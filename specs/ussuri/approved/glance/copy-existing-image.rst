..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

======================================
Copy existing image in multiple stores
======================================

https://blueprints.launchpad.net/glance/+spec/copy-existing-image

Despite the Image service supports several back ends for storing virtual
machine image, there is no way at the moment to copy existing image bits
into multiple stores and avoid the operator to manually copy data and update
image locations.

Problem description
===================

At the moment, if cloud provider decided to upgrade their cloud to Train
release to use the ability of glance of configuring multiple stores, then
there is no way to replicate/copy existing image bits to newly added
stores. As a result, operators today need to perform a number of manual steps
in order to replicate/copy image bits on glance stores despite using the
'enabled_backends' configuration option.

.. note:: Example

    An operator upgrades his existing setup of OpenStack cloud to configure
    different sites, each with their local glance stores which nova hosts
    are accessing directly (Ceph).

    This operator use multiple stores support and want its images to be
    available in each store to prevent the images to be downloaded through
    glance each time a new virtual machine is created and let Nova use COW.

    For this purpose, he need to manually copy existing images data in
    store2 to storeN and register these others locations URL using the
    glance API.

Since glance supports multi stores, it should propose a feature to copy
existing image data into these stores at once to facilitate operators' work.

Proposed change
===============

This spec depends on `Ability to import an image in multiple stores` [1]
to copy the image in multiple stores. In addition to above changes and
existing import methods `glance-direct` and `web-download`, this spec
proposes to introduce additional import method `copy-image`.

If the image from which data needs to be copied in multiple stores is not
in active state then the API should reject the request. If image exists
then it will be copied to staging area. Once copying to staging task is
completed, import task will import the data to all the specified stores. In
case of any failure during copying existing data to staging area or
successful completion of copying/importing data to specified store, image
data from the staging area will be removed.

Introduce one additional Task which will be internal plugin and allow
us to copy the existing image to staging area. To copy the existing image
into staging area, we will first give preference to `default_backend` of
that specific glance-api node. If image is not associated with
`default_backend` then we will iterate through all the available backends
of that specific glance-api node to copy(download) image from that location
to staging area. Failure mechanism will be same as dependent
spec `Ability to import an image in multiple stores` [1].

* If 'all_stores' boolean field is specified, the API should reject
  the request.

* If an unavailable image is specified, the Api should reject the request.

* If an unavailable store is specified, the Api should reject the request.

* If image is already present at specified location, the Api should reject
  the request.

* If base image is deleted while copying the data to new stores, then the
  copying process will be terminated and copied data will be removed as well.

* If 'all_stores_must_succeed' is set to 'true' (default behavior) and an
  error occurs during the upload in at least one store, the request should
  be rejected, the data will be deleted from stores where copying is done
  (not staging), and the state of the image remains the same.

* If 'all_stores_must_succeed' is set to 'false', the request will fail
  (data deleted from stores, ...) only if the upload fails on all stores
  specified by the user. In case of a partial success, the locations added
  to the image will be the stores where the data has been correctly uploaded.

* In case of failures or successful completion of copying/importing data
  to specified stores, image data from staging will be removed.

Users will be able to follow copying/importing operation progress by
looking at 2 reserved image custom properties:

* os_glance_importing_to_stores: This property contains the list of stores
  that has not yet been processed. At the beginning of the copy/import flow,
  it will be filled with the stores provided in the request. Each
  time a store is fully handled, it will be removed from the list. This
  property will be emptied at the end of the process even if an error occurs
  and there are still remaining stores.

* os_glance_failed_import: Each time an import in a store fails, it is added
  to this list. This property is emptied at the beginning of the copy/import
  flow.

Image locations will be updated each time an upload/copy in a store succeed
(with information from this store).

Current location strategies modules should not be affected by theses changes as
we don't change the behavior of the image locations. It is currently possible
to do the same by patching an image and specify a list of locations.

In the same vein, as it is already an option to choose a store when using
import workflow, there is no need to add a new policy to restrict the
copying of image in multiple stores.

Alternatives
------------

Continue copying images manually to different stores and update the locations
using Locations API.

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

* Expected error http response codes: 400, 401, 404, 409, 410

    * 400: `Bad Request` with details.
    * 401: `Unauthorized`
    * 404: `Not Found` (image doesn't exist or is not owned by the caller)
    * 409: `Conflict` (image is not in appropriate status)
    * 410: `Gone` (Image deleted while operation in progress)

**API Version**

This change will require minor version bump.
All URLS will be under the v2 Glance API.  If it is not explicitly specified
assume /v2/<url>

**[Modified API] Import image to the store**

Import image to the store::

    POST /v2/images/{image_id}/import

  If present, copy this image in multiple stores specified using `stores`
  option.

Example curl usage::

        curl -i -X POST -H "X-Auth-Token: $token"
             -H "Content-Type: application/json"
             -d '{"method":{"name":"copy-image"},
                  "stores": ["ceph1", "ceph2"],
                  "allow_failure": false}'
             $image_url/v2/images/{image_id}/import

Security impact
---------------

None

Notifications impact
--------------------

Notification will be sent for each of the successful copy of image.

Other end user impact
---------------------

None

Performance Impact
------------------

As we'll write data in multiple stores, this will increase the IO from the
glance nodes in accordance of the number of stores specified.
From the user point of view, the import workflow will also take more time
depending on the stores where the copying is done.

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

* abhishekk

Reviewers
---------

Core reviewer(s):

* jokke
* rosmaita

Work Items
----------

Implementation tasks may consist of:

* Write new internal plugin to copy image data in staging area

Dependencies
============

None

Testing
=======

Appropriate unit and functional tests to ensure the changes to glance function
correctly. The major testing item is to ensure that if the copy taskflow fails,
data will be deleted only from the new stores, not from the stores where image
is already in and image status does not change.

Documentation Impact
====================

We'll need to ensure the glance docs are updated for:

* New body field for image import.
* New import method for image import.

References
==========

* [1] https://review.opendev.org/#/c/669201
* PoC - https://review.opendev.org/696457
