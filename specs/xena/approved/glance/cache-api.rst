..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=========
Cache API
=========

https://blueprints.launchpad.net/glance/+spec/cache-api

Managing split deployments is currently a bit difficult and sometimes require
operators to run commands on multiple nodes. Introducing a cache API would make
managing such deployments easier.


Problem description
===================

Adding new API endpoints related to caching would prove beneficial in two ways:

* Along with the planned work on cluster awareness, this would make it easier to
  manage split deployments (multiple glance-api nodes on different locations)
* Users would have to deal with fewer commands since the
  glance-cache-prefetcher is now part of glance-api as a periodic job and
  glance-cache-manage will now be part of python-glanceclient.


Proposed change
===============

The main change this specification describes is the extension of the Glance API
to handle cache-related operations. The goal is to have an API that can replace
the "glance-cache-manage" tool. These are the operations we would like to
support:

* List cached,queued images
* Delete cached, queued images
* Delete all cached and queued images using single API call
* Queue image for prefetching

At the moment to enable the glance caching in the deployment operator needs
to configure two different middleware, `cache` and `cachemanage`. `cache`
middleware is responsible for configuring cache resources such as cache
directory, initializing cache driver etc. whereas `cachemanage` middleware
used to deal with actually caching resources via glance-api. As caching
now will be part of glance V2 API, we would like to deprecate `cachemanage`
middleware and remove it as per `deprecation and removal` policy. The newly
added cache endpoints will be ``EXPERIMENTAL`` in this cycle and will be
marked as stable in following cycle.

In addition to above proposed change this will introduce three new policies
`cache_image`, `cache_list` and `delete_cache` so that user with appropriate
permissions can perform these operations. We will also deprecate the existing
`manage_image_cache' policy in favor of new policies. To make the new
policies compatible with secure RBAC we need to ensure to pass required
parameters like ImageTarget while enforcing the new policies. It is recommended
to keep `cache_image`, `cache_list` and `delete_cache` operations limited to
admin use only.

Alternatives
------------

If we do nothing about cluster awareness and we do not provide an easy-to-use
API for cache management, operators could probably write homemade solutions to
aggregate data from multiple nodes, but this would be error-prone and not
user-friendly.


Data model impact
-----------------

None

REST API impact
---------------

This spec proposes the following new endpoints:

**New API**

* List cached and queued images
* Delete a cached or queued image
* Delete all cached or queued images
* Queue image for caching

**Common Response Codes**

* Create Success: `201 Created`
* Delete Success: `204 No Content`
* Failure: `400 Bad Request` with details.
* Forbidden: `403 Forbidden`


**[New API] List cached or queued images**

List all images cached or queued for caching on this node::

    GET /v2/cache
    {
       "cached_images": [
          {
             "id": "d75b9181-e1ce-45b4-8147-fb66fc4ea82f",
             "last_accessed": 1560451015.977297,
             "last_modified": 1560451015.977297,
             "size": 12345,
             "hits": 42,
             "checksum": "6788146b9d3fddc8dd03d86bfe9239b0"
          },
       ],
       "queued_images": [
           "id": "d75b9181-e1ce-45b4-8147-fb66fc4ea82f",
       ]
    }

Response codes:

* 200 -- Upon authorization and successful request. The response body
  contains the JSON payload with the cached and queued images.


**[New API] Delete a queued or cached image**

Delete a specific image from the cache::

    DELETE /v2/cache/​{image_id}​

Response codes:

* 204 -- The image was deleted
* 403 -- Permission denied

**[New API] Delete all queued or cached images**

Delete all queued or cached images::

    DELETE /v2/cache

Response codes:

* 204 -- The cache was purged
* 403 -- Permission denied

**[New API] Queue an image for caching**

Pre-cache an image::

    PUT /v2/cache/​{image_id}​

Response codes:

* 202 -- The request has been accepted, the image will be queued for caching
* 403 -- Permission denied
* 404 -- Image not found

Security impact
---------------

As described in proposed change section either existing policies or
new policies will be enforced to avoid security breach.

Notifications impact
--------------------

None


Other end user impact
---------------------

The glance client should be updated, with new commands:

* glance cache-list
* glance cache-image <IMAGE-ID>
* glance cache-delete <IMAGE-ID>
* glance cache-delete-all

Provision will be made to pass direct URL (host:port) to these commands
which will direct the call to particular glance node. Implementation
details for the same will be described in specific glance-client spec.

Performance Impact
------------------

None

Other deployer impact
---------------------

Caching will be local to each glance node and as these commands will be
executed remotely, operator needs to know the direct URL of each glance
node which are behind the load balancer. Operator need to provide this
direct URL to glanceclient so that client should hit particular node
to retrieve the cache information of that node.

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  jokke

Other contributors:
  cyril-roelandt

Work Items
----------

* Deprecate `cachemanage` middleware
* Add new cache endpoint (/v2/cache)
* Make new policies compatible with secure RBAC
* Add python-glanceclient support
* Deprecate glance-cache-manage
* Deprecate glance-cache-prefetcher
* Modify documentation, update API reference
* Devstack support to enable cache on remote node


Dependencies
============

None


Testing
=======

* The new API endpoints should be tested using Tempest tests.


Documentation Impact
====================

* The API documentation will need to be updated
* Need to update Cache documentation as well with new commands


References
==========

* https://docs.openstack.org/glance/victoria/admin/cache.html
