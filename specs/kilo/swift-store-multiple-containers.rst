..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

================================================================
Glance Swift Store to use Multiple Containers for Storing Images
================================================================

https://blueprints.launchpad.net/glance/+spec/swift-store-multiple-containers

Glance, when configured to use Swift store in Single Tenant Mode, stores
images in one container as indicated by the configuration option,
swift_store_container. This approach of storing images in ONE container
is subject to performance bottleneck.

Storing images in one container is prone to Swift rate-limiting on
containers. Swift is equipped with container rate-limiting that can throttle
concurrent POST, PUT and DELETE operations in a single container.
This becomes a serious issue in a large scale deployments especially
when coupled with smaller segment sizes.


Problem description
===================

Swift is known to be capable of throttling incoming traffic[1]. The very fact
that swift can throttle write operations on containers presents a performance
bottleneck and hence large scale deployments need an alternative to get
around Swift throttling.

When container rate-limiting is enabled for a Swift cluster, it throttles
concurrent POST, PUT and DELETE requests after a certain configurable rate.
This directly translates to a limit on concurrent image creation and deletion
operations for Glance before experiencing performance degradation.

Proposed change
===============
To reduce/overcome the performance bottleneck, we propose the use of multiple
containers for storing images in Single Tenant Mode (this change will not
affect Multi Tenant Mode because that setup stores each image in its own
container). This leads to increased concurrency of image creation and deletion
operations.

There are four major aspects to this change:

- Container Selection - determining what container an image should go into
- Container Creation - creating the new containers
- Re-distribution of Existing Images - moving images from old to new containers
- Database Migration - updating image locations as per new containers

**1) Container Selection:**

This change proposes to select containers based on image uuid. Images will be
stored in multiple containers in order to avoid throttling during
multiple simultaneous uploads. The first N characters of the image UUID, where
N is a configurable integer between 1 and 32, the number of hex digits in a
UUID, with the default value of 2, will be used to determine which container
the image will be uploaded to. With the default value of the first two
characters used, this gives 16*16=256 unique containers. At N=1, the smallest
valid value for this configuration, 16 containers will be created and used for
storing images. The containers will be named after the value set for
swift_store_container with the first N chars of the image UUID as the suffix.

Example: if this config option is set to 3 and
swift_store_container = 'glance', then an image with UUID
'fdae39a1-bac5-4238-aba4-69bcc726e848' would be placed in the container
'glance_fda'. All dashes in the UUID are included when creating the container
name but do not count toward the character limit, so in this example with N=10
the container name would be 'glance_fdae39a1-ba'.

The number of containers can be easily increased or decreased by changing N in
the configuration. However, a new set of containers will be created with every
change to this configuration. Images created after a configuration change
will go into new containers while older images remain in their previous
containers. The older images do not need to necessarily be moved into new
containers as their locations would still point to the existing older container
they are stored in. This means that changing N in the configuration will
never result in existing containers being deleted. However, if one wishes to
move the older images to new containers, they may do so by re-distributing the
images, which is described later in this section.

Note: 'storing' an image in a container implies storing the manifest and all
the image segments in the same container. Unless otherwise mentioned, this
continues to hold true all through this specification.

**2) Container Creation:**

Glance ships with a configuration option to dynamically create the container,
if it doesn't exist already at the time of uploading image data to Swift. This
is indicated by configuration option, swift_store_create_container_on_put. If
dynamic container creation is enabled, Glance would automatically create each
container when the appropriate container for that image is not found.

However, if the config option for dynamic container creation is disabled, image
uploads would fail if the appropriate containers are not created manually by
the deployer. This behavior is consistent with how Glance currently handles
missing containers if the config option to create them is not enabled.


**3) Re-distribution of Existing Images (out of scope):**

This spec will not provide code or scripts to migrate existing images since
lazy loading is an existing effective method of distributing new images.
However, if one wants to migrate images here is the process: Once the use of
multiple containers is enabled or the number of containers is changed, all
previously created images would remain in the older container(s). If desired,
older images can be moved to new containers appropriately. This can be achieved
as a separate batch job that can be run as and when desired. Subject to the
number of older images, redistributing images may involve significant movement
of data in the Swift cluster. Hence, it would be helpful to achieve this in
phases and in a non-intrusive fashion. Once the images are re-distributed,
their image locations need to be updated as well.


**4) Database Migration (out of scope):**

If images are re-distributed by operator choice, image location of each
re-distributed image must be updated to reflect the new container name. This
requires a db migration to replace the old container name in the location with
the new container name as per the image id. This migration can go
hand-in-hand with re-distribution.


**Scope of this spec:**

Of the four aspects discussed above, this specification only addresses
container creation and selection while leaving re-distribution and the
required db migrations out, which can be implemented as another concerted
effort.

Alternatives
------------

1) Instead of using image id as the basis for container selection, one can use
other basis like tenant id, which would keep all images belonging to a certain
tenant in the same container. While other container name basis are possible,
using image id provides an easier way to correlate an image to its container.

2) An alternative to creating containers could be to allow the API to create
all the required containers while it boots up. This requires the API to know
all possible containers before hand, which may or may not be possible depending
upon the container selection basis chosen. This places a certain limitation on
the kind of bases one may opt for. Hence, going with dynamic container creation
will eliminate this limitation as both container selection and creation could
be dynamic. Also, dynamic container creation is in-line with current Glance
behavior.

3) Instead of grouping multiple images together in a container, one alternative
would be to give each image its own container. However, that doesn't solve any
problems, it just moves the cardinality issues from the container to the
account. Additionally, some deployers limit the maximum number of containers
allowed per account. White-listing certain accounts to bypass a container limit
would defeat the purpose of swift ratelimits which are chosen by deployers in
order to protect the entire cluster.


Data model impact
-----------------
New containers will be created and used for storing images. However, this
does not have any impact on the Glance image data model itself.

**Database migrations**:

No database migrations are required. The code supporting multiple containers
would only affect the uploading of new images, determining which container they
belong to based on uuid. For existing images (those uploaded before support
for multiple containers), the image already contains a valid location in its
metadata. Essentially, new containers will be populated by lazy loading: When
an image is uploading, it will first check through a HEAD request if the
appropriate container exists for that image based on its UUID, and if the
container does not exist then the container will be created immediately with a
PUT request.  This image will then be the first image stored in that particular
container.


REST API impact
---------------

None

Security impact
---------------
Given the scope of this spec, where image data is not being re-distributed
among new containers and no migrations are being run, there is minimal
to no security impact introduced.


Notifications impact
--------------------

This change only impacts the image location property among all the image
properties. And, since image location is not included in notifications, there
should be no impact to Glance notifications.

Other end user impact
---------------------

As image location is not accessible to either the end-user or from Glance
client, there should be no end-user impact.

Performance Impact
------------------

The use of multiple containers will reduce throttling when multiple images are
uploaded simultaneously. This leads to increased concurrency of image creation
and deletion operations in large scale deployments.

Container selection would take place for every image upload request and thus
adds an extra operation to the current set of operations to upload image data.
However, selecting a container would be a simple substring operation to fetch
the first few characters of an image id. The time incurred in determining the
container would be significantly smaller than the time incurred to upload image
data. Overall, the performance impact of container selection should be very
minimal.

Container creation is a conditional operation that would take place only when
the container is not present already. This would occur once for each
combination of N characters as specified in the configuration.
For example, the default configuration option is that the first 2 characters of
the image UUID are used to select an appropriate container, leading to a total
of 256 containers which should be optimal for mid size deployments. We found
that in a large scale deployment, 4096 containers would be preferred over 256
containers if smaller segment sizes were chosen. The time incurred in creating
a new container is significantly smaller than the time incurred in upload image
data. Hence, the overall performance impact in image uploads should be minimal.

Other deployer impact
---------------------

This change would begin taking effect upon enabling multiple containers in a
configuration. When enabled, new images would be uploaded to new containers,
while existing images would remain in their previously assigned container.
This change is forwards and backwards compatible, such that the deployer can
choose to enable or disable multiple containers at any time and images will
still upload and download correctly.

Deployers should note that if their deployment limits the total number of
containers per account, the seed for the total number of containers should be
set such that this limit is not hit.


New configuration option in *glance-api.conf*

**swift_store_multiple_containers_seed** - default = 0

When set to 0, a single-tenant store will only use one container to store all
images. When set to an integer value between 1 and 32, a single-tenant store
will use multiple containers to store images, and this value will determine
how many containers are created. Used only when swift_store_multi_tenant is
disabled. The total number of containers that will be used is approximately
equal to 16^N, so if this config option is set to 2, then 16^2=256 containers
will be used to store images.

Example: if this config option is set to 3 and
swift_store_container = 'glance', then an image with UUID
'fdae39a1-bac5-4238-aba4-69bcc726e848' would be placed in the container
'glance_fda'. All dashes in the UUID are included when creating the container
name but do not count toward the character limit, so in this example with N=10
the container name would be 'glance_fdae39a1-ba'.

When choosing the value for swift_store_multiple_containers_seed, deployers
should discuss a suitable value with their swift operations team. The authors
of this spec recommend that large scale deployments use a value of '2', which
will create a maxiumum of ~256 containers. Choosing a higher number than this,
even in extremely large scale deployments, may not have any positive impact
on performance and could lead to a large number of empty, unused containers.
If dynamic container creation is turned off, any value for this configuration
option higher than '1' may be unreasonable as the deployer would have to
manually create each container.


Any diagnostic/monitoring scripts assuming images to be stored in a single
container may need appropriate changes.


Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  hemanth-makkapati

Other contributors:
  ben-roble

Reviewers
-----------

Core reviewer(s):
  nikhil-komawar brian-rosmaita

Other reviewer(s):
  None

Work Items
----------

1) Implement new config options in Swift store driver
2) Implement container selection in Swift store driver
3) Implement unit, functional, and integration tests
4) Change glance-api sample conf in glance repo

Points to note:

- All code changes would be limited to glance_store module.
- Image download code wouldn't require any changes.
- Both manifest and segments would go into the same container.

Dependencies
============

None


Testing
=======

No tempest tests needed


Documentation Impact
====================

* Document new configuration options

References
==========

[1] http://docs.openstack.org/developer/swift/ratelimit.html#configuration

