..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===========================================
Provision for immediate caching of an image
===========================================

Include the URL of your launchpad blueprint:

https://blueprints.launchpad.net/glance/+spec/instant_caching

Provision for immediate caching of a given image on a particular glance node.


Problem description
===================

In Yoga we have added support for caching related operations under V2 API, but
still we need to depend on existing periodic job to cache the actual image.
This means user/deployer/admin needs to wait until next periodic job to run
for caching of an actual image. Even though default time for periodic job is
300 seconds (5 minutes) it may vary deployment wise and the user has to wait
until the actual image is cached.


Proposed change
===============

We are proposing to remove existing periodic job from glance-api and modify
existing ``PUT /v2/cache/{image_id}`` API which will queue an image for caching
and start caching it immediately. If any existing instant caching operation is
in progress then the latest image will be added to the queue so that it will
be picked up for caching as soon as previous operation completes. User can use
``GET /v2/cache`` API call to see the size of the queue.

Alternatives
------------

Instead of modifying existing API, we can add a new POST API which will start
immediate caching of specified image. We can use existing policy `cache_image`
so that user with appropriate permissions can perform this operation. To make
the policy compatible with secure RBAC we need to pass required parameters
like ImageTarget while enforcing the policy. It is recommended to keep
`cache_image` operation limited to admin use only.

Another alternative solution could be, instead of removing the old periodic
job, the new API should trigger the periodic job instantly to cache all the
images rather than just caching a specified image at a time. This
solution need to be thread safe as there might be a chance of existing
periodic job is already running or new periodic job will start running while
we trigger the same via API.

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

None

Notifications impact
--------------------

None

Other end user impact
---------------------

None

Performance Impact
------------------

None

Other deployer impact
---------------------

Caching is and will remain local to each glance node and as this command
will be executed remotely, operator needs to know the direct URL of
each glance node which are behind the load balancer. Operator needs to
provide this direct URL to glanceclient so that client should hit
particular node to trigger immediate caching on that node.

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  dansmith or abhishekk

Other contributors:
  None

Reviewers:
  cyril-roelandt/rosmaita/jokke/pdeore/mrjoshi

Work Items
----------

* Modify existing API (PUT /v2/cache/{image_id})
* Remove the 'cache_prefetcher_interval' config option and related tests.
* Modify documentation, update API reference
* Tempest coverage for Caching operations


Dependencies
============

None


Testing
=======

* All new cache API should be tested using tempest tests


Documentation Impact
====================

* The API documentation will need to be updated
* Need to update Cache documentation as well with new information


References
==========

* https://docs.openstack.org/glance/victoria/admin/cache.html
