..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==============================================
Glance Expand/Contract migrations with Alembic
==============================================

https://blueprints.launchpad.net/glance/+spec/alembic-migrations

This spec outlines the motivation and implementation details for porting
Glance database migrations from SQLAlchemy-based scripts to Alembic.


Problem description
===================

Existing database migrations are implemented in Glance using SQLAlchemy-
migrate scripts. This approach makes designing migrations for rolling upgrades
([1]_ & [2]_) extremely uncomfortable. The ``expand`` and ``contract``
migrations would have to be created in strict sequential order with all of the
latter following all of the former. This places unnecessary restrictions on
the order of migrations and becomes very error prone as multiple schema changes
are introduced in a single cycle. Essentially, using SQLAlchemy-migrate
constrains ``expand`` and ``contract`` migrations to be run atomically and does
not easily facilitate separating them into phases as required during rolling
upgrades.


Proposed change
===============

We are proposing to port the migration flows to be handled by Alembic [3]_.
There are numerous benefits to this change. Alembic allows labeling the
various migration scripts with designated branch names (e.g. ``expand`` and
``contract``), which makes it easier to group the two types of changes and
run them separately.

Another benefit is that Alembic migrations are chained in the manner of linked
list. This is accomplished by explicitly specifying revision dependencies in
each migration script. This will allow developers to get away from dependence
on numeric ordering of migration scripts and obviate the need for placeholder
migrations for retroactive backports, of the like: `023_placeholder
<https://git.openstack.org/cgit/openstack/glance/tree/glance/db/sqlalchemy/
migrate_repo/versions/023_placeholder.py>`_. To facilitate this feature, a new
naming convention is proposed for migration scripts:

    | *<cycle>_<branch-label><##>_<short-desc>.py*
    | e.g. *ocata_expand01_add_visibility_column.py*

Additionally, Alembic supports automatic generation of migration scripts using
SQLAlchemy's ORM. In the future, developers are encouraged to utilize this
feature to minimize their interaction with the underlying DBMS and rely on the
Python code to define the new schema.

Alternatives
------------

The best aleternative available is to continue using SQLAlchemy-migrate
scripts. The downsides of this appropach are outlined in the
`Problem description`_ section above.

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

Performance of existing offline migration flows is not expected to be
impacted in a signifficant way.

Other deployer impact
---------------------

The API of the glance-manage command-line utility remains backwards compatible.
However, the operators will notice that the ``db_version`` command returns a
named head revision rather than a number. This change will be documented.
Additionally, the operators will need to be made aware of the new
``db_expand``, ``db_contract``, and ``db_data_migrate`` APIs in the
glance-manage command-line utility. Refer to the `Documentation Impact`_
section below.

Developer impact
----------------

Going forward, any time a database schema change is implemented, developers
will need to create Alembic migration scripts conforming to the established
naming convention and making sure to link each new revision to the
appropriate down revision.


Implementation
==============

A new ``alembic_migrations`` folder is added under ``glance/db/sqlalchemy``
This folder will contain all the necessary code to implement
Alembic based migrations, including:

* Alembic configuration and environment files. For details see:
  `Migration Environment <http://alembic.zzzcomputing.com/
  en/latest/tutorial.html#the-migration-environment>`_
* helper scripts for creating initial Glance DB schema
* ``versions`` directory, containing migration scripts added in different
  release cycles

Assignee(s)
-----------

Primary assignee:
  hemanthm
  abashmak

Work Items
----------

1. Implement Alembic migration infrastructure and scripts for existing
   database migrations (up to Newton).
2. Introduce ``expand/contract`` migrations for new Ocata features [4]_.
3. Update the glance-manage utility to utilize Alembic for ``db_sync``
   and related commands. Add ``db_expand`` and ``db_contract`` commands
   to prepare for rolling upgrades.


Dependencies
============

* A new Python module will be added to Glance's requirements list:

  * *alembic* - version *0.8.7* or hihger


Testing
=======

Existing and new database migration tests (unit and functional) will be
ported and/or added to exercise the updated glance-manage utility and
test the integrity of Alembic-based migration scripts.


Documentation Impact
====================

The new database version names resulting from the move to Alembic will need to
be documented to make developers aware of the change to ``db_version`` output.

Also, as part of the drive to enable the ``assert:supports-zero-downtime
-upgrade`` tag [5]_, this change will introduce and implement new API methods
for the glance-manage utility: ``db_expand``, ``db_contract``, and
``db_data_migrate``. These will need to be thoroughly documented and their
usage explained in the glance-manage reference as well as the upgrade guide.
It is advised to wait until Glance is able to assert the zero-downtime upgrade
tag to add documentation for the new commands.


References
==========

.. [1] `Glance rolling upgrades
        <https://review.openstack.org/331489>`_
.. [2] `Database strategy for rolling upgrades
        <https://review.openstack.org/331740>`_
.. [3] `Alembic’s documentation
        <http://alembic.zzzcomputing.com/en/latest/>`_
.. [4] `Community images
        <https://specs.openstack.org/openstack/glance-specs/
        specs/newton/approved/glance/community_visibility.html>`_
.. [5] `Supports zero-downtime upgrade tag
        <https://governance.openstack.org/reference/
        tags/assert_supports-zero-downtime-upgrade.html>`_
