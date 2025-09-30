..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===============================================================
Enhanced filesystem driver with configurable timeout protection
===============================================================

https://blueprints.launchpad.net/glance-store/+spec/filesystem-timeout-protection

Add timeout protection to filesystem operations. This prevents operations from
hanging forever when storage is not available. This works for all filesystem
types (local or network) based on configuration.


Problem description
===================

The filesystem store driver in glance_store does not have any timeouts for
filesystem operations. When storage becomes unavailable, operations like
os.path.exists(), os.unlink(), and os.statvfs() can hang forever. This causes
Glance API timeouts and bad user experience.

Common scenarios where these problems happen:

* NFS server outages or network problems
* Storage backend failures (PowerFlex, PowerStore, etc.)
* Network connectivity issues between Glance and storage
* Storage maintenance windows
* Local disk failures that cause IO operations to hang

When these problems happen, Glance operations like image deletion, retrieval,
and storage capacity checks will hang forever. This causes:

* API timeouts and bad user experience
* Resource exhaustion on Glance API servers
* Cannot perform maintenance operations
* Cascading failures in OpenStack deployments

Proposed change
===============

Add timeout protection to the filesystem driver. This prevents operations from
hanging forever. This keeps backward compatibility by default. Default is
blocking IO (timeout = 0 means wait forever).

Three new configuration options will be added:

.. code-block:: ini

  [filesystem]
  # Timeout for all filesystem operations (seconds)
  # Set to 0 to disable timeout protection (blocking IO, normal behavior)
  # Set > 0 to enable timeout protection with thread pool
  # Recommended: 30 seconds for network storage, higher for slow networks
  filesystem_store_timeout = 0

  # Thread pool size for timeout-protected operations
  # Only meaningful when filesystem_store_timeout > 0
  # Ignored when filesystem_store_timeout = 0 (no thread pool is created)
  # Each store instance gets its own pool to avoid starvation
  # Set based on expected concurrency and WSGI worker count
  filesystem_store_thread_pool_size = 10

  # Thread pool usage threshold for warning logs (percentage)
  # Only meaningful when filesystem_store_timeout > 0
  # Ignored when filesystem_store_timeout = 0 (no thread pool is created)
  # When thread pool usage exceeds this threshold, a warning is logged
  # indicating that the pool is getting busy and may start blocking
  filesystem_store_threadpool_threshold = 75

The options ``filesystem_store_thread_pool_size`` and
``filesystem_store_threadpool_threshold`` are only used when
``filesystem_store_timeout > 0``. When ``filesystem_store_timeout = 0``, these
options are ignored since no thread pool is created.

We use ThreadPoolExecutor to wrap filesystem operations when
filesystem_store_timeout > 0. When filesystem_store_timeout = 0 (or not set),
operations run directly without thread pool overhead (blocking IO, current
behavior).

Each store instance will have its own thread pool.

* When an operation times out:

  - The calling thread stops waiting and raises TimeoutError
  - The worker thread continues running (cannot be killed) but we move on
  - Error message: "Operation timed out after {timeout}s. Check storage
    health and connectivity."

When filesystem_store_timeout = 0 (or not set):

* Operations run directly without thread pool overhead

* No timeout protection (current behavior, backward compatible)

* The options ``filesystem_store_thread_pool_size`` and
  ``filesystem_store_threadpool_threshold`` are ignored (no thread pool
  is created).

Operations that will be wrapped (when timeout > 0):

For the first implementation, timeout protection will be limited to metadata
operations. Data pipeline operations (get(), add()) are more complex and will
be considered for a future enhancement.

* delete() - wraps os.unlink()

  .. note::

     When delete() times out, we return an error to the user. But the worker
     thread may still complete the deletion later if storage becomes available
     again. This can leave the DB record while the file is gone. We will
     consider deleting from the DB first, then the store. That way, if the
     store delete times out, the DB is already cleaned up. Operators can handle
     orphaned files later. This potential inconsistency will be documented. We
     may enhance this later to handle it better. For example, if a subsequent
     delete() finds the file already gone, treat it as success (idempotent
     delete).

* get_size() - wraps os.path.getsize()

* _get_capacity_info() - wraps os.statvfs()

Data pipeline operations (future enhancement):

* add() - wraps os.path.exists(), file open(), and file writes

* get() - wraps file location resolution (os.path.exists, os.path.getsize)
  and ChunkedFile creation (which opens the file via open())

  .. note::

     Protecting get() is complex because it only protects the initial file
     open, not the streaming reads that happen later when the iterator is
     consumed. If the mount goes away during streaming, those reads will still
     hang. Full protection would require a wrapper iterator that delegates all
     reads to the thread pool, which adds significant complexity and overhead.

Alternatives
------------

None.

The following alternatives were considered but none are useful:

Filesystem Detection Approach

We could detect filesystem types (NFS, CIFS, etc.) and only apply timeout
protection to network filesystems. This adds complexity without clear benefit.
Local filesystems can also hang (failing disks). Operators can configure timeout
protection if needed.

Dedicated NFS Driver

We could create a separate NFS driver alongside the filesystem driver. This
would require operators to change their driver configuration. This would break
backward compatibility.

Application-Level Timeouts

We could implement timeouts only at the API level. This does not work because
the hanging happens at the filesystem driver level. We need protection at the
storage layer.

No Configuration Options

We could skip adding configuration options and just hardcode timeouts. This was
rejected because different storage backends have different latency
characteristics. Operators need the flexibility to tune timeouts.

Data model impact
-----------------

None.

REST API impact
---------------

None.

Security impact
---------------

This prevents resource exhaustion attacks. An attacker could exploit hanging
filesystem operations to consume server resources. Since each store instance has
its own thread pool, an attack on one filesystem cannot exhaust all server
resources. The damage is limited to that specific store.

Notifications impact
--------------------

None.

Other end user impact
---------------------

Users will get faster failure responses when storage is unavailable. This
happens instead of indefinite hanging (when timeout protection is enabled).
Operators will also get warning logs when thread pool usage exceeds the
configured threshold, helping them identify potential issues before operations
start failing.

Performance Impact
------------------

When timeout protection is enabled (timeout > 0), there is some overhead
from thread pool operations. When disabled (timeout = 0), there is no
performance impact (normal behavior). This prevents resource exhaustion from
hanging operations when enabled.

Other deployer impact
---------------------

Deployers can configure the timeout value based on their storage
characteristics. The default of 0 (blocking IO) keeps backward compatibility.
For network storage or unreliable storage, operators can set
filesystem_store_timeout > 0 to enable protection.

Developer impact
----------------

None.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  abhishek-kekane

Work Items
----------

* Implement thread pool wrapper for filesystem operations with timeout
* Update delete(), get_size(), and _get_capacity_info() to use thread pool
  when timeout > 0
* Implement thread pool usage monitoring and warning logs when threshold is exceeded
* Add generic timeout error messages
* Document timeout edge cases (e.g., delete operations that complete after timeout)
* Write unit and functional tests for timeout behavior

Dependencies
============

None

Testing
=======

* Tempest tests for timeout behavior

Documentation Impact
====================

* Document new configuration options
* Provide guidance on timeout values for different storage types
* Document potential inconsistency when delete() times out (file may be deleted
  later, leaving DB record)

References
==========

None.
