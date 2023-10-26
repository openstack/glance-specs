..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

====================================
Use Centralized database for caching
====================================

https://blueprints.launchpad.net/glance/+spec/centralized-cache-db

Problem description
===================

We use two different database(s) for glance. One is a centralized database
managed by oslo.db (default is MySQL) for storing information related to
regular operations; the other one is a sqlite database for
storing information about caching related operations. Even though the
sqlite database is only created if we enable cache middleware we still
need to maintain it along with centralized database. Also glance caches
are local to each controller node (glance api service), so in case of
multiple glance services running we have multiple sqlite database(s)
operational.

Proposed change
===============

We propose to use centralized database (default MySql) for caching related
operations and stop using sqlite database from this release onwards. In this
case we can get rid of creating sqlite database per glance service and
have everything under central database.

At present users can choose between `sqlite` (Default) and `xattr` for how
caching can be controlled using `image_cache_driver` configuration option. We
propose to introduce new driver `centralized_db` and required configuration
options, make it default and mark `sqlite` driver and related configuration
options as deprecated in this cycle and remove it in 'D' development
cycle.

In order to use central database for caching we recommend to have almost
similar schema (columns) as sqlite database with additional reference to
local node (glance service). New deployments will directly start using this
new central database if cache is enabled.

In case of upgrades/updates we need to deal with migrating existing records
from sqlite database to central database. Since we might have multiple
glance(s) running this will be difficult to handle using alembic migrations.
To avoid this using migration we can perform this operation one time during
service startup. If sqlite database is present at service start and
`image_cache_driver` is not set to `centralized_db` then we will
read records from it and insert those in newly created `cached_images` table
in central database. Once all records are migrated we will clear the sqlite
database table and keep the sqlite database file as it is (to be deleted by
administrator/operator later if required). Important point here is once
deployer chooses to use `centralized_db` and we migrate their records out
of `sqlite` to centralized database, then we will not migrate them back
if deployer wants to revert back to `sqlite` driver.

As deployment can have multiple glance services running, to record cache
details separately for multiple glance services, we can use existing
configuration option ``worker_self_reference_url`` which will
differentiate cache records for each glance service running in the
deployment. ``worker_self_reference_url`` is used to identify nodes in the case
of new import workflow earlier, and now the same can be used for this purpose
as well. Since ``worker_self_reference_url`` is required for `glance-direct`
import method as well, if we found that it was not set by the deployer for
any of the glance setup, then at the service startup we will log appropriate
error message and prevent the service from starting. Also, since in the case of
multiple nodes, ``worker_self_reference_url`` needs to be set to a unique value
per node, and if, by mistake, two or more nodes have the same value for it,
then we will not migrate the cache data of that node to a centralized database
with logging an appropriate warning message.

Once we migrate existing cache records to central database we need to
ensure that existing cache related command line utilities like cache-cleaner,
cache-pruner are working as expected. Since these utilities use dedicated
configuration file (glance-cache.conf), we need to make provision to
introduce required configuration options in this file so that these tools can
connect to central database.


Alternatives
------------

None

Data model impact
-----------------

Create two new tables in mysql, one to record cache related operations and
other to record glance api references as shown below.

Schema for cached_images::

  CREATE TABLE cached_images (
    id bigint auto increment PRIMARY KEY,
    image_id varchar(36),
    last_accessed DateTime,
    last_modified DateTime,
    size bigint,
    hits int,
    checksum varchar(32),
    node_reference_id int,
    UNIQUE KEY `uq_cache_unique_id` (`image_id`,`node_reference_id`)
    FOREIGN KEY (node_reference_id) REFERENCES cache_node_reference(node_reference_id)

  )

Schema for cache_node_reference::

  CREATE TABLE cache_node_reference (
    node_reference_id int PRIMARY KEY auto increment,
    node_reference_url varchar(255)
    UNIQUE KEY `uq_node_reference_url` (`node_reference_url`)
  )

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

None

Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  abhishekk

Other contributors:
  None

Work Items
----------

* Deprecate existing sqlite driver and related configuration options

* Create alembic scripts for two new tables

* Add model/queries to sqlalchemy for new tables

* Introduce new centralized_db driver and related configuration options

* Change cache code to use new mysql database

* Add logic at service startup to migrate data from sqlite to mysql

* Modify related commandline tools like cache-cleaner, cache-pruner
  to use centralized driver

* Tempest tests to ensure multiple glance nodes uses centralized
  database.

* Grenade test(s) to verify upgrading scenario(s)

Dependencies
============

None

Testing
=======

* Unit Tests
* Functional Tests
* Tempest Tests
* grenade tests to verify upgrade scenario

Documentation Impact
====================

Need to document use of ``worker_self_reference_url`` in case of import workflow
and cache related operations.

References
==========

None
