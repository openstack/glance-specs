..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

========================================
Replace Snet Config with Endpoint Config
========================================

https://blueprints.launchpad.net/glance/+spec/replace-snet-config-with-endpoint-config

The snet option forces the deployer to name the desired endpoint after
the public endpoint.

Problem description
===================

The snet option forces the deployer to name the desired endpoint after
the public endpoint. In order to switch between multiple internal
networks, names have to be changed.

Proposed change
===============

Instead of constructing a URL with a prefix from what is returned by
auth, specify the full URL via configuration (e.g.
https://www.example.com/v1/not_a_container). The location of an object
is obtained by appending the container and object to the configured URL.

Alternatives
------------

Only use auth v2. Store and retrieve multiple internal endpoints from the
catalog. This is the preferred approach and requires migrating code that is
using v1 to v2 which is a much larger and completely separate effort.
Furthermore, a configurable endpoint could still be useful for overriding
catalog.

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

Configuration options will change:

- Removed config option: "swift_enable_snet". The default value of
  "swift_enable_snet" was False [1]. The comments indicated not to change this
  default value unless you are Rackspace [2].

- Added config option "swift_store_endpoint". The default value of
  "swift_store_endpoint" is None, in which case the storage url from the auth
  response will be used. If set, the configured endpoint will be used. Example
  values: "swift_store_endpoint" = "https://www.example.com/v1/not_a_container"

1. https://github.com/openstack/glance/blob/fd5a55c7f386a9d9441d5f1291ff6a92f7e6cc1b/etc/glance-api.conf#L525
2. https://github.com/openstack/glance/blob/fd5a55c7f386a9d9441d5f1291ff6a92f7e6cc1b/etc/glance-api.conf#L520

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  jesse-j-cook

Reviewers
---------

Core reviewer(s):
  nikhil-komawar

Other reviewer(s):
  johngarbutt
  ben-roble

Work Items
----------

* Modify code to use endpoint config
* Remove snet prefix code


Dependencies
============

None


Testing
=======

* Verify auth works
* Verify configured endpoint is reached

Documentation Impact
====================

* Document new endpoint configuration option.
* Remove documentation for snet confiugration option.


References
==========
https://review.openstack.org/#/c/139726/
