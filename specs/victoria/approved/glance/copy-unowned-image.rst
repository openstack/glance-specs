..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=======================================
Allow copying unonwned images by policy
=======================================

https://blueprints.launchpad.net/glance/+spec/copy-unowned-image

Currently Glance has a mechanism which allows a user to copy images
between two (or more) backend stores. That only works for images that
they themselves own, which covers many of the use-cases for the
feature. However, considering different types of clouds, admins may
want users to be able to copy images between stores that they do not
own for the purposes of performance optimization and storage
efficiency.


Problem description
===================

Currently a user may only copy images that they own, and there is no
way to allow otherwise. This may lead to anti-pattern behavior, such
as downloading an image and re-uploading it so that it can be
copied. Further, it may prevent optimizations, such as a user
pre-copying a public image to a store for an edge site to improve boot
time, and CoW re-use.

Specifically, Nova is working on a feature to automate storage
efficiency improvements, which rely on this ability in many
cases. Glance has supported multiple backend stores for some time, but
Nova (specifically the ceph/rbd image backend) can only cooperate with
Glance on a single ceph cluster. If multiple clusters are involved,
the worst-case scenario is that Nova ends up downloading the image
from Glance via HTTP and then uploads it to the ceph backing store as
a private-to-the-instance base image. This results in a loss of
fast-snapshot capability as well as massive storage inefficiency. See
`Nova spec for glance multistore capability`_.


Proposed change
===============

Allow the `copy-image` import method to check policy for permission
instead of hard-coding "is admin or owner" behavior. If granted by
policy, use an admin context to kick off the actual import task on
behalf of the requesting user.

Because the "is admin or owner" behavior is baked deep into many
layers in Glance, enabling this requires some substantial work. As a
part of this process, the import task will coalesce all image
operations that may be delegated to a non-owner into a single location
to aid in auditing. If and only if the policy grants this permission
(which is only possible for `copy-image`) then an admin-capable
`ImageRepo` will be provided to the task for use in image property
manipulation.

When the `copy-image` operation is performed by a user other than the
owner through this mechanism, it should be clear that the ownership of
the image (and any new resources created in the process) remains
unchanged.

Alternatives
------------

* One alternative is to just say "sorry, only owned images may be
  copied."

* Another alternative is to have Nova store Glance admin credentials,
  and effectively implement the policy check on their side, using an
  admin user to copy the image if and when necessary.

Data model impact
-----------------

None.

REST API impact
---------------

No new APIs or return codes are added. There is a small implied
behavioral change in the form of users potentially being able to copy
images they could not before.

Security impact
---------------

As with any policy change, there is a potential for unintentional
granting of elevated permission to some users. Assuming the code is
correct, this is no different from other policy knobs. The default
policy for this operation will remain as "is admin or owner" so no
actual change will happen unless the operator so elects.

There is also a potential impact with the use of an admin context for
the operation which has more power to inflict damange or leak
information than there would be otherwise. This effect is mitigated by
the following design points:

* The admin context is not passed to the import task, but rather used
  only to grab an admin-capable `ImageRepo` which is given to the
  task.

* All of the related actions done as admin on behalf of the user are
  confined to a single "actions" object for easy auditing.

* This is only (currently) applied to the `copy-image` import method,
  which means that (ideally) the maximum privilege escalation would be
  copying an image that the user can already see to a new backend
  store.

Notifications impact
--------------------

None.

Other end user impact
---------------------

None.

Performance Impact
------------------

No impact on Glance, but there is a net positive impact to the overall
system in the case where Nova is able to use this feature to co-locate
an image in the backend of a given remote site.

Other deployer impact
---------------------

None.

Developer impact
----------------

There are a number of changes to layers in the onion between the API
and the task itself. This is mostly around the optional `admin_repo`
argument that may be passed through `gateway`, `proxy`, and down to
the task.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  danms

Work Items
----------

* Add tests that validate the current behavior which provide a
  measurement of the change as the feature takes shape.

* Refactor the task creation code to allow passing an optional
  `admin_repo` from the API to the task.

* Add a `context.elevated()` helper, like other projects have, which
  keeps the user's context mostly whole but with admin privileges.

* Refactor the `api_image_import` module to consolidate all image
  operations that will need to be delegated to the `admin_repo` if it
  is passed from the API.

* Add a policy action for `copy_image` which is the primary knob by
  which an admin can enable this feature.

* Update documentation for the `copy-image` method of `image_import`
  to explain the expectations of the admin, owner, and user delegate
  when non-owners are allowed to do this.

Dependencies
============

None.

Testing
=======

* New functional and unit tests will be added before the actual
  changes are made to validate current behavior. Each patch along the
  way will modify or augment those to test the new behavior and ensure
  there are no regressions.

* Nova will ultimately gain a test job that deploys multiple stores,
  including one rbd-backed store, and will initiate a `copy-image`
  import on behalf of a tempest ephemeral tenant that does not own the
  public cirros image.


Documentation Impact
====================

Documentation is likely needed around the policy knob, explaining what
it does, how to use it, and why an admin may want to use it.

References
==========

.. _Nova spec for glance multistore capability: https://specs.openstack.org/openstack/nova-specs/specs/victoria/approved/rbd-glance-multistore.html
