..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

========================================
Pass Targets to Glance's Policy Enforcer
========================================

https://blueprints.launchpad.net/glance/+spec/pass-targets-to-policy-enforcer

Currently it's possible to define custom rules in Glance's ``policy.json``
that rely on attributes other than a user's roles. Unfortunately, if you
attempt to apply one of those rules, it will always cause the user to be
prevented from performing the associated action. This specification proposes
that we pass the proper target objects to the enforcer so these rules can be
used and properly enforced.


Problem description
===================

Currently, Glance promises that permissions can be configured in the
``policy.json`` file but any rule other than a role check currently
results in a ``403 Forbidden`` response. As this is a promised feature,
implementing this specification is merely fixing the already promised
behaviour.

It is not possible to restrict access to actions in Glance's ``policy.json``
based on anything other than a user's roles. The policy enforcer that Glance
extends from oslo expects a dictionary-like object to be passed as a target of
the action. Every method that uses the policy enforcer and enforces the policy
defined for the corresponding action currently passes an empty dictionary
(``{}``) which provides absolutely no data about the actual target.

If we define a rule similar to the following::

   "tenant_is_owner": "tenant%(owner)s"

And we apply it to an action, e.g.,

::

   "delete_image": "rule:tenant_is_owner"

Then every request to delete any image will be denied with a 403
(Unauthorized) response from Glance's API. The reason stems from how the rule
is parsed and the target is passed in. The ``"rule:tenant_is_owner"`` rule
will be parsed as a ``GenericCheck``. These checks are split on the ``:`` into
a ``kind`` and a ``match`` (roughly, ``"<kind>:<match>"``). The match portion
is then interpolated with the target, i.e.,

.. code-block:: python

   match = self.match % target

So using our example above, we would do

.. code-block:: python

   match = "%(owner)s" % {}

Except that this raises a ``KeyError`` which means the check immediately
returns ``False`` and fails. In this particular instance (deleting an image),
if we passed an instance of ``glance.api.policy.ImageTarget``, then what would
instead happen is that the interpolation would succeed.


Proposed change
===============

The solution for image-based resources is simple. We have the ``image`` on the
policy proxies that relate to images. We simply pass that to
``glance.api.policy.ImageTarget`` and pass the resulting instance to the
policy enforcer so it can be accessed like a dictionary when interpolated.
For members and tasks, there is no target class that we can use. These are
very thin classes that could easily be written.

Once we have the appropriately defined target classes, we would then update
the places where the policy is enforced to use instances of those target
classes.

With proper targets in place, we can also implement safer default policy rules
for operators who rely solely on the default ``policy.json`` file.

Alternatives
------------

Custom rule creation based on attributes of the target object could be
disabled. This would severely limit an operator's ability to restrict actions
based on a user's tenant and other properties of the target of the action.

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

This will give operators a significant amount of control over the security of
their Glance installations. Currently they can only restrict actions based on
roles which may be sufficient in some cases. If the operator, however, wishes
to restrict access based on other factors (besides role) they cannot do this.
If they try to do it, there is no indication that it will not work but they
can essentially produce a Denial of Service to users who should be able to
perform actions based on the policy defined.

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

To leverage the fixes in this specification, operators need to update their
versions of ``policy.json`` used in their deployments. To write a rule,
operators need to know that there are three values provided by glance that can
be used in a rule on the left side of the colon (``:``). Those values are the
current user's credentials in the form of:

- role
- tenant
- owner

The left side of the colon can also contain any value that Python can
understand, e.g.,:

- ``True``
- ``False``
- ``"a string"``
- &c.

Role checks are going to continue to work exactly as they already do. If the
role defined in the check is one that the user holds, then that will pass,
e.g., ``role:admin``.

Using ``tenant`` and ``owner`` will only work with Images or actions that
interact with an image. Consider the following rule::

    tenant:%(owner)s

This will use the ``tenant`` value of the currently authenticated user. It
will also use ``owner`` from the image it is acting upon. If those two
values are equivalent the check will pass. All attributes on an image (as well
as extra image properties) are available for use on the right side of the
colon. The most useful are the following:

- ``owner``
- ``protected``
- ``is_public``

An operator, therefore, could construct a set of rules like the following::

    {
        "not_protected": "False:%(protected)s",
        "is_owner": "tenant:%(owner)s",
        "not_protected_and_is_owner": "rule:not_protected and rule:is_owner",
        "delete_image": "rule:not_protected_and_is_owner"
    }

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  icordasc

Reviewers
---------

Core reviewer(s):
  nikhil-komawar
  jokke

Other reviewer(s):
  kragniz

Work Items
----------

- Create appropriate target classes
- Use target classes to proxy targets to the policy enforcer
- Add tests demonstrating that generic checks now work
- Add better documentation surrounding policy rules to the existing
  documentation

Dependencies
============

None


Testing
=======

Functional tests will be added where specific ``policy.json`` files are loaded
to test access control of different targets.


Documentation Impact
====================

There is no direct impact, but the existing ``policy.json`` documentation is
thin and only describes what each rule controls. It does not describe the
available target information or how to write rules.


References
==========

Related bugs:

- https://bugs.launchpad.net/glance/+bug/1253963
- https://bugs.launchpad.net/glance/+bug/1346648

Initial work at an implementation:

- https://review.openstack.org/#/c/146651/

Glance meeting discussion on 2015 January 15:

- http://eavesdrop.openstack.org/meetings/glance/2015/glance.2015-01-15-14.02.log.html
