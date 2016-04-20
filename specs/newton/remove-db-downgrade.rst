..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===================
Remove DB downgrade
===================

https://blueprints.launchpad.net/glance/+spec/remove-db-downgrade


SQL Migrations are the accepted method for OpenStack projects to ensure that
a given schema is consistent across deployments. Often these migrations include
updating of the underlying data as well as modifications to the schema. It is
inadvisable to perform a downwards migration in any environment. As the bp[1]
has been approved through openstack-specs after Kilo, and many projects, such
as Nova, have implemented it, Glance should do it as well.

This spec proposed the work and Glance team would like to give users a cycle
to deprecate downgrade in their environments. So we will remove them during
Newton. In Mitaka, we'll add a deprecation warning to the DB downgrade.


Problem description
===================

Many migrations in OpenStack include data-manipulation to ensure the data
conforms to the new schema; often these data-migrations are difficult or
impossible to reverse without significant overhead. Performing a downgrade of
the schema with such data manipulation can lead to inconsistent or broken
state. The possibility of bad-states, relatively minimal testing, and no demand
for support renders a downgrade of the schema an unsafe action.


Proposed change
===============

1.Add a deprecation warning in Mitaka[3].
2.Remove the downgrade script in Newton.


Alternatives
------------

Downgrade paths can continue to be supported.

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

Users should make a full database backup of their production data before
attempting any upgrade[2].

Performance Impact
------------------

None

Other deployer impact
---------------------

Glance could not be downgrade any more after Newton and it's still work before
it.

Developer impact
----------------

As the downgrade will be remove in the future.There is no need to write new
downgrade script any more.


Implementation
==============

Assignee(s)
-----------

  wangxiyuan(wxy)

Reviewers
---------

  Flavio Percoco(flaper87)
  Nikhil Komawar(nikhil)

Work Items
----------

* Add a deprecation warning for users.
* Remove CLI script for downgrade.
* Remove downgrade migration.
* Document change.
* Add tests code to check there's no downgrade any more and avoid deployer to
  add new downgrade script.


Dependencies
============

None


Testing
=======

Write a test to confirm there is no downgrade in Glance any more.


Documentation Impact
====================

To show that downgrade is deprecated now and will not be supported after
Newton. And to indicate how to roll back the DB after that.


References
==========

[1]:http://specs.openstack.org/openstack/openstack-specs/specs/no-downward-sql-migration.html
[2]:http://docs.openstack.org/openstack-ops/content/ops_upgrades-roll-back.html
[3]:https://bugs.launchpad.net/glance/+bug/1501233
