..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

====================================
Download Image from Suggested Stores
====================================

https://blueprints.launchpad.net/glance/+spec/download-from-specific-store

Right now when you download an image using GET /v2/images/{image_id}/file,
Glance tries the default store first. If the image is not there, it tries
other stores until it finds the image. This spec adds a way to tell Glance
what ordering to use to locate the image data for a particular request.
You can give a list of stores you want to try. This helps compute nodes and
services like Nova and Cinder download from stores that are close to them.

Problem description
===================

In deployments with multiple stores, images can be in different places like
Swift, Cinder, filesystem, or S3. Right now Glance downloads from the default
store first. If not there, it tries other stores one by one until it finds
the image.

This has problems:

* Services cannot say which store to use
* Services cannot pick a faster store or one that is close to them
* Operators cannot test if a specific store is working
* Cannot spread downloads across different stores

The store weight feature from 2023.2 lets operators set store priorities. But
this is only for operators. Services like Nova and Cinder cannot choose stores
based on where they are running.

Use cases:

Services can find available stores using existing APIs like GET /v2/info/stores
and GET /v2/info/stores/detail. These show store names, descriptions, types,
and properties that help decide which store to use.

* Performance: A compute node can download from a local store instead of a
  remote one
* Proximity: Edge compute nodes can download from stores close to them (like
  "us-east" or "eu-west")
* Testing: Operators can test if a specific store works
* Load distribution: Spread downloads across stores so one store does not get
  too much load

Cost concerns:

If users can pick any store, they might pick expensive ones. For example, if
there is a backup store on S3, downloading from it costs money for data egress.
Users may not know this. To fix this, operators can use policy to control who
can use this feature. Operators can also use good store names and descriptions
to guide users to cheaper stores.

Proposed change
===============

Add new query parameters to the existing download endpoint. This lets services
suggest the ordering of stores to try.

API call:
GET /v2/images/{image_id}/file?prefer=store1,store2

How it works:

1. If caching is enabled, and the image is cached, the 'prefer' parameter
   is ignored and the data is returned.
2. Check if the stores in the list exist and are configured. Return errors
   if store does not exist.
3. Try stores from the list in order. Download from the first store that
   has the image.
4. If image is not found in any of the listed stores, fall back to default
   behavior (try all stores)

This approach is better than a new endpoint because:

* Does not add another download API
* Easy for Nova and Cinder to add preferred stores without big changes
* Still backward compatible - if no parameters given, works like before

.. note::

   Important cache behavior: Store preference parameters only work when
   fetching images from backend stores, not when serving from cache. When an
   image is cached, the cache middleware serves it directly and bypasses the
   store preference logic entirely. This means cached images will always return
   HTTP 200 regardless of store parameters, and store preference validation (400
   errors for invalid stores) will not occur for cached images.

Policy for store preference:

A new policy rule "download_from_store" will be added to control who can use
store preference parameters. The default policy will allow anyone who can
download images to also use store preference. This matches the current behavior
where store preference is available to all users who can download. Deployers
can restrict this policy later if needed. For example, they can make it admin
or service role only to prevent regular users from picking expensive stores.

Alternatives
------------

1. New endpoint approach: Create GET /v2/stores/{store_id}/{image_id}/file
   endpoint. This follows the same pattern as delete-from-store API. But it
   only allows one store at a time. Services would need to make multiple calls
   to try different stores. This makes things slower and more complex.

2. Header-based approach: Use HTTP headers to say which store. But headers are
   harder to discover and use.

3. Store weight only: Use the existing store weight from 2023.2. But this only
   works at operator level. Services cannot choose stores based on where they
   run.

4. No change: Keep current behavior. But this does not let services pick stores
   close to them.

Data model impact
-----------------

None

REST API impact
---------------

Modified endpoint: GET /v2/images/{image_id}/file

New query parameters:

* prefer: Comma-separated list of store names (optional)

Response codes:

* 200 OK: Image downloaded
* 400 Bad Request: Invalid store name or bad parameters
* 403 Forbidden: User does not have permission to use this feature
* 404 Not Found: Image not found

Examples:

Download from preferred stores:

  curl -H "X-Auth-Token: $TOKEN" \
    "http://glance-api:9292/v2/images/{image_id}/file?prefer=local-store,backup-store"

Download normal way (no change):

  curl -H "X-Auth-Token: $TOKEN" \
    "http://glance-api:9292/v2/images/{image_id}/file"

Store discovery:

Services can find available stores using GET /v2/info/stores:

  curl -H "X-Auth-Token: $TOKEN" \
    "http://glance-api:9292/v2/info/stores"

Response example:

.. code-block:: json

  {
    "stores": [
      {"id": "local-store", "description": "Fast local store"},
      {"id": "backup-store", "description": "S3 backup store"}
    ]
  }

Backward compatibility:

If no query parameters are given, the endpoint works exactly like before. This
means existing code keeps working without any changes.

Security impact
---------------

Access control:

The normal image download policy still applies. Users must have permission to
download the image. A new policy rule "download_from_store" controls who can
use store preference parameters. By default, anyone who can download images can
also use store preference. Deployers can restrict this policy later if needed.

Store validation:

Glance will check that store names are valid and configured before trying to
use them.

No new data exposure:

This only changes which store to download from. Users can only download images
they already have access to.

Notifications impact
--------------------

None

Other end user impact
---------------------

User docs and API reference need updates to explain the new query parameters.

Performance Impact
------------------

Positive impact:

Services can pick faster stores or stores close to them. This can make downloads
faster.
uncached requests.

Other deployer impact
---------------------

Store management:

Deployers should use good store names and descriptions. This helps services
pick the right stores. For example, "local-fast" vs "backup-s3" makes it clear
which is local and which is expensive.

Cost considerations:

Services might pick expensive stores like S3 backup stores without knowing the
cost. To handle this:

* Use clear store names to show which stores are expensive
* Add policy rules to limit who can use store suggestion
* Consider making this admin or service role only initially

Policy controls:

Operators can add optional policy rules to control who can use this feature.
This can be based on user roles or projects.

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

1. Add query parameter parsing to download endpoint
2. Implement store list validation
3. Add policy support for store suggestion control
4. Add logic to try stores from the list, fallback to default if not found
5. Add unit tests for new parameters
6. Add functional tests for different scenarios
7. Update API documentation

Dependencies
============

None

Testing
=======

* Add required unit and functional tests
* Add tempest tests

Documentation Impact
====================

* Update API documentation
* Update user docs
* Update operator docs

References
==========

* Store weight specification: https://specs.openstack.org/openstack/glance-specs/specs/2023.2/approved/glance_store/store-weight.html
* Store weight implementation: https://review.opendev.org/c/openstack/glance_store/+/885595
