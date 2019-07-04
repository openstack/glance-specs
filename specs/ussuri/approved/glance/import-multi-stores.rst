..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=============================================
Ability to import an image in multiple stores
=============================================

https://blueprints.launchpad.net/glance/+spec/import-multi-stores

Despite the Image service supports several back ends for storing virtual
machine image, the import workflow only allow to push image data in one
store. The goal of this spec is to allow this workflow to import image data
into multiple stores and avoid the operator to manually copy data and update
image locations.

Problem description
===================

At the moment, the import workflow only allow to push image data in one
store. As a result, operators today need to perform a number of manual steps
in order to replicate image bits on backend glance stores despite using the
'enabled_backends' configuration option.

.. note:: Example

    An operator provides an Openstack cloud with different sites, each
    with their local stores which nova hosts are accessing directly (Ceph).

    This operator use multiple stores support and want its images to be
    available in each store to prevent the images to be downloaded through
    glance each time a new virtual machine is created and let Nova use COW.

    For this purpose, when creating a new image, he needs to use the import
    workflow to store image data in store. Since the image is now in status
    "ACTIVE", he can't use the import workflow anymore and need to manually
    upload data in store2 to storeN and register these others locations URL
    using the glance API.

Since glance supports multi stores, it should propose a feature to upload
image data into these stores at once to facilitate operators' work.

Proposed change
===============

This spec proposes the following high level feature to support multiple
stores import:

* Enhance the image import API to support targeting a list of stores for the
  image bits.

The idea is to provide a new 'stores' array field in the json payload where
the user will list all stores he wants to import its data in (example:
['ceph_fast', 'ceph_cheap']).

If an unavailable store is submitted, the Api should reject the request.

If user or operator wants to import the image to all the enabled stores then
it might be difficult or overhead to specify all the stores in the list.
For that purpose a boolean field 'all_stores' will be provided.

* If set to false (default behavior), we use the logic previously described.

* If set to true, the data will be imported to the set of stores you may
  consume from this particular deployment of Glance (ie: the same set of stores
  returned to a call to /v2/info/stores on the glance-api the request hits).
  This can't be used simultaneously with the 'stores' parameter.
  If user submits both, the Api should reject the request.

Another boolean field, 'all_stores_must_succeed', will be added in the payload
to specify which error behavior the user wants to be applied:

* If this field is set to 'true' (default behavior) and an error occurs
  during the upload in at least one store, the request should be rejected, the
  data deleted from stores (not staging), and the state of the image remains
  the same.
  The status of the image will be set to 'ACTIVE' only  when the request is
  fully executed and successful.

* If this field is set to 'false', the request will fail (data deleted from
  stores, ...) only if the upload fails on all stores specified by the user.
  In case of a partial success, the locations added to the image will be the
  stores where the data has been correctly uploaded.
  The status of the image will be set to 'ACTIVE' as soon as an upload in
  one store is fully executed and successful.

Image locations will be updated each time an upload in a store succeed (with
informations from this store).

Users will be able to follow task progress by looking at 2 reserved image
properties:

* os_glance_importing_to_stores: This property contains a list of stores that
  has not yet been processed. At the beginning of the import flow, it will
  be filled with the stores provided in the request. Each time a store is
  fully handled, it will be removed from the list.

* os_glance_failed_import: Each time an import in a store fails, it is added
  to this list. This property is emptied at the beginning of the import flow.

If the image is deleted during the process of the request, import to
remaining stores will not be processed and already uploaded data should be
deleted.

Current location strategies modules shouldn't be affected by theses changes as
we don't change the behavior of the image locations. It is currently possible
to do the same by patching an image and specify a list of locations.

In the same vein, as it is already an option to choose a store when using
import workflow, there is no need to add a new policy to restrict the import in
multiple stores.


Alternatives
------------

An alternative to this solution would be to allow to import data on an image
with status 'ACTIVE'.
This will be the subject of another spec.

Data model impact
-----------------

None

REST API impact
---------------

This spec proposes the following API changes:

**Modified APIs**

* Import an image.

**Common Response Codes**

* Normal http response code: 202

    * 202: `Accepted`

* Expected error http response codes: 400, 401, 403, 404, 409, 410

    * 400: `Bad Request` with details.
    * 401: `Unauthorized`
    * 404: `Not Found` (image doesn't exist or is not owned by the caller)
    * 409: `Conflict` (image is not in appropriate status)
    * 410: `Gone` (image deleted while operation in progress)

**API Version**

This change will require minor version bump.
All URLS will be under the v2 Glance API.  If it is not explicitly specified
assume /v2/<url>

**[Modified API] Import image to the store**

Import image to the store::

    POST /v2/images/{image_id}/import

This modifies the existing REST API to add three new optional body fields.
For backwards compatibility, if the 'stores' parameter is not specified, the
header 'X-Image-Meta-Store' is evaluated.
If neither parameter i.e. 'X-Image-Meta-Store' header and 'stores' are
specified then the store configured as default (e.g. default_backend) is used
to upload the image to.
If both parameters are supplied, or 'all_stores' parameter is set to true and
'X-Image-Meta-Store' header or 'stores' are set, the request will be rejected
as Bad Request (ie: http 400).

New body fields:

* stores -- (String Array)
  If present contains the list of store id to import the image binary data to.
* all_stores -- (Boolean, default to false)
  If set to true, the data will be imported in all configured stores.
  If set to false, 'stores' and/or 'X-Image-Meta-Store' are evaluated.
* all_stores_must_succeed -- (Boolean, default to true)
  If set to false, the task will fail only if import fails in all specified
  stores.
  If set to true, the task will fail if import fails in one of the mentioned
  store.

Changed response codes:

* 400 -- If the 'stores' field is present, but specifies a list of store id
  with at least one id that doesn't exist or is read-only (like http).
  Or, if any two or more of the three 'all_stores':'true', 'stores',
  'X-Image-Meta-Store' are specified.

Example curl usage::

        curl -i -X POST -H "X-Auth-Token: $token"
             -H "Content-Type: application/json"
             -d '{"method":{"name":"glance-direct"},
                  "stores": ["ceph1", "ceph2"],
                  "all_stores_must_succeed": false}'
             $image_url/v2/images/{image_id}/import

Security impact
---------------

None

Notifications impact
--------------------

When going through the image import workflow, the payload sent during
notification stages already contains a field "backend" which contains the
store specified by the user when using multiple backend support.
Notifications should be sent for each store asked by the user containing
the status of the upload to that particular store.
The new properties will be added to the notification payload.

.. note:: Example

    An operator calls the import image api with the following parameters::

        curl -i -X POST -H "X-Auth-Token: $token"
             -H "Content-Type: application/json"
             -d '{"method": {"name":"glance-direct"},
                  "stores": ["ceph1", "ceph2"],
                  "all_stores_must_succeed": false}'
            $image_url/v2/images/{image_id}/import

    The upload fails for 'ceph2' but succeed on 'ceph1'. Since the parameter
    'all_stores_must_succeed' has been set to 'false', the task ends
    successfully and the image is now active.

    Notifications sent by glance should look like (payload is truncated for
    clarity)::

        {
            "priority": "INFO",
            "event_type": "image.prepare",
            "timestamp": "2019-08-27 16:10:30.066867",
            "payload": {"status": "importing",
                        "name": "example",
                        "backend": "ceph1",
                        "os_glance_importing_to_stores": ["ceph1", "ceph2"],
                        "os_glance_failed_import": [],
                        ...},
            "message_id": "1c8993ad-e47c-4af7-9f75-fa49596eeb10",
            ...
        }

        {
            "priority": "INFO",
            "event_type": "image.upload",
            "timestamp": "2019-08-27 16:11:30.058812",
            "payload": {"status": "active",
                        "name": "example",
                        "backend": "ceph1",
                        "os_glance_importing_to_stores": ["ceph2"],
                        "os_glance_failed_import": [],
                        ...},
            "message_id": "8b8993ad-e47c-4af7-9f75-fa49596eeb11",
            ...
        }

        {
            "priority": "INFO",
            "event_type": "image.prepare",
            "timestamp": "2019-08-27 16:10:30.066867",
            "payload": {"status": "importing",
                        "name": "example",
                        "backend": "ceph2",
                        "os_glance_importing_to_stores": ["ceph2"],
                        "os_glance_failed_import": [],
                        ...},
            "message_id": "1c8993ad-e47c-4af7-9f75-fa49596eeb10",
            ...
        }

        {
            "priority": "ERROR",
            "event_type": "image.upload",
            "timestamp": "2019-08-27 16:11:30.058812",
            "payload": {"status": "active",
                        "name": "example",
                        "backend": "ceph2",
                        "os_glance_importing_to_stores": [],
                        "os_glance_failed_import": ["ceph2"],
                        ...},
            "message_id": "8b8993ad-e47c-4af7-9f75-fa49596eeb11",
            ...
        }

Other end user impact
---------------------

**Glance client**

The glance client (CLI + REST client) must be updated in accordance with this
spec. Notably:

* CLI / API support for specifying a list of store id on import.
* CLI / API support for specifying all_stores_must_succeed option on import.

Performance Impact
------------------

As we'll write data in multiple stores, this will increase the IO from the
glance nodes in accordance of the number of stores specified.
From the user point of view, the import workflow will also take more time
depending on the stores where the upload are done.

Other deployer impact
---------------------

None

Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:

* yebinama

Reviewers
---------

Core reviewer(s):

* jokke

Work Items
----------

Implementation tasks may consist of:

* Image import with a list of stores supplied.
* Add python-glanceclient support

Dependencies
============

None

Testing
=======

Appropriate unit and functional tests to ensure the changes to glance function
correctly.

Documentation Impact
====================

We'll need to ensure the glance docs are updated for:

* New body fields for image import.

References
==========

* https://review.opendev.org/#/c/667132/
