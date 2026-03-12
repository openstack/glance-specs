..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

========================================================
S3 store: store location without credentials in the URI
========================================================

https://blueprints.launchpad.net/glance/+spec/s3-location-without-credentials

The S3 store driver currently persists the full S3 location URI in the
Glance database, including access_key and secret_key in the URL. This spec
proposes storing a credential-free location URI and resolving credentials
from the configured backend at access time, with a migration path for
existing images.

Problem description
===================

Today, S3 location URIs stored by Glance include access_key and secret_key
in the URL (e.g. s3://key:secret@host/bucket/object). That causes several
issues:

* Secrets are persisted in the Glance database. Anyone with read access to
  image location data (DB, backups, logs) can obtain S3 credentials.

* Credential rotation requires updating every stored location URI. Glance
  already supports rotation by rewriting URLs on access
  (update_store_in_locations), but the underlying design still keeps
  credentials in the URI.

* If location URIs are ever logged or exposed via API responses, credentials
  are leaked.

* Operators cannot fully lock down S3 credentials to config-only without
  changing how locations are stored and resolved.

Proposed change
===============

Store S3 locations in a credential-free form: scheme, host, bucket, and
object path only (e.g. s3://host/bucket/key). The store/backend identifier
will be stored in location metadata (store) so that when Glance or
glance_store needs to access the object (GET, DELETE, scrubber), the driver
can resolve credentials from the configured backend for that store instead
of from the URI.

In glance_store S3 driver:

* When adding a location (after upload), build and store only the
  credential-free URI and ensure location metadata contains the store
  identifier (enabled_backends backend id in multistore; glance_store
  stores entry name such as s3 in single-store).

* When handling a location (get, delete, existence check): if the URI
  contains credentials (legacy), continue to use them for that request and
  optionally trigger migration (see Upgrade/migration). If the URI has no
  embedded credentials, resolve keys for boto as described under
  **How credentials are resolved** below.

How credentials are resolved
------------------------------

Saying “look up the backend config via store id” is accurate for
**multistore**: Glance and the store layer use metadata['store'] with
enabled_backends set and the per-backend configuration so the correct store
instance is selected; that instance’s (access_key / secret_key) (from
its config group) are used for S3 access.

For **single-store**, there is only one configured S3 backend instance. The S3
driver does not resolve boto credentials by doing a separate lookup on store id
inside the driver: when the URI omits credentials, it uses that instance’s
configured keys (self.access_key / self.secret_key) from the glance_store S3
options. Location metadata['store'] is still set and used on the Glance side
for lazy migration and URI-to-store prefix matching (e.g. the
glance_store.stores entry name such as s3), not as an extra indirection for
which key pair boto uses inside a single backend.

Upgrade/migration for existing images:

Use migration on service call (lazy migration). When an image that has an
S3 location is accessed (e.g. image get, get image data, delete, or scrubber
processing), update_store_in_locations runs for **both** multistore and
single-store deployments. On GET /v2/images/{id}, ImageRepoProxy.get()
always invokes store_utils.update_store_in_locations (single-store no
longer uses a separate path that rewrote S3 credentials into the URI).

Extend that logic: when the S3 location URI contains credentials, rewrite the
stored location to the new credential-free format and ensure metadata
contains the store id (or, for single-store only, the glance_store stores
entry name such as s3), then save the image. No bulk migration at service
startup is required; images are migrated as they are touched.

For **multistore**, SCHEME_TO_CLS_BACKEND_MAP is used to resolve the
backend. For **single-store**, migration and prefix matching use
SCHEME_TO_CLS_MAP and each store's credential-free url_prefix (the S3
driver always sets _url_prefix after configure, including single-store).

CONF.enabled_backends may be unset; store_utils treats a missing value as
{} so membership checks and migration remain safe.

Alternative: a one-time or batched migration at glance-api startup could be
added later if operators want to migrate all images without waiting for
access; the spec recommends lazy migration as the default to avoid heavy DB
scans and downtime risk.

Alternatives
------------

* Keep credentials in the URI and only improve rotation: does not address
  persistence of secrets in the DB or exposure risk.

* Resolve credentials from config by matching URI (host/bucket) to a
  backend: possible but fragile when multiple backends share host or
  bucket; storing store id in metadata is explicit and reliable.

* Bulk migration only at startup: would require scanning all image
  locations and rewriting; heavier and riskier than lazy migration on
  access.

Data model impact
-----------------

No new tables or columns. Location records already have a URL string and
metadata (e.g. store). The format of the URL for S3 will change from
containing credentials to credential-free. Metadata already supports a
"store" key. Existing E-M-C migration strategy does not require schema
changes; only the content of existing location url and metadata fields
changes over time via the migration-on-access logic.

REST API impact
---------------

None. Location URLs may be returned in API responses; the new format will
omit credentials. Clients that currently parse credentials from the URI
would need to stop doing so; such parsing is not part of the Glance API
contract. No new or changed REST methods.

Security impact
---------------

Positive: credentials are no longer stored in the database or in location
URIs that may be logged or exposed. Credentials are read from backend
config at runtime when needed. Operators can rotate credentials in config
without rewriting stored locations; new format locations do not need
rewriting for rotation.

Notifications impact
--------------------

None.

Other end user impact
---------------------

None. Users do not see or parse location URIs in normal use.
python-glanceclient does not expose raw location credentials.

Performance Impact
------------------

Negligible. In multistore, resolving credentials from config by store id is a
simple lookup; in single-store, the lone S3 backend’s keys are used when the
URI omits credentials. Migration on service call adds one optional DB save per
image when an image with a legacy S3 location is first accessed after upgrade;
that matches existing update_store_in_locations behavior.

Other deployer impact
---------------------

After upgrade, existing S3 images continue to work (driver accepts both
legacy and new format). New uploads will use credential-free URIs.
Operators must ensure each S3 backend is correctly configured so that
the keys used at runtime match that backend (multistore: selection by
store id from metadata; single-store: the configured S3 backend instance).
No new config options required; existing backend config (access_key,
secret_key) is used for resolution.

Developer impact
-----------------

glance_store S3 driver must be extended to: (1) write credential-free URIs
and store metadata on add; (2) on get/delete/existence, detect
credential-free URIs and resolve credentials from the backend config
(multistore: using location metadata to pick the instance; single-store:
that instance’s configured keys). On the glance side: extend the S3
location update logic used on image access to rewrite legacy URIs to
credential-free form and persist (analogous to
_update_s3_location_and_store_id today).

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  sakumbha

Other contributors:
  abhishekk

Work Items
----------

* glance_store: S3 driver - add location with credential-free URI and
  store in metadata; on get/delete/existence, support credential-free URI
  by resolving credentials from the backend instance’s config (multistore:
  correct instance via store metadata; single-store: that instance’s keys).

* glance_store: S3 driver - when handling legacy URI (with credentials),
  use credentials from URI for the request; optionally expose or call into
  a helper that can produce the credential-free form for migration.

* Glance: extend update_store_in_locations (or S3-specific helper) to
  rewrite S3 locations that contain credentials to credential-free format
  and set store in metadata, then save image (migration on service call).

* Tests: unit tests for new URI format, credential resolution, and lazy
  migration behavior; adjust any tests that assume credentials in URI.

Dependencies
============

None beyond current Glance and glance_store dependencies.

Testing
=======

Unit tests in glance_store for S3 driver: adding locations in new format,
resolving credentials from config when URI has no credentials, and backward
compatibility when URI has credentials, for both single-store and multistore
configurations where applicable. Unit tests in Glance for migration-on-access:
loading an image with legacy S3 location triggers rewrite to credential-free
and save (single-store and multistore). No new tempest tests required; existing
image API and S3 store tests remain valid.

Documentation Impact
====================

Update deployer docs to describe that S3 locations no longer store
credentials in the URI and that existing images are migrated on access.
Document that credential rotation for S3 can be done via config only for
new-format locations.

References
==========

* Glance store_utils.update_store_in_locations and
  _update_s3_location_and_store_id (lazy migration to credential-free
  URIs and store metadata on access).
* Glance location.ImageRepoProxy.get() calling
  update_store_in_locations for all configurations (single-store and
  multistore).
* glance_store S3 driver: credential-free URIs on add, config-based
  credentials when the URI has none, and credential-free url_prefix for
  URI-to-store matching.
