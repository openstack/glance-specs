..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

================
Rolling upgrades
================

https://blueprints.launchpad.net/glance/+spec/rolling-upgrades

This spec provides a gap analysis of what is required for the Glance project to
assert the various rolling upgrade tags and specifies the actions necessary to
close the gaps.

The goal for Ocata is to assert the ``assert:supports-zero-downtime-upgrade``
tag, with a stretch goal of asserting the
``assert:supports-zero-impact-upgrade`` tag.  Given that asserting these tags
depends on completion of another feature (see spec proposal [GSP1]_), the
backup goal is to assert the ``assert:supports-rolling-upgrade`` tag.  In any
case, Glance will make progress on the upgrade front in this cycle.

Problem description
===================

There are currently four upgrade tags:

* ``assert:supports-upgrade`` [GOV3]_
* ``assert:supports-rolling-upgrade`` [GOV1]_
* ``assert:supports-zero-downtime-upgrade`` [GOV4]_
* ``assert:supports-zero-impact-upgrade`` [GOV5]_

supports-upgrade
----------------

The ``assert:supports-upgrade`` tag [GOV3]_ has been asserted for Glance
[GOV0]_.

supports-rolling-upgrade
------------------------

The requirements for asserting the ``assert:supports-rolling-upgrade`` tag are
listed in [GOV1]_.  They are:

* The project is already tagged as ``type:service`` [GOV2]_.

  * Glance status: done

* The project has already successfully asserted the ``assert:supports-upgrade``
  tag [GOV3]_.

  * Glance staus: done

* The project has a defined plan that allows operators to roll out new code to
  subsets of services, eliminating the need to restart all services on new code
  simultaneously.

  * Glance status: need to define a plan.

    More detail about the required plan, as described in [GOV1]_:

        This plan should clearly call out the supported configuration(s) that
        are expected to work, unless there are no such caveats. This does not
        require complete elimination of downtime during upgrades, but rather
        reducing the scope from “all services” to “some services at a time.” In
        other words, “restarting all API services together” is a reasonable
        restriction.

    The Glance services consist of the Glance API server and the optional
    Glance Registry API server.  The Glance Registry API server is not
    intended to be exposed to end users or other OpenStack services; it is
    expressly designed for internal Glance use only.

    (Note that it's OK for there to be specific configurations under which a
    rolling upgrade is expected to work.  In particular, it's likely that we
    will require deployments using the optional Glance registry to run it on
    dedicated nodes.)

    Glance has had healthcheck middleware that can be used to signal to a load
    balancer that an API node is out of service since the Liberty release
    [GLA2]_.  This can be leveraged to take Glance nodes running "old" code out
    of rotation while nodes running "new" code are brought in.

    Note that while this proposal will allow a mixed deployment of API versions
    to run simultaneously, it does not envision that this will include multiple
    versions of the API running *on the same node* simultaneously.  In other
    words, we do not intend to support a scenario in which "new" API code is
    deployed to a node while "old" Glance processes are running on that node.
    Instead, we expect operators to allow the "old" nodes to drain completely
    and all processes running the "old" code to be stopped before the "new"
    code is deployed to that node.  (If the Glance nodes are VMs, a completely
    drained node could simply be deleted and be replaced by a fresh VM
    containing the "new" code.)

* Full stack integration testing with services arranged in a mid-upgrade manner
  is performed on every proposed commit to validate that mixed-version services
  work together properly.

  * Glance status: needs to be implemented (but note that the tests required
    for the next tag would more than satisfy this requirement).

supports-zero-downtime-upgrade
------------------------------

The ``assert:supports-zero-downtime-upgrade`` tag indicates that a project
supports minimal rolling upgrade capabilities in such a way that no disruptions
to API availability occur during the upgrade.

The requirements for asserting this tag are listed in [GOV4]_.  They are:

* The project is already tagged as ``type:service`` [GOV2]_.

  * Glance status: done

* The project has already successfully asserted both the
  ``assert:supports-upgrade`` and ``assert:supports-rolling-upgrade`` tags.

  * Glance status: the ``assert:supports-rolling-upgrade`` tag has not yet
    been asserted.  See the previous section for what's required.

* Services must completely eliminate API downtime of the control plane during
  the upgrade.

  * Glance status: The key issue is how to handle database changes required for
    release N while release N-1 code is still running.  This is addressed by
    another spec, "Database strategy for rolling upgrades" [GSP1]_.

* Services must be capable of receiving and handling requests throughout the
  upgrade process with a normal success rate.  Services must prevent regression
  by implementing a zero-downtime gate job wherein both a new version of the
  service and an old version of the service are run concurrently.

  * Glance status: needs to be implemented.

supports-zero-impact-upgrade
----------------------------

The ``assert:supports-zero-impact-upgrade`` tag indicates that a project
supports both rolling upgrade capabilities and a zero-downtime upgrade (as
described above) in such a way that no perceivable API performance penalty
occurs during the upgrade.

The requirements for asserting this tag are listed in [GOV5]_.  They are:

* The project is already tagged as ``type:service``.

  * Glance status: done

* The project has already successfully asserted the
  ``assert:supports-upgrade``, ``assert:supports-rolling-upgrade``, and
  ``assert:supports-zero-downtime-upgrade`` tags.

  * Glance status: see the previous sections.

* Services must completely eliminate any perceivable performance
  penalty during the upgrade process. Operators should not
  expect any portion of the upgrade or migration process to place abnormally
  high load on any part of the cloud, or to cause delays in the handling of API
  requests, even intermittently.

  * Glance status: Given that we're talking about Glance services only (not the
    DBMS and not the storage backend), this should be achieved when the
    zero-downtime upgrade is implemented.

* Services must prevent regression by implementing a zero-impact gate job
  wherein both a new version of the service and an old version of the service
  are run concurrently under load. A measurement of API response times must
  show that there are no statistically significant outliers during the upgrade
  process when compared to normal operations.

  * Glance status: needs to be implemented.


Proposed change
===============

There are two major changes:

#. Process Documentation

   What we need to establish is that the Glance project has "a defined plan
   that allows operators to roll out new code to subsets of services,
   eliminating the need to restart all services on new code simultaneously."

   The "Gaps" section of the Product Working Group's "Rolling Updates and
   Upgrades" user story [PWG1]_ provides a useful list of the phases an
   operator would go through in performing a rolling upgrade of an OpenStack
   cloud.  We propose to document the relevant phases clearly for Glance so
   that operators can understand the Glance rolling upgrade story.

   The phases identified by the Product Working Group are:

   #. Maintenance Mode
   #. Live Migration
   #. Upgrade Orchestration - Deploy
   #. Multi-version Interoperability
   #. Online Schema Migration
   #. Graceful Shutdown
   #. Upgrade Orchestration - Remove
   #. Upgrade Orchestration - Tooling
   #. Upgrade Gating
   #. Project Tagging

   For Glance, upgrading from release N-1 to release N, we can compress these
   into:

   #. **Upgrade Orchestration - Deploy**

      * stage the code for release N to new Glance nodes

   #. **Online Schema Migration** - Part 1

      * initial database schema migration (the "expand" phase as described
        in [GSP1]_)
      * background data migration (as described in [GSP1]_)

   #. **Multi-version interoperabilty**

      * start the release N nodes
      * take the release N-1 nodes out of rotation, allowing them to drain

   #. **Upgrade Orchestration - Remove**

      * take each release N-1 node offline once it has completed processing its
        current requests

   #. **Online Schema Migration** - Part 2

      * final database schema migration (the "contract" phase as described
        in [GSP1]_)

#. Testing

   Full stack integration testing with services arranged in a mid-upgrade
   manner is performed on every proposed commit to validate that mixed-version
   services work together properly.

   * This testing must be performed on configurations that the project
     considers to be its reference implementations.

   * The arrangement(s) tested will depend on the project (i.e. should be
     representative of a meaningful-to-operators rolling upgrade scenario) and
     available testing resources.

   * At least one representative arrangement must be tested full-stack in the
     gate.

We propose using Grenade [GRN1]_ for the full stack integration tests.

Alternatives
------------

1. One alternative would be to choose not to support rolling upgrades in
   Glance.  Such a choice, however, would impact other services that depend
   upon Glance (for example, Nova).  Such services would experience disruptions
   during the Glance upgrade.  So this doesn't seem to be a serious
   alternative.

2. The proposal in this spec is to use the "disable by file" feature of the
   oslo healthcheck middleware to take the Glance nodes running "old" code out
   of rotation and allow them to drain.  Stuart McLaren has suggested an
   alternative, namely to piggyback on the zero downtime configuration reload
   feature of Glance (available since the Kilo release [GLA1]_) and create a
   "graceful stop" function that would accept a signal to shut down child
   processes as they complete.  (See [GSP2]_ for details.)

   Since we've got the "disable by file" functionality available, this
   alternative isn't necessary to achieve the upgrade tags.  It would, however,
   be an operator-friendly enhancement that we could pick up at some point.

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

It is anticipated that a rolling upgrade will require operator intervention.

Developer impact
----------------

Developers will need to be aware of Glance features that enable rolling
upgrades and make sure they aren't removed.  (Developers will also need to work
within the constraints of the database strategy for rolling upgrades, but that
developer impact is covered by another spec.)


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  rosmaita
  hemanthm

Other contributors:
  nikhil

Work Items
----------

* Verify the accuracy of current Glance upgrade documentation.

* Write documentation for rolling upgrade (developer docs).

* Write documentation for rolling upgrade (operator docs).

* Grenade tests.

* Assert the tag and notify the OpenStack Technical Committee.


Dependencies
============

To achieve the ``assert::supports-zero-downtime-upgrade`` tag, this spec
depends upon implementation of the spec "Database strategy for rolling
upgrades" [GSP1]_.

Testing
=======

We'll need to implement gate tests (see above).

Documentation Impact
====================

* Documentation of general information for Glance rolling upgrades, in
  particular:

  * The supported configuration(s) for rolling upgrades

  * The operator workflow for performing a rolling upgrade

References
==========

.. [GLA1] https://review.openstack.org/#/c/122181/
.. [GLA2] https://review.openstack.org/#/c/148595/
.. [GOV0] https://review.openstack.org/#/c/245897/
.. [GOV1] https://governance.openstack.org/reference/tags/assert_supports-rolling-upgrade.html
.. [GOV2] https://governance.openstack.org/reference/tags/type_service.html
.. [GOV3] https://governance.openstack.org/reference/tags/assert_supports-upgrade.html
.. [GOV4] https://governance.openstack.org/reference/tags/assert_supports-zero-downtime-upgrade.html
.. [GOV5] https://governance.openstack.org/reference/tags/assert_supports-zero-impact-upgrade.html
.. [GRN1] https://github.com/openstack-dev/grenade
.. [GSP1] https://review.openstack.org/#/c/331740/
.. [GSP2] https://review.openstack.org/#/c/331489/8/specs/ocata/approved/glance/rolling-upgrades.rst@75
.. [PWG1] http://specs.openstack.org/openstack/openstack-user-stories/user-stories/proposed/rolling-upgrades.html
