..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===========================
multi-store backend support
===========================

https://blueprints.launchpad.net/glance/+spec/multi-store

The Image service supports several back ends for storing virtual machine
image namely Block Storage service (cinder), Filesystem (a directory on
a local file system), HTTP, Ceph RBD, Sheepdog, Object Storage service
(swift) and VMware ESX. As of now operator can configure single backend
on a per scheme basis but it's not possible to configure multiple backends
for same or different stores. For example if a cloud deployment has
multiple ceph deployed glance will not be able to use all those backends
at once.

Consider the following use cases for providing multi-store backend support:

* Deployer might want to provide different level of costing for different
  tiers of storage, i.e. One backend for    SSDs and another for
  spindles. Customer may choose one of those based on his need.
* Old storage is retired and deployer wants to have all new images being
  added to new storage and old storage will be operational until data
  is migrated.
* Operator wants to differentiate the images from images added by user.
* Different hypervisors provided from different backends (For
  example, Ceph, Cinder, VMware etc.).
* Each site with their local backends which nova hosts are accessing
  directly (Ceph) and users can select the site where image will be stored.

Problem description
===================

At the moment glance only supports a single store per scheme. So for example,
if an operator wanted to configure the Ceph store (RBD) driver for
2 backend Ceph servers (1 per store), this is not possible today without
substantial changes to the store driver code itself. Even if the store driver
code was changed, the operator today would still have no means to upload or
download image bits from a targeted store without using direct image URLs.

As a result, operators today needs to perform a number of manual steps
in order to replicate or target image bits on backend glance stores. For
example, in order to replicate a existing image's bits to secondary storage
of the same type / scheme as the primary:

* It's a manual out-of-band task to copy image bits to secondary storage.
* The operator must manage store locations manually; there is no way to
  query the available stores to back an image's bits in glance.
* The operator must remember to register secondary location URL using
  the glance API.
* Constructing the location URL by hand is error prone as some URLs are
  lengthy and complex. Moreover they require knowledge of the backing store
  in order to construct properly.

Also consider the case when a glance API consumer wants to download the image
bits from a secondary backend location which was added out-of-band. Today
the consumer must use the direct location URL which implies the consumer
needs the logic necessary to translate that direct URL into a connection
to the backend.

Proposed change
===============

This spec proposes the following high level features to support multiple
stores of the same scheme/type:

* Support in the glance-api.conf and supporting logic to configure, manage
  and use multiple stores of the same or different type/scheme.
* Enhance the image upload API to (optionally) support targeting a backend
  store for the image bits.
* Enhance image download code to download image from any of the enabled
  backends.
* Enhance the image import API to (optionally) support targeting a backend
  store to download the image bits from.
* Additional metadata attribute(s) added to an image locations' metadata
  properties related to backing stores.
* A new REST API to list all configured stores known to the glance service.

** Config/glance-store changes**

In order to have multi-store support of same or different type/scheme
we propose to deprecate 'stores', 'default_store' config option and
add a new config option `enabled_backends` under DEFAULT section,
'default_backend' option under 'glance_store' section and
'description' option under each section of desired store of
glance-api.conf. Operator can use `enabled_backends` to specify comma
separated key:value of storage backends and its store type and then
each backends will have a different section to specify related configuration
options. If 'default_backend' is not explicitly set then appropriate
exception will be raised which will prevent the service from starting.

The reason for deprecating 'default_store' config option is that glance
verifies the default store at the time of service start and if it is not
one of the listed store (file, http, rbd, swift, cinder, vmware or sheepdog)
then it raises the error and prevents the service from start. This validation
has been done using 'choices' attribute of ConfigOption object itself. After
enabling support of multi-store it's difficult to have this kind of
validation check using 'choices' attribute will be difficult as
default_store name will be store identifier and not actual store.

Consider the following example snippet of glance-api.conf which configures
3 stores for use::

    [DEFAULT]
    # list of enabled stores identified by their property group name
    enabled_backends = fast:rbd, cheap:rbd, reliable:file

    # the default store, if not set glance-api service will not start
    default_backend = fast

    # conf props for file system store instance
    [reliable]
    filesystem_store_datadir = /var/lib/images/data/
    description = Reliable filesystem store
    # etc..

    # conf props for ceph store instance
    [fast]
    rbd_store_ceph_conf = /opt/ceph1/ceph.conf
    description = Fast access to rbd store
    # etc..

    # conf props for ceph store instance
    [cheap]
    rbd_store_ceph_conf = /opt/ceph2/ceph.conf
    description = Less expensive rbd store
    # etc..

The example above is for Ceph, but it could apply to any storage backend. As
shown in the example above the 'enabled_backends' property is a comma delimited
list of store identifiers which are setup for glance. Each of the store
identifiers defines a property group name which itself contains the store
specific properties used to configure the store instance and a store type
which will be used to register configuration options related to that store
under the new configuration section defined using store identifiers. Under
the covers the store identifier (aka id) maps to the store class used for
the instance.

While 'stores' and 'default_store' are available an operator can leave the
'enabled_backends' property unset in which case multi-store support is not
"enabled" and glance will work as-is. Once these config options are removed
operator at least need to set one store in the 'enabled_backends' or else
glance-api service will fail to start.

In order to accommodate multiple stores of the same scheme, the scheme_map
used to index stores must also index by store identifier per scheme. The
store identifier is (implicitly) the name of the conf group given in
the glance-api.conf (e.g. reliable, fast and cheap from the example
conf given above).

Consider the following indexing approach::

    scheme_map[scheme][store_id]

Where 'scheme' is the scheme(s) supported by the store implementation and
'store_id' is the identifier for the store.

To maintain backward compatibility with old store API's while they are not
deprecated we also propose to add new store api's like add, get, delete
etc. to glance_store. The old store api's will be removed when the
deprecation period for 'stores' and 'default_store' config option is over.

**API to list stores**

To accommodate the management and discovery of known glance stores, glance
should also provide a REST API which permits users to list all stores
configured for glance. This is a read-only list of glance stores
which includes the store identifier, description for each store and a flag
which will tell whether a store is default or not.

NOTE: The list of glance stores is based on the glance-api.conf with respect to
store configuration. Operators will not be able to configure new stores using
the API. So in order to show the description in the response as mentioned
earlier we propose to add new config option 'description' to each store
with some default description and operator can set it as per their need.

As discussed herein, the store identifier can be used to address a particular
instance of a store for applicable operations such as image upload and
image import.

We propose the new REST resource be located at the following URI::

    /v2/info/stores

More details on this API can be found in the REST API section of this spec.

**Image upload API**
The existing image upload API permits an operator to upload image bits to
the glance service. However today this API does not provide a means for
the operator to target a specific store to back the image bits on
(technically the v1 API allows you to specify a store scheme to target).
This spec proposes the API be enhanced to permit an operator to specify
which store will back the image bits being uploaded.

We propose a header field be used as a means to transport
the identifier of the store to back the image bits. Again the identifier
under the covers is the property group name of the respective glance
store driver. When the image upload API is used to upload image bits, the
glance logic will determine if the target store is specified, and if so
the image bits will be added to the target store.

If no store is targeted in the upload request, the 'default_backend'
is used to back the image bits.

Using this scheme operators will be able to specify which store they want
an image bits to be backed on during an upload operation. We propose the
'X-Image-Meta-Store' header be used as the means to transport a target
store identifier.

More details on this API can be found in the REST API section of this spec.

**Image download**
If cloud get upgraded to use multi-store support from the single store
then glance need to deal with the locations from old stores to new
stores. For example, if operator is using rbd (say ceph) backend
and now he has upgraded the environment and introduced two additional
rbd stores as ceph1 and ceph2 with default store as 'ceph1' then
somehow glance must be able to download the images from old stores
(ceph).

With multiple backends available, Glance needs some enhancements
so it can fulfill the current image download API contract. The
download request will traverse through all the configured backends
to look for the image. As we are adding store information in location
metadata, at first it will look the image in the store which is set
in the location metadata. If location metadata is not set then
as per example from the config section above, if the location
is rbd://<something>, then it will search the image in all available
ceph stores i.e. 'fast' and 'cheap' in this case. This way user will be
able to download his image from the old store even after cloud is
upgraded to use multiple stores.

**Image import API**
The existing image import API allows end users to import image from the
staging area into glance backend. However today this API does not provide
a means for the end user to target a specific store to import the image.
This spec proposes the API be enhanced to permit an end user to specify
which store will back the image being imported.

We propose a header field be used as a means to transport the identifier
of the store to import the image. Again the identifier under the covers
is the property group name of the respective glance store driver. When
the image import API is used to import the image, the glance logic will
determine if the target store header is specified, and if so the image
will be imported to the target store.

If no store is targeted in the import request, the 'default_backend' is
used to import the image.

Using this scheme end users will be able to specify which store they want
an image to be imported during an import operation. We propose the
'X-Image-Meta-Store' header be used as the means to transport a target
store identifier.

More details on this API can be found in the REST API section of this spec.

**Store locations metadata attributes**
In the current glance API, a consumer of the glance API has no way to correlate
an image location with its respective store other than by inspecting the
image's location URL. While this may work fine for many use cases, a more
user friendly relation is needed in a multi-store environment; user's need
an explicit relation between an image location and its respective store
(e.g. what store is this location backed on).

This spec proposes that when image bits are added with the image upload API,
the core glance logic is responsible for adding a metadata attribute to the
image location URL to reflect the backing store's identifier. For example,
if a user uploads an image to the 'ceph1' store in our example above,
once the image bits are uploaded, the image location URL is added and in the
URL's metadata a property with the store's identifier is added to the location
metadata object.

With the store identifier in the image location URL metadata, we can expose it
to the end user with a new attribute as 'store' in the image response so that
it can be used for subsequent operations or within the API consumers logic.

The new image response with store attribute will be something like::

    "size": 1234,
    "store": ["reliable"],
    "checksum": 1234567890,
    "name": "Import image",
    "status": active

Alternatives
------------

Two major alternatives come to mind with respect to a multi-store approach in
glance; multi-store using a service per store and per driver multi-store
support.

**Per store service**
In the service per store approach, each of the configured store instances would
run as a separate process/service. As a result each service would have its
own AMQP/RPC interface, own PID, etc.. To route requests to store services,
we'd use a scheduler which itself is another process / service. This is the
same approach used in cinder multi-backend support.

Although the service per store approach may be a longer term goal for glance,
today we haven't seen enough justification from our consumer base to justify
the major refactoring/changes which are required to move glance to this
model.

Therefore this spec proposes the multi-store approach outlined within this
spec - let's get an initial approximation multi-store working and gage
our next steps based on consumer feedback in the community.

**Per driver support**
Another potential approach would be to push the multi-store logic down within
each glance store driver's implementation. For example the store driver
itself could contain logic to multiplex with multiple backends.

While this approach would work, it would require each store driver's
implementation to change and would result in suboptimal reuse of code.

This spec proposes a multi-store approach which has little or no impact
to each store driver; they can be used as-is in a multi-store implementation.
By pushing the logic to support multiple stores of the same scheme up into
the core of glance, we get maximal reuse and store driver implementations
needn't be concerned with such logic.

Data model impact
-----------------

This spec does not propose any changes to the data model. Rather the approach
herein can maintain all new stateful data either in memory or within the
existing schema used by glance. However store identifier will be stored as
a metadata in the location object.

REST API impact
---------------

This spec proposes the following API changes:

**New API**

* List all stores known to the glance service.

**Modified APIs**

* Import an image.
* Upload an image file.
* Get image details.

**Common Response Codes**

* Create Success: `201 Created`
* Modify Success: `200 OK`
* Delete Success: `204 No Content`
* Failure: `400 Bad Request` with details.
* Forbidden: `403 Forbidden`

**API Version**

All URLS will be under the v2 Glance API.  If it is not explicitly specified
assume /v2/<url>

**[New API] List stores**

List all stores known to the glance service::

    GET /v2/info/stores

This API takes no query parameters and when authorized returns a listing of all
stores known to the glance service. The stores known to glance are those which
have been configured in the glance-api.conf and have been loaded during glance
startup. The response body payload is JSON and contains a JSON object per
store. Each store JSON object contains the store's identifier (id),
description and if a particular store is a default store the it will
have a flag telling store is default. For example::

    {
       "stores":[
          {
             "id":"reliable",
             "description": "Reliable filesystem store"
          },
          {
             "id":"fast",
             "description": "Fast access to rbd store",
             "default": true
          },
          {
             "id":"cheap",
             "description": "Less expensive rbd store"
          }
       ]
    }

Response codes:

* 200 -- Upon authorization and successful request. The response body
  contains the JSON payload with the known stores.

**[Modified API] Create image**
We propose to add an 'OpenStack-image-store-ids' header to the image-create
response which would have the available stores. Using this user can decide
which store he needs to upload/import his image and wouldn't have to make
a separate get-stores call.

New response headers
^^^^^^^^^^^^^^^^^^^^

``OpenStack-image-store-ids``

   The value of this header will be a comma-separated list of stores
   available.  For example,

   OpenStack-image-store-ids: fast, cheap, reliable

**[Modified API] Upload image binary data**

Get image binary data::

    PUT /v2/images/​{image_id}​/file

This modifies the existing REST API to support a new header field which is
optional and if present specifies the store id to upload the image data to.
For backwards compatibility, if the header is not specified the store
specified as the default (e.g. default_store) is used to upload the image
to.

New header fields:

* X-Image-Meta-Store -- If present contains the store id to upload the image
  binary data to.

New / changed response codes:

* 400 -- If the X-Image-Meta-Store header is present, but specifies a
  store id for a store that doesn't exist by that id.

Example curl usage::

        curl -i -X PUT -H "X-Auth-Token: $token" -H "X-Image-Meta-Store:
            ceph1" -H "Content-Type: application/octet-stream"
            -d @/home/glance/ubuntu-12.10.qcow2
            $image_url/v2/images/{image_id}/file


**[Modified API] Get image details**

Get the details for a specified image::

    GET /v2/images/​{image_id}​

Although this spec does not impose any changes on the glance API layer, this
call will now shows the location's store id. In case if there are multiple
locations, then all locations will be displayed as comma separated list. The
new image response with store attribute will be something like::

    "size": 1234,
    "store": ["reliable"],
    "checksum": 1234567890,
    "name": "Import image",
    "status": active


**[Modified API] Import image to the backend**

Import image to the backend::

    POST /v2/images/​{image_id}​/import

This modifies the existing REST API to support a new header field which is
optional and if present specifies the store id to import the image data to.
For backwards compatibility, if the header is not specified the store
specified as the default (e.g. default_store) is used to import the image
to.

New header fields:

* X-Image-Meta-Store -- If present contains the store id to upload the image
  binary data to.

New / changed response codes:

* 400 -- If the X-Image-Meta-Store header is present, but specifies a
  store id for a store that doesn't exist by that id.

Example curl usage::

        curl -i -X PUT -H "X-Auth-Token: $token" -H "X-Image-Meta-Store:
            ceph1" -H "Content-Type: application/json"
            -d '{"method":{"name":"glance-direct"}}'
            $image_url/v2/images/{image_id}/import

Security impact
---------------

None

Notifications impact
--------------------

Need to add 'stores' field in the notification response as one of the use
case of this proposal is offering different price tiers for storage which
will help systems which consumes notifications to perform the billing.

Other end user impact
---------------------

This proposal introduces a few other user impacts worth noting.

**Glance client**
Ideally the glance client (CLI + REST client) should be updated in accordance
with this spec. Notably:

* CLI / API support for listing glance stores.
* CLI / API support for specifying a store id on upload/import.

**Configuration**
Deployers will need to be aware of the configuration aspects for glance
multi-store. From a conf point of view, configuring multi-store for glance
will look very much (from a high level) like configuring cinder for
multi-backend. The conf file specifics will need to be documented.

Performance Impact
------------------

A very little hit on the performance of downloading the image from the old
stores. For example, if existing user is using single rbd (say ceph)
backend and now he has upgraded the environment and introduced two
additional rbd stores as ceph1 and ceph2 with default store as 'ceph1'
then if image which needs to be download from old store (ceph) will
take some time as it needs to be looked in all the enabled backends.

Other deployer impact
---------------------

Once merged, glance multi-store is not enabled unless the deployer
configures the enabled_backends property in glance-api.conf and thus is backwards
compatible out-of-the-box. When multi-store is disabled, v2 API users can
use the list stores API and will retrieve a list of the current
stores configured (of course only 1 store per scheme).

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  abhishek-kekane

Other contributors:
  None

Work Items
----------

Implementation tasks may consist of:

* Conf support for multi-store.
* Multi-store loading and indexing.
* List stores API.
* Location URL metadata store id on upload.
* Add new 'store' attribute in image response.
* Image upload with store targeting.
* Image import with store targeting.
* Multi-store delete and other store access codepaths.
* Add python-glanceclient support


Dependencies
============

None


Testing
=======

* Need to add new tempest tests to verify multi-store support


Documentation Impact
====================

As mentioned in the 'work items' section, we'll need to ensure the glance docs
are update for:

* The new list stores REST API.
* New header field for image upload.
* New header field for image import.
* New store id in image response.
* Overall glance multi-store documentation to educate deployers on the
  feature and how it's used.


References
==========

* https://review.openstack.org/#/c/150967
