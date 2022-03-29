..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=============================================
Expanding stores-info detail for other stores
=============================================

https://blueprints.launchpad.net/glance/+spec/expanding-stores-detail

Problem description
===================

In Yoga release we added a new API (GET /v2/info/stores/detail) which exposes
the store specific details of a store.  At the moment the Discovery API only exposes
the store details and properties of the RBD backend. We want to make the API more
generic and  expose details of  other stores also.

Proposed change
===============

We will be extending the functionality of Discovery (GET /v2/info/stores/detail) API
which will expose the store specific details about the store like store type and other
specific store properties of other stores like cinder, swift, filesystem etc.
Options that can be beneficial to be exposed for different stores :

*  Cinder: cinder_volume_type
* Filesystem: filesystem_store_dir, chunk_size, thin_provisioning, filesystem_store_dirs
* Swift: container, obj_size and chunk_size
* S3: s3_store_large_object_size, s3_store_large_object_chunk_size, s3_store_thread_pools

We will use the existing method ``get_store_from_store_identifier`` which returns
the store class instance and will utilize it to fetch the store specific information
to return it via API.

Alternatives
------------

None

Data model impact
-----------------

None

REST API impact
---------------

With this new implementation, we will now be returning the "properties" value for other
stores(apart from RBD).

.. code-block:: console

  GET /v2/info/stores/detail

The output will be as follows:

.. code-block:: python

  {
      "stores": [
          {
              "id":"reliable",
              "type": "rbd",
              "description": "Reliable RBD store",
              "default": true,
              "properties": {
                  "pool": "pool1"
                  "chunk_size": 65553
                  "thin_provisioning": false
              }
          },
          {
              "id":"cheap",
              "type": "file",
              "description": "Cheap file store",
              "properties": {
                  "datadir": "fdir"
                  "chunk_size": 65553
                  "thin_provisioning": false
              }
          },
          {
              "id":"fast",
              "type": "cinder",
              "description": "Fast Cinder Store",
              "properties": {
                  "volume_type": "volume1"
                  "use_multipath": false
              }
          },
          {
              "id":"slow",
              "type": "swift",
              "description": "Slow Swift store",
              "properties": {
                  "container": "container1"
                  "obj_size": 52428
                  "chunk_size": 204800
              }
          },


      ]
  }

Security impact
---------------

This API does expose some additional sensitive information, but only to admins,
consistent with other things we already expose.

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

None

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  mrjoshi, whoami-rajat

Other contributors:
  None

Work Items
----------

* Fetch details from the specific store/backed and return it in the API response

Dependencies
============

None

Testing
=======

* Unit Tests
* Functional Tests

Documentation Impact
====================

Add documentation providing details about the properties exposed for each store

References
==========

https://review.opendev.org/c/openstack/glance-specs/+/817391
https://review.opendev.org/c/openstack/glance/+/824438
