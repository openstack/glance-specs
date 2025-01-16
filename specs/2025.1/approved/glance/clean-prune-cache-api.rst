..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==================================
API for cleaning and pruning cache
==================================

https://blueprints.launchpad.net/glance/+spec/clean-prune-cache-api

New API calls for cleaning and pruning image cache directories.


Problem description
===================

As of today if image caching is enabled in the deployment, then deployer
need to configure glance-cache-cleaner and glance-cache-pruner as
cron jobs so that invalid image cache files gets cleaned periodically
and if cache directory oversized then old cache files gets deleted
automatically. This is an overhead for the deployer to make sure
cron jobs are configured and running effectively.


Proposed change
===============

We are propsing to deprecate `glance-cache-cleaner`, `glance-cache-pruner`
and `glance-cache-prefetcher` command line tools in this cycle and remove
them in ``G`` developemnt cycle. As we already have an API call
``/v2/cache/{image_id}`` to cache an image, similarly we will add two
new API POST calls ``/v2/cache/clean`` and ``/v2/cache/prune`` which will
do the job of pruning and cleaning for us. These two APIs will be admin
only and non-admin user will be restricted to use it.

We will introduce two new policies ``cache_clean`` and ``cache_prune``
default to used by ``admin`` for restricting the use of these new
APIs.


Alternatives
------------

Instead of adding new API calls we can move existing code to reuse
it as a periodic call under glance API service. This will need
to introduce two additional configuration parameters to introduce
interval of periodic calls.

Data model impact
-----------------

None

REST API impact
---------------

This spec propose the following new APIs:

* Clean invalid cached images

**[New API] Clean invalid cached images**

Clean invalid cached images::

    POST /v2/cache/clean
    {}

Response codes:
* 200 -- Upon authorization and successful request.
* 403 -- Permission denied

* Prune image cache directory

**[New API] Prune image cache directory**

Prune image cache directory::

    POST /v2/cache/prune
    {}

    * JSON response body

    .. code-block:: json

        {
            "total_files_pruned": <total_files_pruned>,
            "total_bytes_pruned": <total_bytes_pruned>
        }

Response codes:
* 200 -- Upon authorization and successful request.
* 403 -- Permission denied


Security impact
---------------

As described in proposed change section new policies will be enforced
to avoid security breach.

Notifications impact
--------------------

None

Other end user impact
---------------------

The glance client and openstack client should be updated, with new commands:

* glance cache-clean
* glance cache-prune
* openstack cache clean
* openstack cache-prune

Performance Impact
------------------

None

Other deployer impact
---------------------

Deployer needs to stop using ``glance-cache-cleaner``, ``glance-cache-pruner``
and ``glance-cache-prefetcher`` command line tools in the environment.

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

* Introduce new API calls
* Enforce new policy rules
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

* The API documentation needs to be updated
* Need to update Cache documentation as well with new commands

References
==========

* https://docs.openstack.org/glance/victoria/admin/cache.html
