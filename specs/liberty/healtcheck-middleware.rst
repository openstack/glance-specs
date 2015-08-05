..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

======================
HealthCheck Middleware
======================

https://blueprints.launchpad.net/glance/+spec/healthcheck-middleware

HealthCheck Middleware provides <SERVER>:<PORT>/healthcheck endpoint. This
endpoint behaves similar way as it does in Swift[1]. Normal operations returns
200 OK and if config option disable_path is enabled and that path exists
it will return 503 DISABLED BY FILE.


Problem description
===================

Currently Glance does not have any reasonable means to provide health check
information for example to HAProxy. Any such deployment causes extensive
logging and causes unnecessary operations in the server end (FE. GET request
to / which leads to version check).


Proposed change
===============

Take advantage of ``oslo.middleware``\ 's healthcheck middleware by:

#. Adding a new paste filter - ``healthcheck``
#. Adding the new filter to the default Glance API and Registry pipelines

Disabled functionality would allow using a file in the filesystem to return
503 DISABLED BY FILE response dropping the node from the HAProxy. This would
allow the nodes disabled to finish their current operations and improve
maintenance experience in HA deployments.

Alternatives
------------

Current operations model.

Take Swift's slightly smaller implementation and copy it directly into
Glance's source tree.

Data model impact
-----------------

None

REST API impact
---------------

GET '/healthcheck' 200 OK, 503 DISABLED BY FILE

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

Potential performance improvement as healthcheck is done quite frequently
and the middleware is lightweight filter at the start of the pipeline.

Other deployer impact
---------------------

healthcheck would be added to the the start of the used pipeline to be used.
Optional disable_path=PATH option would be needed to the config files to
enable the discreet disable functionality.

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  jokke
  kamil-rykowski

Core Reviewers:
  kragniz
  flaper87
  icordasc

Work Items
----------

Code Change
Tests
Config Change
Documentation Change


Dependencies
============

None


Testing
=======

Simple functional tests to verify the responses form the <SRV>:<P>/healthcheck


Documentation Impact
====================

Documentation changes are quite minimal explaining the new config option and
functionality.

References
==========

[1] _https://github.com/openstack/swift/blob/master/swift/common/middleware/healthcheck.py
