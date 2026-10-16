..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=======================================
Parallel downloads for S3-backed images
=======================================

https://blueprints.launchpad.net/glance-store/+spec/s3-multipart-download

Large images stored in S3 are currently downloaded through Glance as one
sequential stream. This limits throughput and makes a transient network
failure expensive because the download may have to restart from the
beginning.

This spec proposes an opt-in way to download S3-backed images using several
concurrent byte-range requests. The feature spans the S3 driver, Glance
discovery, python-glanceclient, openstacksdk, and OSC.

Review patches already exist for the S3 driver and python-glanceclient. The
openstacksdk and OSC portions still need to be implemented.

Problem description
===================

Glance already understands HTTP range requests, but the S3 driver does not
support them. Clients therefore cannot split an S3-backed image download
into parts.

The current client paths also use a single request and do not retry only the
failed part of a download. Large-image users need higher throughput, better
resilience, unchanged integrity checks, and correct behavior when the image
cache is enabled.

Proposed change
===============

The S3 driver will support ranged reads using the backend's native range
request mechanism and will advertise the existing ``READ_RANDOM``
capability, which means a store can read from an offset and limit the number
of bytes returned. Full-image downloads will continue to work exactly as
they do today. Requests outside the image size will return the same kind of
error used by other drivers.

python-glanceclient, openstacksdk, and OSC will expose an opt-in parallel
download option. When it is enabled, a client will split the image into
non-overlapping ranges, request those ranges concurrently, and write each
response at the correct offset in a local file. Failed parts will be retried
independently. After reassembly, the client will verify the complete image
using its recorded hash.

If a store does not advertise ranged reads, or a range request returns the
Glance API's HTTP 400 response for
``glance_store.StoreRandomGetNotSupported``, the client will fall back to the
existing single-stream path. A 200 response, HTTP 416 response, or any other
error must not trigger fallback.

OSC will use openstacksdk for this feature. It should not bypass openstacksdk
to call python-glanceclient directly.

The supported CLIs should use one new option, ``--threads``. It defaults to
``1`` and keeps today's single-stream behavior. A value greater than ``1``
enables parallel download and requires a file destination because stdout is
not seekable.

The supported CLIs should also expose ``--offset``. It must be zero or greater
and less than the image size. A nonzero offset fetches the remaining bytes and
writes them at the same offset in the destination file, which allows a
partially downloaded file to be resumed. A nonzero offset also requires a file
destination.

Additional CLI knobs may be useful later:

* ``--part-size`` to control the size of each range request.
* ``--min-size`` to avoid parallel overhead for small images.
* ``--retry`` to control how many times a failed part is retried.

None of these are required for the first implementation. They should be
added only if users need finer control than ``--threads`` provides.

Glance will optionally report whether each store has the ``READ_RANDOM``
capability. When available, the discovery response will also include the
maximum number of concurrent range requests that clients should use. This
lets clients choose the parallel path without sending a probe request first.
The new response fields will be additive.

Client libraries will cap requested parallelism to the advertised maximum.
Glance will also enforce a configurable per-worker limit on concurrent ranged
downloads. When a project exceeds that limit, Glance will return HTTP 429 with
a ``Retry-After`` header. The limit is per API worker, so deployments that
need a global limit must enforce it in their HTTP tier.

When the image cache is enabled, range requests will continue to bypass the
cache. Partial responses will not be written to the cache. Normal full-image
downloads will continue to populate and be served from the cache. This means
a parallel download will not use or populate the cache. That is intentional
and safe. Serving ranges directly from a cached file can be considered
later, but it is not part of this spec.

Gaps in the current patches:
The S3 driver does not yet convert out-of-range requests into a Glance
error. It also turns every full read into a range request, which is
unnecessary and changes the backend request behavior. Its tests do not yet
cover out-of-range requests or realistic partial-content responses.

The client patch does not yet fall back to the normal download path, retry
failed parts, verify that each response matches the requested range, or
validate the final image hash. It also ignores ``--allow-md5-fallback`` in
multipart mode and uses a fixed minimum-size threshold that is not exposed
to users.

openstacksdk and OSC support is still missing.

Alternatives
------------

* Serve ranges from the image cache. This would reduce repeated backend reads
  for cached images, but it requires separate cache coordination work. This
  is tracked by bug 1664709.

* Use S3 temporary URLs to download directly from the backend. This avoids
  Glance API bandwidth entirely, but it bypasses the image cache and requires
  consumers to reach the store endpoint directly. See the temporary URL spec
  at https://review.opendev.org/c/openstack/glance-specs/+/970214.

Data model impact
-----------------

None

REST API impact
----------------

No request or response changes are required for the download itself. The
optional store discovery fields are additive. Ranged downloads may return
HTTP 429 when the per-worker concurrency limit is exceeded.

Security impact
----------------

The feature reuses the existing image download authorization path. Parallel
downloads can increase backend request volume, so Glance will enforce a
per-worker concurrency limit and clients will cap requested parallelism.
Final hash validation will remain mandatory.

Notifications impact
---------------------

None

Other end user impact
---------------------

Users of the supported CLIs get an opt-in concurrency option. Existing
single-stream behavior remains the default.

Performance impact
------------------

Large S3-backed downloads should be faster and less sensitive to transient
failures. Users who do not opt in are unaffected.

Other deployer impact
---------------------

Operators should confirm that their S3-compatible backend supports range
requests. Parallel downloads may increase request volume and concurrent
connections. Ranged downloads will bypass the image cache. Operators can tune
the per-worker concurrency limit and may enforce a global limit in their HTTP
tier.

Developer impact
----------------

The store capability and client download patterns should be reusable by
other drivers and clients. Extending them to other backends is out of scope.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  lamprechtm

Other contributors:
  abhishekk (Abhishek Kekane)

Work Items
----------

1. Add ranged-read support to the S3 driver.

2. Expose ranged-read support and concurrency limits through store discovery.

3. Add per-worker concurrency limiting to Glance.

4. Add opt-in parallel download and offset resume to python-glanceclient.

5. Add opt-in parallel download and offset resume to openstacksdk.

6. Expose the options in OSC.

7. Preserve and test image-cache range behavior.

8. Document the feature, cache behavior, and concurrency limits.

Dependencies
============

No new third-party dependency is required.

Testing
=======

Tests should cover S3 range support, store discovery, parallel client
downloads, offset writes and resume, retry, fallback, final hash validation,
CLI option handling, HTTP 429 limiting, and cold-cache and warm-cache range
behavior.

Documentation Impact
====================

Operator documentation should describe the new option, backend requirements,
integrity behavior, and cache behavior.

References
==========

* https://review.opendev.org/c/openstack/glance_store/+/969482
* https://review.opendev.org/c/openstack/python-glanceclient/+/969491
* https://bugs.launchpad.net/glance/+bug/1664709
