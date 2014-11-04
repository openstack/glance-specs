..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================================
Glance db purge utility
==========================================

https://blueprints.launchpad.net/glance/+spec/database-purge

This spec adds the ability to sanely and safely purge deleted rows from
the glance database for all relevant tables. Presently, we keep all deleted
rows. I believe this is unmaintainable as we move towards more upgradable
releases. Today, most operators depend on manual DB queries to delete this
data, but this exposes the DB to human errors.

The goal is to have this be an extension to the `glance-manage db` command.
Similar specs are being submitted to all the various projects that touch
a database.

Problem description
===================

Very long lived OpenStack installations will carry around database rows
for years and years. This brings following problems:

* If deleted data is kept in the DB, the number of rows can grow very large
  taking up the disk space of nodes. Larger disk space means more worry
  for disaster recovery, long running non-differential backups, etc.

* Large number of deleted rows also means, an admin or authorized owner
  querying for the corresponding rows will get 5xx responses timing out
  on the DB, eventually slowing down other queries and API performance.

* DB upgradeability is a big challenge if the older data style are less
  or inconsistent with the latest formats. An example would be the image
  locations string where older location string styles are different
  from the latest.

To date, there is no "mechanism" to programmatically
purge the deleted data. The archive rows feature doesn't solve this.

Proposed change
===============

The proposal is to add a "purge" method to DbCommands in
glance/glance/cmd/manage.py. This will take a maximum count of rows to delete
and number of days argument and use that for a data_sub match.
Like::

  DELETE FROM images
    WHERE deleted != 0 AND deleted_at > data_sub(NOW()...)
    LIMIT count;

Alternatives
------------

Today, this can be accomplished manually with SQL commands, or via script.
There is also the archive_deleted_rows method. However, this won't satisfy
certain data destruction policies that may exist at some companies.

Data model impact
-----------------

None, all tables presently include a "deleted_at" column.

REST API impact
---------------

None, this would be run from glance-manage

Security impact
---------------

None, This only touches already deleted rows.

Notifications impact
--------------------

None

Other end user impact
---------------------

This affects the operator's ability to identify and delete all those rows from
the DB that have location stored for backend data entities, that are not
deleted (or partially deleted) due to some error at the time of the DELETE api
call or during scrubber's data purge run.

This has another operator/user impact for the calls that require changes-since
filter. It is required by the Nova proxy API and exists in v1 (and potentially
in v2). Purging the deleted data results into information evaporation that
the changes-since filter use case is designed for. One example, if it is needed
to check an old snapshot that has been deleted but has some vital info
for cross checking. Some operators give/want to give that functionality
to users. Purging breaks that contract and operators need to be aware about it.

Performance Impact
------------------

This has the potential to improve performance for very large databases.
Very long-lived installations can suffer from inefficient operations on
large tables.

Another performance impact is on the negative side unless the operators
are being careful about the count. A long running purging operation will
potentially cause delay in the upgrade process. It is also likely to result
into a different differential backup of the DB and that may delay the process.

Other deployer impact
---------------------

Some developers who want to optimize calls like re-adding a deleted
image-member to image while re-sharing that image, will have to consider
the rows can be deleted from now on.

Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  mmagr

Reviewers
---------

Core reviewer(s):
  flaper87
  nikhil-komawar

Other reviewer(s):
  None

Work Items
----------

Add purge functionality to manage.py db/api.py db/sqlalchemy/api.py
Add tests to confirm functionality
Add documentation of feature

Dependencies
============

None

Testing
=======

The test will be written as such. Three rows will be inserted into a test db.
Two will be "deleted=1", one will be "deleted=0"
One of the deleted rows will have "deleted_at" be NOW(), the other will be
"deleted_at" a few days ago, lets say 10. The test will call the new
function with the argument of "7", to verify that only the row that was
deleted at 10 days ago will be purged. The two other rows should remain.

Documentation Impact
====================

The documentation needs to emphasize that the image_locations table will be
trimmed, which will destroy all information about where the image was
stored in various backends. The operator should keep this in mind when
selecting the number-of-days value for the purge function.

References
==========

This was discussed on both the openstack-operators mailing list and the
openstack-developers mailing lists with positive feedback from the group.

http://lists.openstack.org/pipermail/openstack-dev/2014-October/049616.html
