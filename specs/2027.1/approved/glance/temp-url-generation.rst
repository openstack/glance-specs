..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=============================
Temp URL generation in Glance
=============================

https://blueprints.launchpad.net/glance/+spec/temp-url-generation

Let Glance hand out short-lived URLs that read image data straight from an
object store, so consumers such as Nova and Cinder can download images without
streaming them through the Glance API.


Problem description
===================

Consumers download image data through ``GET /v2/images/{image_id}/file``.
For an image in an object store, every byte crosses a Glance API server::

  object store -> Glance API -> consumer

Glance's image cache helps repeated downloads of immutable public images,
but it does not cover the heavy cases: images too large to fit the cache,
instance backups, and images created from volumes, which churn it. For
those, Glance API nodes scale purely as bandwidth proxies, and boot storms
(thousands of hypervisors fetching the same uncached image) make the API
tier the bottleneck.

Object stores can sign a URL that reads one object for a limited time
without any other credential (S3 presigned URLs, Swift temporary URLs).
Glance already holds the store credentials, so it can sign that URL and
hand it to the consumer::

  object store -> consumer

The bytes then leave the Glance API path: downloads run at object-store
speed and the bandwidth cost moves from the Glance tier to the store.
Consumers keep no store credential and need no knowledge of the backend.

Two consequences follow from bypassing the API, and they are why the
feature is per-store and off by default:

* temporary-URL downloads neither use nor fill the glance-api image cache;
* every download is a store read, so on stores that bill egress (S3) the
  operator pays per download instead of once per cache fill.

Use Cases
---------

* An operator runs Glance on S3 and wants Nova to download uncached images
  from S3 without putting S3 credentials on the compute nodes. This
  includes Ceph-backed computes (``images_type=rbd``) for images without
  an ``rbd://`` location: Nova downloads them to the local cache through
  the ordinary file-fetch path and imports them into Ceph.
* An operator wants to cut Glance API bandwidth and CPU while booting many
  instances from large images.
* Ironic, which already generates Swift temporary URLs itself, could get
  them from Glance for any supporting store in a multi-store deployment.
  (Ironic motivated the redirect route proposed by earlier revisions of
  this spec; a JSON response serves it equally well, see Alternatives.)

Proposed change
===============

#. glance_store: add ``get_temp_url(location, context=None)`` to the store
   driver interface, and ``get_temp_url(uri, backend, context=None)`` to
   the multi-store helpers. A driver returns a tuple of (URL, expiry as an
   aware UTC ``datetime``). A new ``TEMP_URL`` store capability bit
   (``0b10000000``, the next free bit — it fits the existing
   ``BitMasks.ALL``, and the operation map gains a ``get_temp_url`` entry)
   says which stores give temporary URLs:
   ``get_temp_url`` is guarded by ``capabilities.check`` like ``get`` and
   ``add``, and raises a new ``TempURLNotSupported`` on a store without the
   capability. The driver sets the capability only when it implements
   temporary URLs, the operator enabled them, and the required options are
   set, so the capability is one source of truth for both the API check and
   store discovery.
#. glance_store S3 driver: implement it with a presigned ``GET`` of the
   image object, always signed with SigV4 (without a configured region,
   botocore would presign with the deprecated SigV2), behind two new
   per-store options (see `Other deployer impact`_). Presigning is a local
   computation: Glance sends no request to S3 when giving a URL.
#. Glance: add ``GET /v2/stores/{store_id}/{image_id}/tempurl``, the
   ``generate_image_temp_url`` policy, the ``image.temp_url`` notification,
   and ``temp_url_enabled`` in store discovery.
#. glance_store Swift driver, as a follow-up in the same cycle: same
   interface, behind ``swift_store_temp_url_enabled`` and
   ``swift_store_temp_url_expiry``, plus a secret
   ``swift_store_temp_url_key`` — Swift signs temporary URLs with a key
   separate from its authentication credentials. The multi-tenant Swift
   store is not supported at first: with one account per project each
   account would need its own key, so the driver simply does not set the
   ``TEMP_URL`` capability in that mode.
#. openstacksdk and python-openstackclient support, in this cycle.

The feature needs multiple stores (``enabled_backends``): the route
addresses a store by its identifier.

Alternatives
------------

A redirect route answering ``307`` to the temporary URL
  It adds a second API with no consumer, hides ``expires_at`` from the
  caller, makes HTTP clients follow the redirect with their
  ``X-Auth-Token`` still attached, and puts the signed URL in a
  ``Location`` header, which proxies and access logs tend to record. A
  consumer that wants the bytes can follow the URL from the JSON response
  itself; Ironic can read the JSON just as well.

A store-less ``GET /v2/images/{image_id}/tempurl``
  Glance would pick a temp-URL-capable store itself, which would also
  serve single-store deployments (still the default configuration), where
  images have no ``stores`` field for consumers to iterate. Not proposed
  for now: the per-store route mirrors the existing store-scoped calls,
  keeps one code path, and leaves the store choice to the consumer, which
  knows which endpoints it can reach. The store-less call can be added
  later on top of the same driver method if the cores want single-store
  support.

Data model impact
-----------------

None.

REST API impact
---------------

**[NEW API] Get a temporary URL for image data**::

  GET /v2/stores/{store_id}/{image_id}/tempurl

No request body. Response, with ``Cache-Control: no-store``:

.. code-block:: json

    {
        "image_id": "1bea47ed-f6a9-463b-b423-14b9cca9ad27",
        "store_id": "fast",
        "temp_url": "https://s3.example.com/glance/1bea47ed-...?X-Amz-Signature=...",
        "expires_at": "2026-10-22T12:05:00Z"
    }

``expires_at`` is an ISO 8601 UTC timestamp, truncated to the second.
S3 presigned URLs count expiry in whole seconds, and S3 checks it when a
request *starts*, so truncating guarantees the advertised time never comes
after the real expiry, and a download started in time finishes even if it
lasts longer.

Checks run in this order, so a caller cannot probe a private image through
the error codes:

=====  ====================================================================
Order  Condition / code
=====  ====================================================================
1      multiple stores (``enabled_backends``) not enabled: 404
2      store unknown on this node: 409
3      image missing or not visible to the primary token: 404
4      a policy check fails: 403
5      image not ``active``: 409
6      the store holds no copy of the image: 404
7      the store lacks the ``TEMP_URL`` capability: 409
any    any method other than GET: 405
=====  ====================================================================

At step 4, the primary token must pass ``download_from_store``, which
authorizes the image and store exactly like a normal download.
``generate_image_temp_url`` defaults to ``rule:service_api`` and is
evaluated with the union of the primary token's roles and the roles from
``X-Service-Token``. The service role never grants image visibility by
itself.

This new call requires an Images API minor version bump: 2.18 is current,
so the feature will include version update to 2.19 in ``api-ref`` and
``/versions`` response updates.

**[UPDATE API] Store discovery**::

  GET /v2/info/stores/detail

Each store gains ``temp_url_enabled``: true when the store has the
``TEMP_URL`` capability (driver support, operator opt-in, and required
options all present). Each store also reports its configured ``weight``
(from the 2023.2 store-weight work), so a consumer can order candidate
stores by descending weight. Consumers may use ``temp_url_enabled`` to
skip hopeless calls, but they don't have to: a Glance without this
feature answers 404 (no such route), so treating any error as "no URL
from this store" works without a discovery call or a version check.

Security impact
---------------

A temporary URL is a bearer credential for one image in one store until it
expires: whoever holds it can read the image data, whether or not they
have any OpenStack access.

Besides the read access, the URL shows the store endpoint, bucket and
object name, and for S3 the access key ID (``X-Amz-Credential``),
not the secret key.

Mitigations:

* New policy ``generate_image_temp_url``, defaulting to
  ``rule:service_api`` (currently ``role:service or role:admin``): the
  check is evaluated with the union of the primary token's roles and the
  roles from ``X-Service-Token``, so a ``service`` role in either token,
  or the ``admin`` role, authorizes the optimized temp-URL path. The
  service role does not grant image access by itself. The
  primary token must also pass ``download_from_store`` (the
  store-selection policy from the download-from-suggested-stores work)
  on the image, so the API only hands out data the caller could download
  from a specific store through ``/file``. ``download_from_store`` is
  evaluated on the primary token only. ``generate_image_temp_url``
  deliberately does not include ``project_id:%(project_id)s``: the image
  may be public, shared or community, and the paired
  ``download_from_store`` check enforces the caller's relation to the
  image. Nova therefore sends the user token as ``X-Auth-Token`` and its
  service token as ``X-Service-Token``; this supports private images
  without making every service token a global image reader.
* Short, bounded expiry: 60 s by default, at most 300 s (5 minutes).
* ``Cache-Control: no-store`` on the response.
* The URL is never logged by the Glance API or the drivers and never
  appears in a notification. (Known leak vectors found while testing the
  PoC, all closed: keystoneauth logs response bodies at DEBUG unless the
  request passes ``log=False``; exceptions raised by requests/keystoneauth
  quote the URL, so consumers should log exception types only.)

Limits:

* A presigned URL cannot be revoked individually. The only way to kill all
  outstanding URLs at once is to rotate the store credentials; Glance
  itself then needs the new key before the old one is removed, so on S3
  the switch means two valid access keys for a while.
* Image state changes revoke nothing: after a deactivation, a visibility
  change, or a member removed from a shared image, outstanding URLs keep
  working until they expire. Deleting the image deletes the object and so
  ends its URLs — except with ``delayed_delete``, where the object (and
  so the URL) lives until the scrubber runs or the URL expires.

The expiry is therefore the real bound on exposure.

Notifications impact
--------------------

* Added: ``image.temp_url`` INFO notification, sent for every URL given,
  with ``image_id``, ``owner_id``, ``store_id``, ``expires_at``,
  ``receiver_tenant_id`` and ``receiver_user_id``. It never holds the URL.
  The fields follow ``image.send`` so consumers can switch to it, knowing
  it records a URL given, not a download completed.
* Disappearing: bytes downloaded through a temporary URL produce no
  ``image.send``, because Glance never sees the transfer. Consumers that
  count ``image.send`` (metering, auditing) silently lose those downloads
  when the feature is turned on. A download that gets a URL, fails, and
  falls back to ``/file`` is reported twice: once as ``image.temp_url``,
  once as ``image.send``.

Other end user impact
---------------------

None: the API is for services acting on behalf of users, and for admins.

Performance Impact
------------------

Image bytes downloaded through a temporary URL bypass the Glance API and
its image cache. Getting the URL costs one small API call and, for S3, a
local signature computation — no request to the store. The download load
moves to the object store: its request-rate and bandwidth limits now apply
to every consumer instead of a few Glance nodes.

Other deployer impact
---------------------

Temporary URLs are off until enabled per store.

S3 store options:

``s3_store_temp_url_enabled``
  Boolean, default ``False``. Let this store give temporary URLs; drives
  the ``TEMP_URL`` capability and the discovery field.
``s3_store_temp_url_expiry``
  Integer seconds, default ``300``, from ``1`` to ``3600`` (1 hour).
  How long a URL stays valid.

URLs are signed for ``s3_store_region_name`` when set, else for the region
``s3_store_host`` implies, else for ``us-east-1``: set
``s3_store_region_name`` when the bucket is in another region.

Swift store options (follow-up): ``swift_store_temp_url_enabled``,
``swift_store_temp_url_expiry``, and ``swift_store_temp_url_key``, the
secret HMAC key Swift temporary URLs are signed with. It is independent of
the Swift authentication credentials and must match the TempURL metadata
set on the Swift account/container. Not available with the multi-tenant
store.

Consumers must be able to reach the object store endpoint as Glance sees
it (the signed URL's host is Glance's ``s3_store_host``, which may not
resolve or route the same way from a compute node) and to trust its TLS
certificate. A store on a plain ``http`` endpoint hands out URLs that
travel in clear and can be replayed until they expire: use HTTPS.
Consumers such as Nova only accept ``https`` URLs.

Nova must enable ``send_service_user_token`` so Glance receives the user
token as ``X-Auth-Token`` and Nova's service token as ``X-Service-Token``.

Developer impact
----------------

Store drivers can implement ``get_temp_url`` and set the ``TEMP_URL``
capability when their configuration allows it. The interface is generic;
only S3 is implemented here, Swift follows in the same cycle.

Upgrade impact
--------------

None: the feature is off by default and the API is new.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  mklejn

Other contributors:
  womax, flelain, lhenry, wsikora

Work Items
----------

Ordered for milestone 1 (Nov 16–20): the glance_store change must merge
and be released before the Glance change can depend on it.

1. glance_store: driver interface, ``TEMP_URL`` capability,
   ``TempURLNotSupported``, multi-store helper, S3 driver and its two
   options. Post now, in parallel with this spec, without waiting for the
   spec to merge. Needs a glance_store release (last release 5.7.0; the
   Glance change will require ``glance-store>=5.8.0``).
2. Glance: the route, the policy, the notification, the discovery field,
   the api-ref and the docs, with ``Depends-On`` on the glance_store
   change and a requirements bump.
3. Swift driver (follow-up glance_store change, same cycle).
4. openstacksdk and python-openstackclient support, this cycle — no new
   user-facing Glance API lands without it. python-glanceclient is not
   changed: the CLI is being deprecated and consumers (Nova first) call
   the API with a plain GET on the keystoneauth session they already have.
5. Tempest tests on an S3-backed devstack.

Fallback if the glance_store release misses milestone 1: Zuul installs
glance_store from git (as raised on the PTG pad), or the Glance side slips
to milestone 2, which still leaves time for Nova at milestone 3.

Dependencies
============

* A glance_store release containing the driver interface
  (``glance-store>=5.8.0``).
* The ``download_from_store`` policy introduced by the approved
  download-from-suggested-stores spec (2026.1).
* Nova's use of this API is specified by nova-spec
  ``glance-temp-url-image-download`` (1010607). Nova reads the image's
  ``stores`` field, calls ``GET /v2/info/stores/detail`` to read each
  store's ``weight``, and orders the candidate stores by descending
  weight (equal weights keep the ``stores`` order); if that discovery
  call is unavailable, it keeps the ``stores`` order. It then calls this
  API per store with the user token as ``X-Auth-Token`` and its service
  token as ``X-Service-Token`` (or an admin token), downloads the
  returned URL with no auth header (HTTPS only, no redirects), checks
  size and ``os_hash_value`` while streaming, and on any error moves to
  the next store, then falls back to ``/file``; a bad image signature
  fails the download instead of falling back; images without
  ``os_hash_value`` always use ``/file``.
* Related: the direct multipart upload spec (1009784), see below.

Testing
=======

* Unit tests in glance_store (presigned URL shape, SigV4 forced without a
  region, disabled store, expiry bounds, multi-store helper) and Glance
  (controller, policy including union-role evaluation, serializer,
  notifications, discovery).
* Glance functional tests: success with a user token plus a service
  token on a private image, success with admin, member alone refused,
  bare service token refused for a private image, denial when
  ``download_from_store`` fails, denial when ``generate_image_temp_url``
  fails, unsupported store, unknown store, image not in store,
  non-active image, wrong method, discovery field, ``Cache-Control``.
* Tempest: on an S3-backed devstack, get a URL, download it with no token,
  compare the hash; negative tests for the policy, unknown store, no copy
  in the store, and a store without the capability.

Documentation Impact
====================

* api-ref for the new call, version and the discovery field.
* glance_store option help and release notes.
* Notification reference: ``image.temp_url`` added; note about
  ``image.send`` no longer covering temp-URL downloads.

References
==========

* Swift temporary URLs:
  https://docs.openstack.org/swift/latest/api/temporary_url_middleware.html
* Ironic's current Swift-only use:
  https://docs.openstack.org/ironic/latest/install/configure-glance-swift.html
* Nova spec: https://review.opendev.org/c/openstack/nova-specs/+/1010607
* Direct multipart upload spec:
  https://review.opendev.org/c/openstack/glance-specs/+/1009784

History
=======

.. list-table:: Revisions
   :header-rows: 1

   * - Release Name
     - Description
   * - 2027.1
     - Introduced
