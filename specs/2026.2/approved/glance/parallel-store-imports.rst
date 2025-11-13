..
  This work is licensed under a Creative Commons Attribution 3.0 Unported
  License.

http://creativecommons.org/licenses/by/3.0/legalcode

=======================================
Parallel Store Imports for Image Import
=======================================

Include the URL of your launchpad blueprint:

https://blueprints.launchpad.net/glance/+spec/parallel-store-imports

Currently when importing an image to multiple stores using the
interoperable image import API (glance-direct or web-download methods),
stores are processed sequentially. This means if you're importing to 5
stores, each store import waits for the previous one to complete.

This spec proposes adding parallel execution for store imports within a
single image import operation, with a configurable limit
on how many stores can be imported in parallel. We can further enhance this
functionality to support copy-image import method as well.

Problem description
===================

When importing an image to multiple stores using the image
import workflow, the current implementation processes stores sequentially.
For example, if importing an image to stores A, B, C, D, and E,
the workflow will:

1. Import to store A (wait for completion)
2. Import to store B (wait for completion)
3. Import to store C (wait for completion)
4. Import to store D (wait for completion)
5. Import to store E (wait for completion)

This sequential approach is inefficient when stores are independent and
can be written to in parallel. The total import time is the sum of all
individual store import times, even though these operations could happen
concurrently.

This behavior is not changed by the ``[taskflow_executor]`` options
``engine_mode`` and ``max_workers``. Those settings only control how the
Taskflow engine schedules work inside a single import task (for example
``serial`` versus ``parallel`` mode with a bounded thread pool).

Interoperable image import flows are built as linear Taskflow graphs: each
"import to store" step depends on the previous step completing, so Glance
still copies to multiple backends one after another regardless of
``engine_mode``. ``parallel`` only helps when a flow exposes independent
Taskflow atoms the engine may run at the same time; the current multi-store
import path does not do that for per-store writes. Parallelism across
different images (the API spawning each import on a task pool) is separate
and does not make one image replicate to several stores at once, which is
the gap this specification addresses.

Operators deploying multi-store configurations would benefit from reduced
import times when importing images to multiple backends. This is especially
relevant for scenarios like:
- Importing images across regions
- Distributing images to multiple storage backends for redundancy
- Migrating images between storage systems

Proposed change
===============

Modify the import flow to support parallel execution of imports
within a single image import operation. The implementation will:

1. Add a new configuration option `max_parallel_stores`
in the `[image_import_opts]` section with a default value of 1. This
controls how many stores can be imported to simultaneously for a single
image. The default value of 1 maintains backward compatibility by using
sequential imports. Operators can enable parallel imports by setting this
value to a number greater than 1.

2. When parallel imports are enabled (`max_parallel_stores` is more than 1
   and there is more than one target store), the code uses a work queue and
   a worker pool. The pool size is at most ``max_parallel_stores`` (how many
   store imports may run at the same time).

   One import job is one target store. First the flow runs the normal linear
   part (for example staging download and verify). After that, all jobs go
   into the queue. The jobs do not all run at the same time. Only up to
   ``max_parallel_stores`` store imports are active together; any other jobs
   wait in the queue until a worker is free. When one worker finishes one
   store, it takes the next job from the queue until the queue is empty.

   Location Collection: When stores run in parallel, each task copies data
   to its store and puts location info in one shared in-memory structure.
   Final location rows will be saved when Atomic Location Saving step runs to
   avoid race conditions. We will also persists per-store
   bookkeeping in the database while work is queued and uploading; see
   ``Location status`` part below. Order of which store finishes first is not
   important for correctness. When ``all_stores_must_succeed`` is True, image
   becomes ``active`` after Atomic Location Saving step. When
   ``all_stores_must_succeed`` is False, image can become ``active`` as soon as
   first store write is successful.

   Atomic Location Saving: A separate task runs to collect locations from the
   shared data structure and save them to database in controlled way.
   For ``all_stores_must_succeed=True``, this runs after all queued jobs are
   finished and then sets image status to ``active``. For
   ``all_stores_must_succeed=False``, image may already be ``active`` after
   first success, and this step keeps reconciling later successful locations.
   For this step we need a direct database API call.
   image_repo.save() would validate the locations again. They were already
   validated during the parallel imports, so that can fail with
   InvalidLocation exception.

   Partial failure and cleanup: The import can fail before Atomic Location
   Saving completes. Then the full image may already exist on some backends,
   while the image record may not yet expose final ``active`` locations (or
   may hold only in-progress rows). So we must record per store: if the
   write finished, and the location URI (or some kind of handle) that we
   need for delete. We keep this in the same shared object as for Location
   Collection, and any durable rows must remain consistent with
   that record for cleanup. On failure, the normal revert or failure code must
   read the record and delete any orphan image data on the backends (same idea
   as today, but it must use the list built during parallel store jobs).

   Failure behavior is still controlled by the existing
   `all_stores_must_succeed` parameter. If it is True (default): when any
   store import fails, the whole import fails at once. The image stays in
   importing state. Revert must delete the image data on every store that
   already had a successful write. This must be the same behavior as the
   sequential import today. We cancel or wait until ongoing work stops,
   depending on how the task is written. Then we walk the recorded list and
   delete the objects.

   If `all_stores_must_succeed` is False: the other jobs in the queue keep
   running. Failed stores are written to `os_glance_failed_import`. Each
   failed job must still delete partial or bad objects on that store, so only
   clean locations go into the final save. As soon as first store write is
   successful, image is set to ``active``. Remaining successful stores are
   still reconciled into location rows.

   Location status in the database: With parallel import, if the worker
   dies after data is uploaded to the store but image is not saved yet, we have
   the orphan data problem. Table ``image_locations`` already has ``status``
   column (default ``active``). We should use this column to show per-store
   progress. It is not same as image status field. It is useful for operator,
   for debug, for tests, and maybe later for API to show progress.

   Suggested approach (high level only):

   * ``pending``: row exists for that store, job is in queue, worker did not
     start upload yet. We can create row when job is enqueued so we see
     difference between waiting in queue and real upload.

   * ``uploading``: worker took the job from queue and is writing to backend.

   * ``active``: upload finished, this is normal usable location. Same rules
     as today when image is ``active`` and when locations show in API.

   Optional: if we need one more step before we say location is fully
   published (for example after checksum check across stores), we can add
   status like ``uploaded`` meaning object is on backend and we know URI,
   and ``active`` only after final step.

   Flow idea: for each store we register durable state (example: row with
   ``pending``), put job in queue, wait until queue empty with bounded pool.
   Worker side: take job, set row to ``uploading``, do upload, set to
   ``active`` or first ``uploaded`` then ``active`` if we use two steps, then
   take next job.

   Image ``active`` timing follows ``all_stores_must_succeed`` (see above).
   When it is True, image stays ``importing`` until all target stores finish
   or fail per the rules, then becomes ``active`` in Atomic Location Saving.
   When it is False, image becomes ``active`` after the first successful store
   write; other stores can still be ``pending`` or ``uploading`` and their
   location rows are updated as they complete. Orphan cleanup and revert must
   follow the same flag behavior as sequential import today.

   A future enhancement can add an API option or flag to expose ``pending``,
   ``uploading``, maybe ``uploaded`` locations (for example for
   operators who want to see import progress).

3. The default value is 1. This is for backward compatibility: same as
sequential import today. If the operator tried a higher value and wants
sequential behavior again, they set `max_parallel_stores` back to 1.

Alternatives
------------

Refactor the interoperable import Taskflow to use a non-linear graph for
the per-store copy phase (for example Taskflow's ``GraphFlow``, or another
supported parallel pattern), instead of chaining each
``import to store`` step in a single ``linear_flow``.

In that design, steps that must stay ordered (image lock, staging download,
verify staging, import plugins) remain on a linear prefix. Once the staged
file is ready, the flow fans out to multiple independent store-write
atoms, then fans in before later work (collect locations, persist to the
database, set image status, cleanup). With such a graph,
``[taskflow_executor]`` ``engine_mode = parallel`` (and ``max_workers``)
becomes meaningful for that phase, because the engine has independent atoms
to schedule concurrently.

This alternative still requires explicit handling of database consistency,
failure semantics (including ``all_stores_must_succeed``), and resource
limits; an operator-facing maximum concurrency cap may still be desirable
even if the implementation uses graph parallelism rather than an explicit
queue and worker pool for the store-import phase.

The primary proposal uses a bounded worker pool fed by a queue of per-store
import jobs, with ``max_parallel_stores`` as the concurrency limit.
A graph-based flow could be a future refinement or an equivalent implementation
strategy behind the same configuration knob.

Data model impact
-----------------

None

REST API impact
---------------

None at first release. Later maybe we add flag or API to show per-location
status from ``Location status in the database`` part (``pending``,
``uploading``, maybe ``uploaded``).

Security impact
---------------

None

Notifications impact
--------------------

None

Other end user impact
---------------------

End users will see faster import times when importing to multiple stores,
but the API interface remains the same. No changes to python-glanceclient
are required.

Performance Impact
------------------

The primary performance benefit is reduced wall-clock import time when
importing to multiple stores. Sequential work is roughly the sum of each
store's import time. With a queue and a bounded worker pool, up to
``max_parallel_stores`` stores run at once, so total time is usually much
less than that sum.

The actual improvement depends on:
- Number of stores being imported to
- Individual store import times
- Configured parallelism limit
- Available system resources (network, disk I/O)

Potential concerns:
- Increased memory usage when multiple large images are being imported
to multiple stores simultaneously
- Network bandwidth saturation if importing to remote stores
- Disk I/O contention if multiple stores share the same physical storage

The configurable limit allows operators to tune based on their hardware
and network capacity.

Other deployer impact
---------------------

A new configuration option will be added:

.. code-block:: ini

   [image_import_opts]
   max_parallel_stores = 1

Operators can adjust this value based on:
- Available network bandwidth
- Storage backend capabilities
- System memory and CPU resources
- Typical image sizes in their deployment

Default value of 1 maintains backward compatibility with sequential
imports. Operators who want to enable parallel imports can set this value
to a number greater than 1. A value of 3 provides a reasonable balance
between performance improvement and resource usage for most deployments.
Operators with high-bandwidth networks and powerful storage backends may
increase this value further. Operators with limited resources should set
it to a lower value.


Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
abhishekk

Other contributors:
None

Work Items
----------

1. Add configuration option `max_parallel_stores` in the `[image_import_opts]`
   section.
2. Implement bounded worker pool and queue. Each job is one store. Record
   progress in shared structure for Location Collection. Update
   ``image_locations`` status as needed: ``pending`` in queue, ``uploading``
   during write, then ``active`` or optional ``uploaded``.
3. Implement final save path (collector or similar): collect finished store
   data, fix location rows to ``active`` and image status per chosen policy,
   write database, set image ``active`` when import success rules are ok.
4. Bookkeeping, revert, cleanup: delete bad data on backends on failure,
   fix rows that are not ``active``. Default API should not show in-progress
   rows in locations list and should not use them for ``direct_url``, until we
   add explicit API for that.
5. Unit tests and functional tests including failure, revert, locations
   visibility.
6. Document new config, parallel import behavior, and meaning of
   ``pending`` / ``uploading`` / optional intermediate for operator and for
   possible future API.

Dependencies
============

None.

Testing
=======

New tempest tests will be added to verify the changes.

Documentation Impact
====================

The new configuration option needs to be documented in the configuration
reference. A brief explanation of when and how to tune this option
should be included in the admin documentation for interoperable image
import.

References
==========

None

