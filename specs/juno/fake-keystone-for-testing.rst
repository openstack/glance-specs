..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================================
Fake Keystone Server for Functional Tests
==========================================

The URL of the launchpad blueprint:

https://blueprints.launchpad.net/glance/+spec/fake-keystone-for-testing

As keystone is only supported auth method for glance we should be doing our
functional tests against keystone pipeline as well.

Problem description
===================

Currently we are defaulting the Glance authentication pipeline to noauth.
This is not supported configuration with glance and causes some issues.

* Default config cannot be changed to keystone pipeline unless we have
  Keystone functionality available during our tests as the servers are spun
  up with default configuration as well as with the test specific one.

* Functional tests does not reflect to real world as they uses unsupported
  authentication pipeline. Also certain functionalities (like using registry
  with v2) cannot be tested as noauth does not provide the needed user
  information.

Proposed change
===============

Fake Keystone server with minimal functionality would solve this issue without
increasing the overhead for our testing too much:

Needed functionality would be:

* Support for auth token verification (this can be done with pre determined
  set of tokens and token management would not be needed)

* Support for user - password authentication (this can also be done with pre
  determined set of user/password combinations and user management would not
  be needed).

Alternatives
------------

Monkey patching the code we are actually testing to act against the design
agreed when implemented. This would allow us to pass the test issues, but
leave a hole for unwanted behaviour to pass tests.

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

This would potentially harden the security as the functional tests would be
ran against more real life like configuration.

Notifications impact
--------------------

None

Other end user impact
---------------------

None

Performance Impact
------------------

There is impact on test performance as more processes are needed to run the
tests.

This can be circumvented by more coarse functional testing as agreed on weekly
Glance meeting (14:39):
http://eavesdrop.openstack.org/meetings/glance/2014/
glance.2014-06-05-14.05.log.html

Other deployer impact
---------------------

None

Developer impact
----------------

Better visibility of how changes affects due to better testing experience.


Implementation
==============

Assignee(s)
-----------

  Erno Kuvaja <jokke>

Work Items
----------

* Implementation of the Fake Keystone server

* Changing the functional tests using it

* Refactoring the functional tests to circumvent the performance hit / improve
  the performance


Dependencies
============

None


Testing
=======

As this is testing functionality/change testing of it would not be needed.


Documentation Impact
====================

None


References
==========

None
