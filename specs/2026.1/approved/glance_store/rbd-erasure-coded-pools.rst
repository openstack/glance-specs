..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================================
RBD Erasure-Coded Pools Support
==========================================

Include the URL of your launchpad blueprint:

https://blueprints.launchpad.net/glance/+spec/rbd-erasure-coded-pools

This specification proposes adding support for erasure-coded pools in the
Glance RBD store driver for cold storage and archival use cases. Erasure-coded
pools reduce storage overhead by 50-75% compared to traditional 3x replication,
but have significant performance costs (CPU overhead, slower operations). This
makes them suitable for infrequently-accessed images where storage efficiency
is more important than performance.

Problem description
===================

The current RBD store driver in Glance only supports replicated pools, which
typically use 3x replication and require 200% storage overhead. For large-scale
deployments with terabytes of images, particularly cold storage or archival
images that are infrequently accessed, this overhead is expensive.

Erasure-coded pools can provide similar data protection with 50-75% less
storage overhead, but they have significant performance trade-offs (higher CPU
usage on the Ceph cluster, slower write and read operations, slower recovery).
These trade-offs make them unsuitable as a general replacement for replication,
but valuable for specific use cases where storage cost is more important than
performance.

Proposed change
===============

This specification proposes extending the RBD store driver to support
erasure-coded pools using Ceph's two-pool model.

Use librbd's native ``data_pool`` parameter to store image metadata in a
replicated pool and image data in an erasure-coded pool.

Before enabling this feature, deployers must create and configure the required
pools on their Ceph cluster. The following commands are expected to be run:

.. code-block:: bash

   $ ceph osd pool create images_data erasure
   $ ceph osd pool create images replicated
   $ ceph osd pool set images_data allow_ec_overwrites true

The ``allow_ec_overwrites true`` setting is required on the erasure-coded
pool. Without this setting, image creation will fail when using the two-pool
model, as librbd needs to be able to overwrite objects in the erasure-coded
pool for metadata operations.

Add ``rbd_store_data_pool`` configuration option to specify the erasure-coded
pool for data storage. If not configured, the driver behaves exactly as it
currently does with single replicated pools.

Implementation:

* When creating new images, pass the ``data_pool`` parameter to librbd's
  ``create()`` method. librbd handles all the complexity of managing the
  two pools.

* Existing images remain in their original single-pool location (all data and
  metadata in the replicated pool). librbd transparently handles reading them
  from their current location.

* New images created after enabling ``rbd_store_data_pool`` will use the
  two-pool model (metadata in the replicated pool, data in the erasure-coded
  pool).

When ``rbd_store_data_pool`` is enabled, the replicated pool (specified by
``rbd_store_pool``) will contain both:
* Existing images: All image data and metadata (single-pool storage)
* New images: Only image metadata (two-pool storage)

While this mixing is technically supported by librbd, it is not recommended
for production deployments. Operators should consider one of the following
approaches:

1. Use separate pools (recommended): Create a new replicated pool
   specifically for metadata when enabling erasure-coded pools, keeping the
   existing pool for legacy images. For example:
   - Keep existing ``images`` pool for legacy images
   - Create new ``images_meta`` pool for metadata of new images
   - Create ``images_data`` pool for data of new images

2. Migration path: Use Glance multistore to migrate existing images to a
   separate backend before enabling erasure-coded pools, or use external tools
   to migrate images between pools.

3. Accept mixing: Allow mixing in the same pool if the deployment can
   tolerate the operational complexity.

Migration of existing images to use the two-pool model is not part of this
specification. If needed, this would be a future enhancement that could use
Glance multistore capabilities or external migration tools.

.. note::

   Performance Considerations:

   Erasure-coded pools have significant performance trade-offs. The Ceph OSD
   daemons (storage nodes) need substantial CPU power to encode and decode data.
   This overhead is not on Glance itself, but on the Ceph cluster. Higher k+m
   values (e.g., 8+3 vs 4+2) increase CPU usage.

   Writes are slower due to encoding work. Reads can be slower, especially if
   data reconstruction is needed when nodes are down. Rebuilding data after
   hardware failures is much more CPU-intensive and slower than with replicated
   pools.

   For large image uploads, operators may need to increase timeout settings
   (particularly for image imports using the stage->import workflow) if write
   performance to EC pools is significantly slower than to replicated pools.

   Best use cases are cold storage or archival images that are infrequently
   accessed, where storage cost savings are more important than performance.

   This feature is disabled by default. Deployers should test performance with
   their specific Ceph hardware and erasure coding profile before enabling
   ``rbd_store_data_pool`` in production.

Alternatives
------------

Implement a system that automatically selects pools based on image
characteristics. This adds complexity and isn't needed for most deployments.

Use external tools to move images between pools. This lacks integration with
Glance and requires separate management tools.

Don't add this feature. Deployments that need cost-efficient cold storage would
have to accept the storage overhead or use external solutions.

The proposed solution is simple: just pass the data pool configuration through
to librbd, which already supports this natively.

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

When ``rbd_store_data_pool`` is configured, write and read operations will be
slower than with replicated pools due to the CPU overhead of erasure coding on
the Ceph cluster. The exact impact depends on the Ceph hardware and the erasure
coding profile used (k+m values).

When ``rbd_store_data_pool`` is not configured (the default), there is no
performance impact.

Other deployer impact
---------------------

New option ``rbd_store_data_pool`` to specify the erasure-coded pool for image
data. When not configured, behavior is unchanged.

Deployers need to create and configure erasure-coded pools on their Ceph
cluster before enabling this feature. Specifically:

* Create an erasure-coded pool for image data (e.g., ``images_data``)
* Create a replicated pool for image metadata (e.g., ``images``)
* Set ``allow_ec_overwrites true`` on the erasure-coded pool (required for
  librbd to function correctly with the two-pool model)

Ensure the Ceph cluster has sufficient CPU resources to handle erasure coding
overhead.

Can be enabled without service interruption. Existing images continue to work
from their current pools.

Note that when ``rbd_store_data_pool`` is enabled, the replicated pool will
contain both legacy images (with all data) and new images (metadata only). While
this mixing is supported, it is recommended to use separate pools for clean
separation (see "Proposed change" section for details).

.. warning::

   Do not enable erasure-coded pools in Glance if Nova or Cinder share the
   same RBD pool as Glance. Erasure-coded pools use a two-pool model where
   image metadata is stored in the replicated pool (rbd_store_pool) and image
   data is stored in the erasure-coded pool (rbd_store_data_pool). If Nova or
   Cinder are configured to use the same pool as Glance's metadata pool, they
   will not be able to properly access or create resources because they do not
   support the two-pool model. This will cause failures when Nova tries to
   boot instances from images stored in erasure-coded pools, or when Cinder
   tries to create volumes from such images.

May want to monitor pool usage and Ceph cluster CPU utilization.

Test write/read performance and timeout behavior before enabling in production.

Developer impact
----------------

The RBD store driver needs to be modified to pass the ``data_pool`` parameter
to librbd when configured.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  cyril-roelandt or abhishekk

Other contributors:
  pranali-deore (Tempest testing)
  whoami-rajat (Cinder changes)

Work Items
----------

* Add the ``rbd_store_data_pool`` configuration option to glance_store
* Modify the RBD driver to pass the ``data_pool`` parameter to librbd's
  ``create()`` method when creating images
* Update devstack-ceph-plugin to create erasure-coded pools for testing
* Coordinate with Cinder and Nova teams - they may need similar changes to
  their RBD configuration to work with images stored in erasure-coded pools
* Add tests for the two-pool scenario
* Update documentation with configuration examples and performance guidance
* Note: Migration tools are not part of this spec

Dependencies
============

Need a Ceph cluster with erasure-coded pools configured.

Cinder writes volumes and snapshots directly to Ceph. It may need similar
``data_pool`` support in its ``rbd_pool`` configuration to create
volumes/snapshots in erasure-coded pools.

Nova may write instance snapshots directly to Ceph pools. It may need similar
``data_pool`` support in its ``libvirt.images_rbd_pool`` configuration.

The devstack-ceph-plugin needs updates to create erasure-coded pools for
testing.

Testing
=======

Test the two-pool configuration and error scenarios with unit tests.

Add tempest tests after devstack-ceph plugin supports creating
erasure-coded pools.

The devstack-ceph-plugin needs to be updated to:

* Create the erasure-coded pool (e.g., ``images_data``) with the ``erasure``
  pool type
* Create the replicated pool (e.g., ``images``) for metadata
* Set ``allow_ec_overwrites true`` on the erasure-coded pool

Without the ``allow_ec_overwrites`` setting, image creation operations will
fail during testing, as verified in testing with Ceph Tentacle release.

Documentation Impact
====================

Document the ``rbd_store_data_pool`` option, performance considerations, and
when to use erasure-coded pools.

Include how to set up Ceph erasure-coded pools and enable the feature in
Glance.

References
==========

* `Existing Ceph EC Pools Specification <https://review.opendev.org/c/openstack/glance-specs/+/863110>`_
* `Ceph Erasure Coding <https://docs.ceph.com/en/latest/rados/operations/erasure-code/>`_
* `Ceph Erasure Code Profiles <https://docs.ceph.com/en/latest/rados/operations/erasure-code-profile/>`_
