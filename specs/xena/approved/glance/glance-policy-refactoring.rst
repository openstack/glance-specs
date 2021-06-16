..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

========================
Policy Layer Refactoring
========================

https://blueprints.launchpad.net/glance/+spec/policy-refactor

During implementation of V2 Image API in glance an Onion layered architecture
was introduced. The reason behind implementing the layered architecture was to
avoid regression in any layer if either of the layer is modified. Glance has
a separate layer for Policy injections which is closer to database rather than
API. This spec will act as a Master specification for policy refactoring and
have several spec-lite's to explain respective implementation details.

Problem description
===================

The current policy enforcement occurs in Policy layer. As such, it is
conceptually tied to the objects implemented in the Glance architecture. A
problem with this design, which has only revealed itself as the v2 API has
matured, is that operators want to use policies to control who can make API
calls (as they can with most other OpenStack services). In Glance, however,
policies directly affect the objects dealt with internally by Glance, and only
indirectly affect who can make API calls. This makes it difficult for operators
to configure Glance.

In addition, while implementing Secure RBAC in glance we also noticed that
certain API calls enforce multiple policies down the layer. For example
in case of `modify_image` policy it enforces `get_image` policy which
enforces `get_image_location` policy. This can be confusing for operators
modifying the policy for `modify_image` and wondering why it hasn't taken
effect if the `get_image` policy or `get_image_policy` short-circuits the
operation.


Proposed change
===============

We need a better way of handling policies:

1. One of the major proposals is to move the actual policy enforcement up to
   the API layer so that an operator can, for example, easily restrict access
   to a particular call. Most of the OpenStack projects have policy
   enforcements closer to API layer, so these efforts will also put us more
   in-line with the current thinking of policy enforcement.

2. Make `get_*` policies be enforced only while showing particular resource
   rather than enforcing it for each API call. For example `get_image` policy
   should be enforced only for showing particular image to end user and not for
   other API calls such as update, delete, upload or download image.

3. Backward compatibility will be maintained while moving policies closer to
   API layer. (NOTE: RBAC related changes are not considered here.)

4. At the moment our unit and functional tests are referring to policy.yaml
   file from the test repo, instead our default policies should be used and
   overridden as and when required.

5. In order to test new policy changes with RBAC we need two different CI jobs
   which will run our tests with old policies as well as with the new RBAC flag
   enabled.

Note: Some of the above changes will have its own spec lite to further discuss
the implementation details.

Alternatives
------------

Keep it as it is and use hacks while implementing other scopes of Secure RBAC.

Data model impact
-----------------

None

REST API impact
---------------

No changes to the REST API, but see "Other Deployer Impact" section, below.

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

Considering experimental support added for project scope realted to Secure
RBAC, operators need to understand which policies to govern and how to
configure them properly. Also, there's likely to be some tweaking and
testing of any custom policies during upgrade to Xena (or beyond).

Developer impact
----------------

Developers will have to be more aware of policies and where policy enforcement
must happen.


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  dansmith
  abhishek-kekane

Other contributors:
  pdeore

Work Items
----------

* Move API specific policy checks up to the API layer
* Enforce `get_*` policies at API layer only
* Enforce resource specific policies close to database layer
* Policy enforcement should be compatible with secure RBAC structure
* Tests should run using default policies and not policy.yaml
* New CI jobs to run tempest tests with and without Secure RBAC enabled

Dependencies
============

None


Testing
=======

As explained in Work Items section our unit and functional tests need
to use our default polices in code rather than policy.yaml file. We also
need new CI jobs to run tempest tests with and without Secure RBAC
enabled.


Documentation Impact
====================

Policies are documented in code, so the documentation will be updated as the
refactoring occurs.


References
==========

* https://review.opendev.org/q/topic:%22policy-poc%22+(status:open%20OR%20status:merged)

* https://bugs.launchpad.net/glance/+bug/1915582
