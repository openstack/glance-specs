..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=========================
Deprecate Glance Registry
=========================

Launchpad blueprint:

https://blueprints.launchpad.net/glance/+spec/deprecate-registry

Glance registry has, historically, helped to scale Glance by allowing for
centralizing the database access (glance-registry) while distributing the data
access (glance-api). In addition, it's helped as a safe-guard for the database
access credentials as it shouldn't be deployed as a public endpoint.

With the release and support of Glance's V2, the Glance Registry service has
become redundant, hence this proposal to deprecate it.

Problem description
===================

Glance Registry serves a very specific use case, which is to serve as a proxy
for the database operations in a Glance deployment. This use case came as part
of older Glance API versions and a certainly older architecture.

Unfortunately, it's becoming more of a burden to maintain it - development,
operations and documentation wise - than a benefit for the project itself.

From a development perspective, the team has to maintain the API updated for
every change in the database API. From an operational perspective, there's
another set of API nodes that need to be deployed, monitored, and upgraded. From
a documentation stand point, the team needs to make sure the service docs are
up-to-date, the best practices are spelled out and configuration files updated.

The benefits of this service have been discussed in a recent thread[0]_ on both,
developers and operators, mailing lists. The output of this thread is not really
conclusive, although it suggests there's no real use case for this service
anymore and that OPs would be better off by not having it.

Rolling upgrades was brought as a possible blocker for this deprecation. As it's
been explained in the thread[1], upgrading Glance (or even the planned work on
rolling upgrades) should not depend on the presence of this service. Anything
needed from Glance Registry should be possible to obtain from Glance API itself.

Glance Glare is not going to use Glance registry, which would also leave us with
an inconsistent deployment and a bad user experience.

Proposed change
===============

This spec proposes to deprecate the glance-registry service. Mark the service as
deprecated and ready for removal in the Q release.

Alternatives
------------

Keep maintaining the Glance Registry service.

Data model impact
-----------------

None

REST API impact
---------------

The public facing API won't be changed. The registry API will be deprecated and
not required anymore.

Security impact
---------------

Deployers will have to put the database credentials in the glance-api config
files. This might be seen as a security issue for some deployments as this means
an attacker that gains access to the glance-api server could potentially access
glance's database. However, this is not any different than what other services.

Notifications impact
--------------------

None

Other end user impact
---------------------

None

Performance Impact
------------------

This change should actually improve the overall performance as it'd get rid of
an extra step glance-api needs to go through to access the image metadata.

Other deployer impact
---------------------

Glance deployments will eventually have to move away from using the registry.
This can't be done for glance-api nodes using v1 but it can certainly be done
for v2-only nodes.

Developer impact
----------------

Less code to maintain, happier developers.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  flaper87

Other contributors:
  <launchpad-id or None>

Reviewers
---------

Core reviewer(s):
  rosmaita
  jokke
  nikhil

Other reviewer(s):
  <launchpad-id or None>
  <launchpad-id or None>

Work Items
----------

* Add a glance-api only job
* Mark the registry service as deprecated

Dependencies
============

* https://review.openstack.org/#/c/315190/

Testing
=======

Test a registry-less deployment in the OpenStack CI. 

Documentation Impact
====================

Document the motivations behind this deprecation and a recommended upgrade path
from Mitaka to Newton and on.

References
==========

.. [0] http://lists.openstack.org/pipermail/openstack-dev/2016-May/094773.html

.. [1] http://lists.openstack.org/pipermail/openstack-dev/2016-May/095144.html
