..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===========================
multi-store backend support
===========================

https://blueprints.launchpad.net/glance/+spec/multi-store

The Image service supports several back ends for storing virtual machine
image namely Block Storage service (cinder), Filesystem (a directory on
a local file system), HTTP, Ceph RBD, Sheepdog, Object Storage service
(swift) and VMware ESX. As of now operator can configure single backend
on a per scheme basis but it's not possible to configure multiple backends
for same or different stores. For example if a cloud deployment has
multiple ceph deployed glance will not be able to use all those backends
at once.

Consider the following use cases for providing multi-store backend support:

 * Deployer might want to provide different level of costing for different
   tiers of storage, i.e. One backend for    SSDs and another for
   spindles. Customer may choose one of those based on his need.
 * Old storage is retired and deployer wants to have all new images being
   added to new storage and old storage will be operational until data
   is migrated.
 * Operator wants to differentiate the images from images added by user.
 * Different hypervisors provided from different backends (For
   example, Ceph, Cinder, VMware etc.).
 * Each site with their local backends which nova hosts are accessing
   directly (Ceph) and users can select the site where image will be stored.

Problem description
===================

At the moment glance only supports a single store per scheme. So for example,
if an operator wanted to configure the Ceph store (RBD) driver for
2 backend Ceph servers (1 per store), this is not possible today without
substantial changes to the store driver code itself. Even if the store driver
code was changed, the operator today would still have no means to upload or
download image bits from a targeted store without using direct image URLs.

As a result, operators today needs to perform a number of manual steps
in order to replicate or target image bits on backend glance stores. For
example, in order to replicate a existing image's bits to secondary storage
of the same type / scheme as the primary:

 * It's a manual out-of-band task to copy image bits to secondary storage.
 * The operator must manage store locations manually; there is no way to
   query the available stores to back an image's bits in glance.
 * The operator must remember to register secondary location URL using
   the glance API.
 * Constructing the location URL by hand is error prone as some URLs are
   lengthy and complex. Moreover they require knowledge of the backing store
   in order to construct properly.

Also consider the case when a glance API consumer wants to download the image
bits from a secondary backend location which was added out-of-band. Today
the consumer must use the direct location URL which implies the consumer
needs the logic necessary to translate that direct URL into a connection
to the backend.


Current state
=============

Glance community agrees to address the problem described above during
Rocky/S cycles. The actual detailed specification is still under discussion
and will amend this spec as https://review.openstack.org/#/c/562467 when
the implementation details are agreed on.
