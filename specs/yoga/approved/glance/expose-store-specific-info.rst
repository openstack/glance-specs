..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=================================
Expose store specific information
=================================

https://blueprints.launchpad.net/glance/+spec/expose-store-specific-info

Problem description
===================

When we upload a volume from cinder's RBD backend as an image to glance's
RBD backend, the generic code path to copy data chunk by chunk is executed,
which makes the operation very slow. This can be optimized by using COW cloning
for rbd backends and for this Cinder requires store type and rbd specific store
info from glance side.

Proposed change
===============

At the moment the Discovery (GET /v2/info/stores) API provides the list of
multiple-backend present and the default store but not the type of the stores.

We will be extending the functionality of Discovery (GET /v2/info/stores) API
by adding a new API (GET /v2/info/stores/detail) which will expose the store
specific details about the store like store type and other specific store
properties.

Since the store specific information is mostly intended for other services
(like cinder) or operators to consume and not for end users, this operation
will be admin only and we will introduce a new policy ``stores_info_detail``,
that will default to admin only rule, to restrict this for non-admin users.
In future, when the ``service`` role will be in place in keystone to facilitate
service to service interaction, this policy rule will be adjusted accordingly.

We will use the existing method ``get_store_from_store_identifier`` which returns
the store class instance and will utilize it to fetch the store specific information
to return it via API in a defined format. For more details see `REST API impact`_ section.

Alternatives
------------

None

Data model impact
-----------------

None

REST API impact
---------------

We are going to add a new API ``GET /v2/info/stores/detail`` which will return
the store details like store type and store specific properties.
It will be validated by the new policy rule ``stores_info_detail`` which defaults
to admin only and then the detailed info related to the stores will be returned.

.. code-block:: console

  GET /v2/info/stores/detail

The output will be as follows:

.. code-block:: python

  {
      "stores": [
          {
              "id":"reliable",
              "type": "rbd",
              "description": "More expensive store with data redundancy",
              "default": true,
              "properties": {
                  "pool": "pool1"
              }
          },
          {
              "id":"cheap",
              "type": "file",
              "description": "Less expensive store for seldom-used images",
              "properties": {}
          },
      ]
  }

We are going to add a field ``type`` to specify the type of store.
Also we will add a field ``properties`` which will be a JSON object type and
contain the store specific properties. For the current usecase we are only
going to add RBD store info and leave the properties for other stores as empty
JSON objects ``{}``.

Security impact
---------------

Since this optimization skips the writing of image that happens on the glance side,
it will also skip the checksum and hash value calculated in that scenario.
Due to the above case, we will add a new config option on the cinder side to
enable/disable this optimization. By default, it will be disabled.

Another case is we require direct-url and image locations in the image detail
response to take benefit of any optimization in nova-glance or cinder-glance
interactions which is a security concern described in OSSN-0065.

Notifications impact
--------------------

None

Other end user impact
---------------------

A new optional parameter ``--detail`` will be added to the stores info command on
glanceclient side.

The parameter will accept boolean values. If ``True``, it will expose store specific
information else will show the non-detailed information about stores as it works currently.

* Stores Detail: ``glance stores-info --detail``

  --detail  With sufficient permissions, display additional information about the stores.

Performance Impact
------------------

Uploading volume to image incase of cinder RBD to glance RBD will be
significantly improved.

+------------------------------------+---------------+---------------+---------------+
|             Image size             |      2GB      |     3GB       |      5GB      |
+====================================+===============+===============+===============+
| Time without COW clone             | 1min17Sec     | 1min15Sec     | 2min49Sec     |
+------------------------------------+---------------+---------------+---------------+
| Time with COW clone                | 1.29Sec       | 2.32Sec       | 1.63Sec       |
+------------------------------------+---------------+---------------+---------------+
|                                    | **-98%**      | **-97%**      | **-99%**      |
+------------------------------------+---------------+---------------+---------------+



Other deployer impact
---------------------

None

Developer impact
----------------

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

* Add an optional parameter ``--detail`` in the stores-info command on the
  glanceclient side.
* Add a new API to glance ``GET /v2/info/stores/detail``.
* Create a new policy ``stores_info_detail`` that will default to admin only
  rule and enforce it if detail flag is passed.

Dependencies
============

None

Testing
=======

* Unit Tests
* Functional Tests
* Tempest Tests

Documentation Impact
====================

A new section for the new API ``GET /v2/info/stores/detail`` needs to be added
in the api-ref.

References
==========
https://review.opendev.org/c/openstack/cinder-specs/+/810363
