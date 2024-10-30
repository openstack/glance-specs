..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===========================================
New API to list nodes where Image is cached
===========================================

https://blueprints.launchpad.net/glance/+spec/list-nodes-image-cached

Deployer would like to see on which glance worker nodes an image is
cached in one API call.


Problem description
===================

As of today if you have configured multiple glance nodes and you need
to see whether image is cached on particular node then you need to
query to that particular glance node or query each glance node for the
same.

Use case, In a DCN environment you want to see whether that particular
edge node has image cached or not.


Proposed change
===============

Glance now by default uses a centralized database for cache, which allows
us to have access to all cached images across glance nodes. We are
adding a new admin only API which will accept ``image_id`` as an input
parameter and will return us the direct URL of all  glance nodes where
that particular image is cached.

We will also introduce a new policy ``list_cached_nodes`` so that users
with appropriate permissions can perform this operation.

If caching is not enabled in deployment or deployment is not using
centralized database for caching then this API will return HTTP
409 Conflict response to the user.

In the future we can use this API from consumers like nova or cinder
in such a way that they can directly send the API request to
particular glance node where the image is cached.

Alternatives
------------

None

Data model impact
-----------------

None

REST API impact
---------------

This spec propose the following new API:

**New API**

* List nodes where image is cached

**Common Response Codes**

* Accepted: `200 Accepted`
* Forbidden: `403 Forbidden`
* Conflict: `409 Conflict`
* Not Found: `404 Not Found`

**[New API] List nodes where image is cached**

List nodes::

    GET /v2/cache/nodes/{image_id}
    {
        "cached_nodes": [
            http://node_1:60999,
            http://node_2:60999,
            http://node_5:60999,
         ],
    }

Security impact
---------------

As described in proposed change section new policy will be enforced
to avoid security breach.

Notifications impact
--------------------

None

Other end user impact
---------------------

The glance client and openstack client should be updated, with new commands:

* glance cache-nodes-list <image_id>
* openstack cache nodes list <image_id>

Performance Impact
------------------

None

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
  abhishekk

Work Items
----------

* Introduce new API call
* Enforce new policy rule
* Documentation
* Testing

Dependencies
============

None

Testing
=======

New tempest test to cover this scenario

Documentation Impact
====================

* The API documentation will need to be updated
* Need to update Cache documentation as well with new commands

References
==========

* https://docs.openstack.org/glance/victoria/admin/cache.html
