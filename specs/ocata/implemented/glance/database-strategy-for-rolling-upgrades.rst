..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

======================================
Database strategy for rolling upgrades
======================================

https://blueprints.launchpad.net/glance/+spec/database-strategy-for-rolling-upgrades

This spec outlines a database modification strategy for Glance that will
facilitate zero-downtime rolling upgrades and make it possible for Glance
to assert the ``assert:supports-zero-downtime-upgrade`` tag.

Problem description
===================

In order to apply the ``assert:supports-zero-downtime-upgrade`` tag [GVV2]_
to Glance, the ``assert:supports-rolling-upgrade`` tag [GVV1]_ must first be
asserted.  It states that

  The project has a defined plan that allows operators to roll out new code to
  subsets of services, eliminating the need to restart all services on new code
  simultaneously.

In order to assert the ``assert:supports-zero-downtime-upgrade`` tag, Glance
must completely eliminate API downtime of the control plane during the upgrade.
A key issue for Glance in this regard is how to handle database changes
required for release N while release N-1 code is still running.  We outline a
strategy by which this may be accomplished below.

.. note::
    In what follows, we make the assumption that an operator interested
    in rolling upgrades will meet us halfway, that is, will be using an
    up-to-date version of the underlying DBMS that supports online schema
    changes that allow as much concurrency as possible.


Proposed change
===============

We propose an expand and contract strategy to implement database changes
in such a way that a rolling upgrade may be accomplished within the confines
of a single release. Some OpenStack services, such as Cinder, that have
addressed this problem have chosen to make database changes over a sequence of
releases, but we believe that given the structure of Glance and typical usage
patterns, database changes can be made and finalized within a single release.
Such an approach is preferable for an open source project in which the cast of
characters may change considerably from cycle to cycle.

We first present an overview of the upgrade strategy and then provide a
detailed example of how this will work for a change that will be occurring in
the Ocata release.

Overview
--------

The following diagram depicts a typical upgrade of an OpenStack service. The
older services are shutdown completely (mostly during a maintenance window),
the new code is deployed and finally the new services are started. Obviously,
this involves some downtime for the users. To minimize/eliminate downtime, the
services can be upgraded in a rolling fashion, that is, upgrading few services
at a time. This results in a situation where both old (say N-1) and new (say N)
services must co-exist for a certain period of time. In a straightforward
upgrade where the new services have no database changes associated with them,
the services can co-exist right from the onset as both rely on the same schema.

.. |.| unicode:: U+200B .. zero-width space not considered whitespace

.. parsed-literal::

 |.|                              |        |         |
 |.|                              |        |         |
 |.|                              |        |         |
 |.|     -----------------------+ |        |         | +---------------------
 |.|                            | |     Deploy N     | |
 |.|                  N-1       | |  (upgrade code   | |     N
 |.|                            | |  and/or config   | |
 |.|     -----------------------+ |  and migrate db) | +---------------------
 |.|                              |        |         |
 |.|                            Stop N-1   |       Start N
 |.|                            Services   |       Services
 |.|                              |        |         |
 |.|                              |        |         |
 |.|                              |        |         |
 |.|                              |        |         |
 |.|                              |        |         |
 |.|                              |        |         |
 |.|
 |.|                               <---------------->
 |.|                                     Downtime
 |.|                               <---------------->

However, in the presence of database changes it isn't yet possible for the
services to co-exist. The primary reason is the way we do database
changes/migrations currently. A typical migration in Glance is an atomic change
that includes both schema and corresponding data migrations together.
While the schema migrations perform necessary additions/removals/modifications
to the schema, data migrations perform corresponding changes to the data.
This approach at times, depending on the nature of schema changes, is
backwards-incompatible. That is, older services may not be able to run with new
schema. This essentially limits the ability for old and new services to
co-exist and consequently prohibits rolling upgrades.

To achieve rolling upgrades, database migrations need to be done in such a way
that both old and new services can co-exist over a period of time. A well known
strategy is to re-imagine database changes in ``expand and contract`` style
instead of one atomic change. With the expand and contract style, we achieve
the desired schema changes in two distinct steps:

    * **Expand**: In the ``expand`` step, we make ``only additive changes``
      that are required by the new services. This keeps the schema intact for
      older services to run along with the new services. The typical schema
      changes that fall into this category are adding columns and tables.

      An exception to this additive-only change strategy is that it may
      be necessary to remove some constraints in order to allow database
      triggers (discussed below) to work.

    * **Contract**: All the other changes, that is ``non-additive changes``,
      are grouped into ``contract`` step. Changes like removing a column, table
      and/or constraints are made in this step.

      Additionally, if any constraints were removed during the expand
      step, they are restored during the contract phase.  Any database
      triggers installed during the expand phase are also removed at this
      point.

This breakup gives us the ability to perform the minimum required changes
first (while keeping schema compatibility with old services) and delay the
other changes until a later point in time. Therefore, we always first expand
the database in order to start a rolling upgrade while the old services are
still running. Once the database is expanded, the new columns and tables are
created. However, they would be empty. At this point, we should start migrating
the data over to the new column. But, at the same time, it is important to
keep the new and old columns in sync. Any writes to old column must be sync-ed
to the new column. And, vice-versa (although we don't write to the new column
yet, we have to keep the old column in sync when the new services come up and
start writing to the new column while the services co-exist). We use **database
triggers** to keep the columns in sync.

We add the triggers to the database along with the additive changes
during the database expand. At this point, we start migrating the data over to
the new column. However, because the old services are live at this point, we
migrate the data in small batches to avoid excessive load on the database and
thereby any interruption to the old services. These migrations can be scheduled
to run during low-traffic hours to minimize impact on older services. Once the
data migrations finish, the new column is populated and ready for use, we start
deploying the new services.

We deploy services in small batches by taking some nodes out of rotation,
wait for them to drain connections, upgrade the services and put the nodes back
into rotation. It is during this period that old and new services co-exist.
When the new services come up, they start reading from and writing to the new
column. Any data written to the new column is synced over to the old column (by
the triggers added during database expand) and available for older services to
consume. Once all the older services are upgraded, it is now safe to contract
the database. This ensures that we reach the desired state of database schema.
We also drop the database triggers during the database contract because
the old column would cease to exist and only the new column would be in use.


.. parsed-literal::

 |.|         ---------------------------------------+
 |.|                                                |
 |.|                         N-1                    |
 |.|                                                |
 |.|         ---------------------------------------+
 |.|
 |.|                 |    |           |    |         |     |
 |.|                 |    |        Finish  |         |     |
 |.|                 |    |         Data   |
 |.|              Expand  |      Migrations| +----------------------------
 |.|             Database |           |    | |
 |.|                 &    |           |    | |     N
 |.|                Add   |           |    | |
 |.|              Triggers|           |    | +----------------------------
 |.|                 |    |           |    |
 |.|                 |    |           | Start N      |     |
 |.|                 |  Start         |  Deploy      | Contract
 |.|                 |  Data          |    |         | Database
 |.|                 | Migrations     |    |         |     &
 |.|                 |    |           |    |         |   Drop
 |.|                 |    |           |    |         |  Triggers
 |.|                 |    |           |    |     Finish N  |
 |.|                 |    |           |    |      Deploy   |
 |.|                 |    |           |    |         |     |
 |.|                 |    |           |    |         |     |


To summarize, as shown in the above diagram, we split the database migrations
into schema and data migrations. The schema migrations can be additive or
contractive in nature, or a combination of both. Additive schema migrations are
run before the upgrade begins to prepare the database for new services while it
is still usable by old services.  (This phase is also called "database
expand".) During database expand, we also add triggers on old and new columns
to keep them in sync. Once the database is expanded, we start migrating the
data over to the new column in small batches.  When the data migrations are
complete, we upgrade the old services in a rolling fashion. Once all the old
services are upgraded, we run the contractive migrations on the database.
(This phase is also called "database contract".) The triggers are also dropped
during database contract.

In addition to the description of the process given above, here are a few
constraints on how upgrades will work:

* A typical upgrade is complete only when the entire expand-migrate-contract
  cycle for a release is performed.  We do *not* propose to support an N-1 to
  N upgrade while an N-2 to N-1 upgrade is in progress.

* "Leapfrogging" releases (that is, allowing a direct N-2 to N upgrade,
  skipping N-1) is *not* supported.

* It's possible that in a single release there may be multiple features, worked
  on independently by different developers, that will require some kind of
  database modification.  What we are proposing in this spec is that for each
  release, there will be a *single* expand-migrate-contract operation from the
  operator's point of view.  In other words, all feature teams will have to
  coordinate so that all expands are performed, followed by all migrations, and
  concluding with all contractions.  This will be easy for features whose
  changes are completely independent, but may be more difficult for others.
  However, preserving zero-downtime database changes will be a Glance project
  priority once this spec has been approved, so such interactions will be
  addressed on the specs for features.

.. note:: The current Glance spec template asks this question in the "Data
          model impact" section:

          * What database migrations will accompany this change?

          This should be modified along the following lines.  (Note: this is
          only a suggestion, we can argue about the best wording on the patch
          that modifies the spec template.)

          * Glance is committed to zero-downtime database migrations.
            Explain what database migrations will accompany this change.
            Do they have the potential to interfere with the database
            migrations for other specs that have been approved for this
            cycle?

Keep in mind that our goal here is to achieve the upgrade tags.  While it's
not *prohibited* to exceed them, they do specify a baseline for achievement
that's been adopted by the OpenStack community.  Hence simply meeting the
requirements for the tags is a worthwhile goal.

Steps
-----

Let's look at a rolling-upgrade strategy for Glance in more detail. Consider
the case where a database change is made such that data stored in
"the old column" in release N-1 will be stored in "the new column" in
release N. The following are steps that we take to achieve rolling-upgrade.

Expand Database
^^^^^^^^^^^^^^^

Goal: Prepare database for N by expanding the database

As shown in the below diagram, initially, we have N-1 reading from and writing
to the old column. We then expand the schema for N which introduces the new
column while N-1 is still running. This should have minimal to no impact on N-1
services.

.. note:: It is important to note that while database expand operations are
    required to be strictly additive in nature, adding constraints can
    sometimes be disruptive as they are known to lock the table.  This is
    alleviated by online DDL capabilities in MySQL 5.6 for InnoDB. So, simple
    changes may not be a concern.  (In any case, the plan proposed in this spec
    adds constraints during the contract phase only.)

.. parsed-literal::

 |.|     -----------------------------------------------------------
 |.|
 |.|                               N-1
 |.|
 |.|     -------+-----------------------+---------------------------
 |.|            |                       |
 |.|            |           |           |                          |
 |.|         Read/Write     |        Read/Write                    |
 |.|            |       Expand N        |                          |
 |.|            |           &           |                        Start
 |.|       +----v-----+    Add     +----v-----+----------+        Data
 |.|       |   Old    |  Triggers  |   Old    |   New    |     Migrations
 |.|       +----------+     |      +---------------------+         |
 |.|       |          |     |      |          |          |         |
 |.|       |          |     |      |          |          |         |
 |.|       |          |     |      |          |          |         |
 |.|       |          |     |      |          |          |         |
 |.|       |          |     |      |          |          |         |
 |.|       |          |     |      |          |          |         |
 |.|       |          |     |      |          |          |         |
 |.|       |          |     |      |          |          |         |
 |.|       |          |     |      |          |          |         |
 |.|       |          |     |      |          |          |         |
 |.|       +----------+     |      +----------+----------+         |
 |.|                        |          ^             ^             |
 |.|                        |          |  Triggers   |             |
 |.|                        |          +-------------+             |
 |.|                        |                                      |
 |.|                        | <--------------------------------- > |
 |.|                        |           Expand Database            |
 |.|                        | <--------------------------------- > |



While expanding the database, we also add triggers that keep the old and new
columns in sync.

Deliverable: We propose to make this available by extending the glance-manage
utility with an expand command. The database could be expanded by running
``glance-manage db expand``.


Migrate Data
^^^^^^^^^^^^

Goal: Populate the new column(s) for N to use

At this point, only release N code is running and it continues to read from and
write to the old column as shown in the below diagram. All writes made by N-1
to the old column are synced with the new column. While the triggers slowly
start populating the new column, we commence the background data migrations to
populate data into the new column in a non-intrusive manner.

.. parsed-literal::

 |.|       -------------------------------------------------
 |.|
 |.|                           N-1
 |.|
 |.|       -----------------+-------------------------------
 |.|                        |
 |.|            |           |                          |
 |.|            |        Read/Write                    |
 |.|            |           |                          |
 |.|          Start         |                        Finish
 |.|          Data     +----v-----+----------+        Data
 |.|       Migrations  |   Old    |   New    |     Migrations
 |.|            |      +---------------------+         |
 |.|            |      |          |          |         |
 |.|            |      |          |          |         |
 |.|            |      |          |          |         |
 |.|            |      |          |          |         |
 |.|            |      |          |          |         |
 |.|            |      |          |          |         |
 |.|            |      |          |          |         |
 |.|            |      |          |          |         |
 |.|            |      |          |          |         |
 |.|            |      |          |          |         |
 |.|            |      +----------+----------+         |
 |.|            |          ^             ^             |
 |.|            |          |  Triggers   |             |
 |.|            |          +-------------+             |
 |.|            |                                      |
 |.|            | <--------------------------------- > |
 |.|            |            Migrate Data              |
 |.|            | <--------------------------------- > |


Deliverable: We propose to extend the glance-manage utility to migrate the data
in batches. The batch size could be controlled with an optional parameter, for
example, ``max_rows``.  The parameter would allow operators to schedule
migrations of no more than N rows at a time, in case they have a large database
and want to run the migration only during off-peak times.  Without the optional
parameter, all rows would be migrated.  The utility will return an appropriate
response if it's run and it finds that there are no rows that need to be
migrated.

For example: ``glance-manage db migrate --max_rows=10``.


Deploy
^^^^^^

Goal: Deploy N by upgrading N-1 in a rolling fashion and have both versions
      co-exist during the deploy

As the new column is now ready to use, we start deploying N in small batches.
Release N-1 has no idea that an upgrade is occurring, but the release N code is
co-existing with N-1 services as shown in the below diagram. While N-1 and N
services are using the old and new column respectively, the triggers are
keeping the two columns in sync whenever there is a database write. This
enables N to see the updates made by N-1 and vice-versa.

.. parsed-literal::

 |.|                ------------------------------------+
 |.|                                                    |
 |.|                                    N-1             |
 |.|                                                    |
 |.|                --------------+---------------------+    |
 |.|                              |                          |
 |.|                   |          |
 |.|                   |          |   +------------------------------
 |.|                   |          |   |
 |.|                   |          |   |   N
 |.|                   |          |   |
 |.|                   |          |   +-------+----------------------
 |.|                   |          |           |
 |.|                   |        Read/       Read/            |
 |.|                   |        Write       Write            |
 |.|                   |          |           |              |
 |.|                   |          |           |              |
 |.|                   |      +---v------+----v-----+     Finish N
 |.|                   |      |  Old     |   New    |      Deploy
 |.|                Start N   +---------------------+        |
 |.|                Deploy    |          |          |        |
 |.|                   |      |          |          |        |
 |.|                   |      |          |          |        |
 |.|                   |      |          |          |        |
 |.|                   |      |          |          |        |
 |.|                   |      |          |          |        |
 |.|                   |      |          |          |        |
 |.|                   |      |          |          |        |
 |.|                   |      |          |          |        |
 |.|                   |      |          |          |        |
 |.|                   |      +----------+----------+        |
 |.|                   |          ^             ^            |
 |.|                   |          |  Triggers   |            |
 |.|                   |          +-------------+            |
 |.|                   |                                     |
 |.|                   |                                     |
 |.|                   |    <---------------------------->   |
 |.|                   |               Deploy                |
 |.|                   |    <---------------------------->   |
 |.|                   |                                     |
 |.|

.. note::
    As the N-1 and N services co-exist, users may notice inconsistent behavior
    in certain situations. Typically, a new release is backwards-compatible
    with the previous release. As such, all requests should exhibit similar
    behavior across both versions. However, some changes to the API (for
    example: bug fixes) may result in different behavior across two releases.
    So, a user may witness different responses to similar requests depending
    upon which service processes the request.

    Similarly, user requests for new features introduced with the new version,
    may fail when they are processed by an older service. While this
    inconsistency is not desirable, it could be seen as a decent compromise
    over incurring downtime during the upgrade.

Contract Database
^^^^^^^^^^^^^^^^^

Goal: Complete the schema migrations desired in N

When all the services are upgraded, the old column is unused. The new column
would be the source of truth henceforth. The old column is ready for removal.
At this point, we contract the database, which drops the old column and
triggers added during database expand.

.. parsed-literal::

 |.|              |
 |.|              |
 |.|
 |.|         -------------------------------------------
 |.|
 |.|                                N
 |.|
 |.|         -----------------------+-------------------
 |.|                                |
 |.|              |               Read/
 |.|              |               Write
 |.|              |                 |
 |.|              |                 |
 |.|          Contract          +---v----+
 |.|           Database         |   New  |
 |.|              &             +--------+
 |.|            Drop            |        |
 |.|           Triggers         |        |
 |.|              |             |        |
 |.|              |             |        |
 |.|              |             |        |
 |.|              |             |        |
 |.|              |             |        |
 |.|              |             |        |
 |.|              |             |        |
 |.|              |             |        |
 |.|              |             ---------+
 |.|              |
 |.|              |
 |.|              |     <----------------------->
 |.|              |         Contract Database
 |.|              |     <----------------------->
 |.|              |

.. note::
    In addition to removing the unused columns and tables, SQL constraints such
    as nullability, unique and default must be set here.

Deliverable: We propose to make this available by extending the glance-manage
utility with a contract command. The database could be contracted by running
``glance-manage db contract``.


Rolling Upgrade Process for Operators
-------------------------------------

Following is the process to upgrade Glance with zero downtime:

1. Backup Glance database.

2. Choose an arbitrary Glance node or provision a new node to install the new
   release. If an existing Glance node is chosen, gracefully stop the Glance
   services.

3. Upgrade the above chosen node with new release and update the configuration
   accordingly. However, Glance services MUST NOT be started just yet.

4. Using the upgraded node, expand the database using the command
   ``glance-manage db expand``.

5. Then, schedule the data migrations using the command
   ``glance-manage db migrate --max_rows=<max. row count>``.

    Data migrations must be scheduled to run until no more rows are left to
    migrate.

6. Start the Glance processes on the first node.

7. Taking one node at a time from the remaining nodes, stop the Glance
   processes, upgrade to the new release (and corresponding configuration) and
   start the Glance processes.

.. note::
    Before stopping the Glance processes on a node, one may choose to wait
    until all the existing connections drain out. This could be achieved by
    taking the node out of rotation. This way all the requests that are
    currently being processed will get a chance to finish processing.
    However, some Glance requests like uploading and downloading images
    may last a long time. This increases the wait time to drain out all
    connections and consequently the time to upgrade Glance completely.
    On the other hand, stopping the Glance services before the connections
    drain out will present the user with errors. This can at times be seen as
    downtime as well. Hence, an operator must be judicious when stopping the
    services.

8. Contract the database by running the command
   ``glance manage db contract`` from any one of the nodes.


Example
-------

To understand how this would work in action, consider the following example of
a Glance database change proposed for Ocata.

.. note:: This does not prescribe the actual Ocata database change.  It is
          included here as a realistic example for a sanity check of this
          proposal.

The "old column": Newton (release N-1): boolean ``is_public`` column in images
table.  This column has nullable=False and default=False.

The "new column": Ocata (release N) : enum (or string ... key point is it's a
different data type) ``visibility`` column in images table.  This column can
have one of the values 'public', 'private', 'shared', 'community'.  After the
database contraction has completed, this column would have
nullable=False, and default='private'.  (During the migrate and deploy phases,
this column will probably have nullable=true with no default.)

Using the proposed strategy, the database upgrade would proceed as follows.

#. Pre-upgrade: Version N-1 code read/write to ``is_public``.

#. Expand Database: Add the ``visibility`` column and the appropriate triggers
   to keep the old and new values in sync.

#. Migrate Data: Crawl the 'images' table.  For any row where
   ``visibility`` is null, set the value for ``visibility`` as follows:

   * If ``is_public`` is '1': set visibility to ``public``
   * If ``is_public`` is '0': if the image has any members, set visibility to
     ``shared``; otherwise set visibility to ``private``

   Migrate any data (using triggers) written by N-1 code to the old column
   using the above criteria.

#. Deploy: Deploy N code in a rolling fashion. N code will start using the
   ``visibility`` column.

   Here's an analysis of database activity.

   * Write operations

     * The v1 API

       * nothing to worry about, has no concept of ``visibility``

     * The v2 API

       #. ``visibility`` set to ``public``

          * N-1: will put '1' in ``is_public``
            * Triggers will put 'public' in ``visibility``
          * N: will put 'public' in ``visibility``
            * Triggers will put '1' in ``is_public``

       #. ``visibility`` set to ``private``

          * N-1: will put '0' in ``is_public``
            * Triggers will put 'private' in ``visibility``
          * N: will put 'private' in ``visibility``
            * Triggers will put '0' in ``is_public``

       #. ``visibility`` set to ``community``

          * N-1: call will fail at API level, will never hit the database
          * N: will put 'community' in ``visibility``
            * Triggers will put '0' in ``is_public``

             .. note::
              This essentially means that a community image will be considered
              as private image by N-1. Thus, barring the owner, a community
              image won't be visible to any one. Since N-1 has no notion of
              community images, this behavior can be seen as consistent with
              respect to N-1. However, it may be confusing the owner of the
              community image for whom the image will appear as community with
              N and private with N-1. Thus, the owner may try to change the
              visibility again. To discourage this, we may prohibit any writes
              to the ``is_public`` column when it has '0' and ``visibility``
              column has ``community``. This could be done again by using the
              same triggers that we added during database expand. The first
              alternative mentioned in the alternatives section avoids this
              situation.

       #. ``visibility`` set to ``shared``

          * N-1: call will fail at API level, will never hit the database
          * N: will write 'shared' in ``visibility``

            * Triggers will write '0' in ``is_public``; this will allow image
              sharing to continue to work properly on the release N-1 nodes as
              well as the v1 API on all nodes.

   * Read operations

     * Read operations across API versions and releases should remain
       unaffected as the triggers keep both old and new columns in sync by
       translating the data appropriately.

#. Contract Database: The only API nodes running are version N.
   The ``is_public`` column is no longer in use. Drop ``is_public`` and add
   nullable=True and default=private on ``visibility`` column.


Alternatives
------------

1. This is a small variant of the above described strategy. The fundamental
   idea behind the above described strategy is: When both versions co-exist,
   sync the writes made by one set of services to be available for the others
   to consume. We achieve this using triggers. On the other hand, what if we
   eliminate the need to sync? That is, what if we disallow any writes to both
   old and the new columns while the services co-exist? This can be achieved by
   using triggers again. Essentially, the triggers we add during the database
   expand step will intercept and disallow writes to the old and new columns.

   For the above given example, all requests attempting to change the
   visibility of image will fail for the duration of deploy step where the
   services co-exist. Reads would be permitted, however. Once the deploy is
   finished and we contract the database (the triggers are dropped here),
   writes to new column would be permitted as usual. This gives us a way to
   eliminate the need for syncing data across columns. Consequently, there is
   much less complexity in the triggers and the upgrade is less error-prone.
   However, it is important to note that one may see an increased error rate
   during the deploy due to disallowed writes. Although the API will be
   responsive throughout this entire period (and hence "up"), the increased
   rate of 5xx responses will make it impossible to assert the
   ``assert:zero-downtime-upgrade`` tag [GVV2]_.  Since being able to assert
   this tag is the aim of this spec, this alternative is not acceptable.

2. A well known alternative replaces the use of triggers by migrating the data
   online from within the application. While the triggers approach migrates the
   data online on a database write operation, the other approach attempts to
   migrate the data on an on-demand basis in the event of a database read
   operation.

Approaches taken by other Openstack Projects:

Nova: See [NOV1]_.

Cinder: See [CIN1]_.

Keystone: See [KEY1]_.

Neutron: See [NEU1]_, [NEU2]_.

Data model impact
-----------------

None

REST API impact
---------------

There would be no impact to REST API contracts as such.

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

The background data migration will consume extra database resources, but this
can be managed if the migration script is carefully written.

Other deployer impact
---------------------

* Deployers who intend to deploy Glance the old way, that is with downtime,
  remain unaffected.
* Each step of the migration requires operator intervention.

Developer impact
----------------

Any developer working on a feature that requires database changes must write
additional code to support the rolling upgrade strategy outlined in this
document.  By confining the database changes to a single release, however,
developers of release N+1 do not have to worry about completing procedures
begun during the migration of release N-1 to N.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  alex_bash
  hemanthm

Other contributors:
  nikhil

Work Items
----------

* Write documentation for rolling upgrade (developer docs).

* Write documentation for rolling upgrade (operator docs).

* Introduce expand/contract migration streams and the corresponding
  glance-manage CLI.

* Work with the developers of Ocata features that require database changes
  to implement code to follow the rolling upgrade strategy.  These include:

  * community images and enhanced image sharing

  * image import

Dependencies
============

None

Testing
=======

In order to assert the rolling upgrades tag, Glance must have full stack
integration testing with a service arrangement that is representative of a
meaningful-to-operators rolling upgrade scenario.

Ideally these tests will be able to simulate Glance running at scale, since, as
discussed above, some DBMS problems may not be revealed in a small test
database.


Documentation Impact
====================

* Developer documentation: the upgrade strategy.

* Operator documentation:

  * configuration options for putting the code into the various modes
  * running the database scripts

References
==========

.. [GVV1] https://governance.openstack.org/reference/tags/assert_supports-rolling-upgrade.html
.. [GVV2] https://governance.openstack.org/reference/tags/assert_supports-zero-downtime-upgrade.html
.. [NOV1] http://www.danplanet.com/blog/2015/10/07/upgrades-in-nova-database-migrations/
.. [CIN1] https://specs.openstack.org/openstack/cinder-specs/specs/mitaka/online-schema-upgrades.html
.. [KEY1] https://specs.openstack.org/openstack/keystone-specs/specs/mitaka/online-schema-migration.html
.. [NEU1] https://specs.openstack.org/openstack/neutron-specs/specs/liberty/online-schema-migrations.html
.. [NEU2] http://docs.openstack.org/developer/neutron/devref/upgrade.html
