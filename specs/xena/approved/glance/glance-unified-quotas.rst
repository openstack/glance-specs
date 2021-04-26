..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===========================================
Implement Unified Keystone Quotas in Glance
===========================================

https://blueprints.launchpad.net/glance/+spec/glance-unified-quotas

Glance currently lacks per-tenant quota capabilities, which is
something that other OpenStack projects have had for quite some
time. Especially since Glance is a key project for a working cloud,
and because it involves consumption of expensive resources, quotas are
necessary for operators to properly restrict usage. As noted in the
recent PTG, public clouds charge for every resource, and thus
per-tenant limits may be less important. However, private clouds
generally do not bill for usage, and instead rely on pre-paid quotas
for resource sharing. This work aims to implement quotas for Glance.

Problem description
===================

Glance does not have per-tenant quotas.

* As an operator of a private cloud, I need to be able to define a
  quota for a tenant to avoid them consuming unlimited resources since
  I do not bill them for each one.

* As an operator of a cloud, I have customers of differing sizes, and
  wish to use per-tenant quotas to provide "safety valve" limits on
  runaway usage. Having just one global value that applies to all
  users is not powerful enough to provide reasonable limits for
  tenants of varying size.


Proposed change
===============

Keystone has implemented something called "unified limits," which
allows an operator to define (in Keystone) default and per-tenant
quota limits. By default the "flat" model provides a very basic
one-tenant-one-limit structure, but more complex hierarchies are
possible. These can be set using Keystone's client (openstackclient)
utility to register, set, and update limits per tenant.

By utilizing this Keystone functionality, Glance does not need to
define new APIs and client support to allow operators to set the
limits, nor is it required to build a persistence model to store them,
clean them up, etc. Instead, Glance can query the limit values from
Keystone and compare them against current/proposed usage in order to
determine if a particular resource consumption should be
allowed. Effectively, Glance needs only *enforce* the quotas, but it
does not need to store or manage them. Limits are fetched from
Keystone automatically and per-request by the ``oslo_limit`` library,
and thus quota changes take effect immediately.

Adding new quota limits is relatively easy using this model. While
more can be added in the future, this spec covers the work required to
add the following limits:

* ``image_size_total``: A limit on the storage consumed by all the
  non-deleted images for the tenant. Images with multiple locations
  will count as multiple usages. Specified in Mebibytes (MiB). This
  will be enforced in the image upload path, as well as the import
  path which are the APIs in which a user actually consumes more
  storage.
* ``image_stage_total``: A limit on the storage consumed by all the
  images in ``uploading``, ``importing``, and any other transient
  import-related states for the tenant. In order to capture space used
  by copying images, we will also include active images with a
  non-zero list of ``os_glance_importing_to_stores`` items. Specified
  in Mebibytes (MiB). This will be enforced in the image stage path.
* ``image_count_total``: A limit on the total number of non-deleted
  images owned by the tenant. Specified as a count of images. This
  will be enforced in the image create path.
* ``image_count_uploading``: A limit on the total number of images
  currently in either the ``uploading``, ``saving``, ``importing`` and
  any other transient states related to upload or import by the
  tenant. In order to capture images being copied, we will include
  active images with a non-zero list of
  ``os_glance_importing_to_stores`` items. Specified as a count of
  images. This will be enforced in the image upload and stage paths,
  and will provide a limit on the number of images that can be adding
  external data to the system at any given point.

Since the staging area for Glance API workers is likely to be far more
constrained than the general-purpose image storage, those quotas are
separated. An operator likely wants to give a user a large amount of
image storage, which is backed by a sophisticated and distributed
backend. However, the staging area is really "temporary space" which
is used in the process of importing images, and is likely to be far
more constrained (local disk on an API worker). By allowing a separate
quota for the staging area, an operator gains the ability to provide
many TiB of space for general image storage, while restricting users
to a small number of import operations at a time. It helps to avoid a
user staging a large amount of image data and then leaving it there
for a long period of time. If staging quota is not desired, then
setting it to ``-1`` in Keystone signals to ``oslo_limit`` that it
should be "unlimited." By allowing for a separate count and size
staging quota, the operator can either restrict the amount of image
data, or the number of operations in progress.

For the storage-related limits, the initial revision of this will
simply enforce the quota at the beginning of the relevant long-running
storage-using operation. This has the benefit of being simple and
predictable, but does make the quota enforcement "soft" in that a user
must go over the limit before they are stopped. Existing global limits
are enforced as "hard" thresholds in cases where the user provided a
size ahead of time, and can interrupt a long-running network operation
if breached. The benefit of this is that friendly users are not
allowed to exceed their limit, although users that do not provide the
size (such as when streaming an image) still require checking the
limit after the operation is complete.  The drawback of the current
behavior is that if a user exceeds the 1TiB limit at 900GiB, they will
have wasted time and network bandwidth, only to have the entire stream
discarded. Since the global limits are intended to stop gross
over usage and be large enough for any tenant, they are unlikely to be
hit normally. The per-tenant ones described here are more likely to be
hit regularly, and thus the soft behavior is chosen. Enforcing them as
hard limits during or after a transfer could be done as a follow-on
effort.

Honoring these limits will be conditional based on a configuration
option. By default limit quotas will be disabled, which will most
easily facilitate upgrades. When disabled, nothing will be different
from how it is today. When enabled, Glance will fetch limits from
Keystone, expecting the operator has registered them as prescribed,
and enforce them against a user's usage. I think ultimately it
probably makes the most sense to make that enabled by default, and
potentially eventually ultimately remove the knob entirely. Obviously,
we can keep the knob indefinitely if that is more desirable.

Alternatives
------------

One alternative is always to do nothing. Glance has not had quotas for
this long, so we could just not add them and rely on the global
resource limits, as they are today.

Another alternative is to implement quotas in Glance itself and not
utilize the Keystone unified limits functionality. This would require
new APIs, client support, and database models. It would also run
contrary to the efforts in the wider community to move towards
defining all quota limits in Keystone.

We could also decide that soft quotas are not good enough and take one
of the following paths to get hard quotas:

* Start requiring API clients to declare image sizes at upload time so
  that we can do the quota check accurately up front.
* Refactor oslo-limit to expose the details of the limits, and use
  that in a refactored Image.set_data() wrapper to halt data transfer
  mid-stream when the limit is exceeded.

Either of these are candidates for future work that build on top of
the work proposed in this spec.

Data model impact
-----------------

There are no additional values that need to be stored if we do
this. We already store the image size, which is what we need to count
at enforcement time for the storage-based limits. Since Keystone
stores the actual per-tenant quota limit values, we do not need to
store those.

REST API impact
---------------

This will introduce some more ways to get HTTP 413 limit errors, but
since they are already possible due to the existing limits, there is
effectively no change.

A future effort should add a quota usage API to allow clients to check
consumption against their limits.

Security impact
---------------

This should improve the overall security of the system, because
resource limits can be custom-tailored to each tenant instead of
relying only on global large-enough-for-anyone limits.

Notifications impact
--------------------

None.

Other end user impact
---------------------

No client changes are required. Actual end users may notice a
behavioral change related to their operator being able to enforce a
smaller quota on them than previously was possible (which is the goal
of this effort).

Performance Impact
------------------

Querying Keystone for the limits for a tenant is not free, and will
introduce some dependency and latency. However, this interaction
(specifically with Keystone) is in the critical path for all API usage
anyway. At least initially, a configuration option will be provided to
enable this behavior, defaulting to disabled.

Other deployer impact
---------------------

Operators will need to define the registered and actual limits for the
Glance values in Keystone prior to enabling enforcement. This is done
by registering them in keystone with default values using the
openstack client. Quotas for individual users can be then set using a
similar mechanism. All of this can be done prior to and after enabling
enforcement on the glance side.

Operators upgrading from Wallaby or earlier need not do anything
specific during the upgrade, as enforcement is off by default. If the
operator wishes to utilize quotas after upgrading, they can register
the quotas and enable glance enforcement in the config at any time.

Developer impact
----------------

None.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  danms

Work Items
----------

* Introduce the base infrastructure for querying and checking limits
  from Keystone.
* Add the ``image_size_total`` quota enforcement to upload and import.
* Add the ``image_stage_total`` quota enforcement to stage.
* Add the ``image_count_total`` quota enforcement to create.
* Add the ``image_count_uploading`` quota enforcement to stage and
  upload.
* Figure out what to do about ceph snapshots which show up as zero
  size.
* Add tempest support for limits and tests for these quotas.
* Implement configuring these quotas in devstack and integrate
  testing into a job.
* Add operator docs to explain how to enable, configure and use these
  quotas.


Dependencies
============

* This will require us to add ``oslo_limit`` as a dependency.
* This will require devstack support to test
* Tempest testing will be considered required for this, as the
  interaction across Keystone and Glance is key to ensuring
  correctness.


Testing
=======

Unit and functional testing will be straightforward in the
tree. Tempest testing will be provided, by setting a small limit on a
tenant and then uploading a few images to ensure we run across the
each limit.


Documentation Impact
====================

Since per-tenant quotas in Glance do not exist yet, the docs will need
to be updated to add coverage. Operators will need to know which
limits to configure in Keystone, how to do that, as well as how to
enable enforcing in Glance. Operators will also need to understand the
soft-limit nature of the size-based quotas, and how Glance's
willingness to accept unbounded uploads impact quota enforcement.

References
==========

* Keystone unified limit docs:
  https://docs.openstack.org/keystone/latest/admin/unified-limits.html
* Glance Xena PTG etherpad where this was raised again recently:
  https://etherpad.opendev.org/p/xena-glance-ptg
* Gerrit topic for implementation and tests:
  https://review.opendev.org/q/topic:%22bp%252Fglance-unified-quotas%22+(status:open%20OR%20status:merged)
