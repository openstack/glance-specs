..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

======================================================
Reuse the deleted image-member before create a new one
======================================================

https://blueprints.launchpad.net/glance/+spec/reuse-the-deleted-image-member

Check the deleted image-member before create a new one, then update it if it
exists, otherwise, create a new one.

Problem description
===================

If glance backend database is not MySQL or PostgreSQL,the unique constraint
of image-member only includes image-id and member. In this case, if an
image-member is deleted, then create it again with the same parameters, glance
initiates a query to see if there is already an existing one, but the
result does not include the record which was marked as deleted, glance will
try to create a new one with the same parameters, then it will fail with
duplicate error.


Proposed change
===============

Use only one record to maintain the member-ship between a pair of image and
tenant. When create a new image-member, at first check all existing
image-member records including the deleted image-member, then update it if it
exists, otherwise, create a new one.

Alternatives
------------
Unify the unique constraint for image-member like we did for MySQL and
PostgreSQL in 022_image_member_index.py, it has migrated unique constraint of
image-member for MySQL and PostgreSQL, now its unique constraint includes
image-id, member and deleted_at. Currently the column "deleted_at" is
nullable. For other databases like DB2, its unique constraint is more
restricted than MySQL. The columns under unique constrains should be
"NOT NULL", otherwise, an error occurs. Thus, we can not create the same unique
constraint for this kinds of database.

We would alter "deleted_at" column to "not nullable" in migration. That means
we have to insert a default timestamp value for the new created image-member,
an active member with a no-blank timestamp for "deleted_at" would confuse
user.

Another solution is migrating the unique constraint from (image-id, member,
deleted_at) to (image-id, member,created_at) for MySQL and PostgreSQL, from
(image-id, member) to (image-id, member,created_at) for other databases.
created_at is not nullable, so the new constraint will be applicable to all
databases. This solution needs data migration for different database.

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

When create a new image-member, it will search all image-member records
including the deleted items. But if we enable this patch, it will very rare to
see many deleted image-member, as the membership will be kept by only one
record. The only case is, multiple deleted image-members were created before
applying this patch, we could make a migration script in another patch to
remove them.

Other deployer impact
---------------------

Configuration options will change:

None

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  Long Quan Sha

Reviewers
---------

Core reviewer(s):
  nikhil-komawar
  Ian Cordasco

Other reviewer(s):
  Kamil Rykowski
  Abhishek Kekane

Work Items
----------

* Reuse the deleted image-member when create a new one


Dependencies
============

None


Testing
=======

* Verify the deleted image-member is updated when create a new one

Documentation Impact
====================

None


References
==========

Proposed patch:

https://review.openstack.org/190895


unique constraint for PostgreSQL, the same as MySQL:

http://www.postgresql.org/docs/8.1/static/ddl-constraints.html

unique constraint for DB2:

https://www-01.ibm.com/support/knowledgecenter/SSEPGG_9.7.0/com.ibm.db2.luw.admin.dbobj.doc/doc/c0020151.html

