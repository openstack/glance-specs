..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================================
HTTP Proxy Support for Glance S3 Driver
==========================================

https://blueprints.launchpad.net/glance/+spec/http-proxy-support-for-s3

Currently the S3 store does not allow operators to connect to an S3 backend
through a proxy. This can create limitations on the ability to connect to the
S3 backend securely from a different network. I propose to add the option to
use a proxy to connect to an S3 backend.

Problem description
===================

If glance store is configured to use the S3 backend and the backend is behind
a private network and needs to be accessed remotely, there is no secure way
to access the S3 backend securely.


Proposed change
===============

Boto, the library that is used to make the connection to the S3 backend,
already supports proxy configurations. I propose that we enable the connection
to accept additional config options to give users the option to connect
through a proxy.

The following configurations would be added:

* s3_store_enable_proxy: Enables the use of a proxy
* s3_store_proxy_host: The proxy server (required when proxy is enabled)
* s3_store_proxy_port: The port to connect to the proxy
* s3_store_proxy_user: The username of the proxy connection.
* s3_store_proxy_password: The password to be used to connect through the proxy.


Alternatives
------------

The user can use system wide proxy parameters, but would limit the ability to
connect from an outside network.

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

This would introduce security settings to be modified by user. The ability to
connect through a proxy will provide a good way to secure connections.

Notifications impact
--------------------

None

Other end user impact
---------------------

This introduces proxy configuration options in the store configuration.

Performance Impact
------------------

None

Other deployer impact
---------------------

This change will have to be explicitly configured in the store options.


Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  cpallares

Reviewers
---------

Core reviewer(s):
  flaper87
  sigmavirus24

Other reviewer(s):
  rosmaita

Work Items
----------

* Add configurations (proxy name, port, user, password, default number of
  retries to S3, etc).
* Modify connections made to S3 to optionally accept proxy parameters.
* Create additional unit tests for connections made to the S3 backend using a
  proxy.

Dependencies
============

None


Testing
=======

Unit testing will be needed for testing proxy connection.

Documentation Impact
====================

Documentation for the S3 store will need to be updated to include proxy opts.

References
==========

* `Boto S3 Docs`_
* `OpenStack Security Guidelines`_

..  _Boto S3 Docs: https://boto.readthedocs.org/en/latest/ref/s3.html
..  _OpenStack Security Guidelines: https://wiki.openstack.org/wiki/Security/Guidelines
