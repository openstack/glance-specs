..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==================================================
Support download from and upload to Cinder volumes
==================================================

https://blueprints.launchpad.net/glance/+spec/cinder-store-upload-download

Current Glance's Cinder backend driver only can get the volume size but
doesn't support read, write and deletion of volumes.

As missing parts in Cinder side (listed in [1]_: os-brick library,
readonly-volumes, multi-attach) are now supported, now we can implement
read (download), write (upload), and deletion for it.

When an raw image is backed on the cinder store, a new volume with the image
can be created by cloning the image volume. This will be useful to launch
boot-from-volume instances rapidly as some Cinder drivers can clone a volume
efficiently using copy-on-write. It will also improves storage capacity with
the drivers which support thin-provisioning. [3]_

Note that the image volume itself is not intended to be used as a boot-volume
for an instance. Image volumes are marked read-only, so they cannot be attached
to instances in read-write mode. Instead, cloned volumes should be used for
booting instances.

Problem description
===================

Without upload, download and deletion support of Glance's Cinder backend
driver, it can't be used as a default store.


Proposed change
===============

This spec proposes implementing image uploading to and downloading from Cinder
volumes, and deletion of the volume on the image deletion.

* Uploading steps:

  - Create a new volume with the size that can store the image. It will be
    placed in the tenant specified in glance-api.conf.

  - Attach the new volume to the glance-api host using the os-brick library.

    - The os-brick library collects the connector (host) information, such as
      the initiator IQN for iSCSI or WWN for FibreChannel.

    - Call ``initialize_connection`` API of Cinder with the connector
      information and the volume as arguments to get the volume connection
      information, such as target portal IP address and IQN for iSCSI.

    - Pass the connection information to the os-brick's ``connect_volume``
      method to attach the volume to the host. The volume device information
      such as the device path (e.g. ``/dev/sdX``) is returned.
      This step requires root privilege to execute the command for iSCSI, FC
      and so on, so the ``glance-rootwrap`` must be installed and it should
      allow the commands for os-brick. [2]_

  - Write the image data to the volume from the given device path.

  - Detach the volume from the host.

    - Call the os-brick's ``disconnect_volume`` method and Cinder's
      ``terminate_connection`` API to remove the volume connection.

  - Mark the volume as read-only.

  - Add volume metadata that indicate the image size, image ID, image owner
    (to track the owner even when it is placed in the service tenant). e.g.:
    ::

       {
        'image_id': 'e38f5596-4bd3-4b63-b4ef-88bcc814ed8e',
        'image_owner':     'b58fffa08b4242988c42950b5f24fcd5',
        'image_size':      '228599296',
       }


* Downloading steps:

  - Attach the image volume to glance-api host as read-only.

  - Read the image data from the volume.

  - Detach the volume.

* Deletion steps:

  - Call the Cinder's ``delete`` API to delete the volume when the image is
    deleted.

As cinder currently doesn't support ACL or public volumes among tenants,
in order to support public or sharable images, the image volume should be
placed in the service tenant which is only accessible from the Glance and
Cinder services to control the accessibility.

Alternatives
------------

None

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

To attach and detach volumes to the host, root privilege is required to
operate block devices on the host. Glance needs to import oslo-rootwrap
to allow only required commands for these operations to be executed as root.

The Glance node must be a part of storage network (iSCSI, FC etc.). In theory
that might open new attack vectors each way.

Notifications impact
--------------------

None

Other end user impact
---------------------

None

Performance Impact
------------------

When creating a new Cinder volume from an image stored in the Glance Cinder
store, or creating a new image from a volume, Cinder is able to offload
the image copy using storage array features such as background copy or
copy-on-write, if some conditions (e.g. image stored in Cinder backend is in
raw format) are satisfied. This will improve the performance of image copy
significantly.

Nova-compute will be able to bypass the image copy by attaching the image
volumes to the host, if Cinder is deployed.

Note that the image upload/download requires sufficient bandwidth to/from
cinder storage.

Other deployer impact
---------------------

To use cinder backends, the Glance node must be able to access the backend
storage and it may require additional hardware connectivity (iSCSI, FC, etc.).
Operators have to configure cinder and glance-api.conf appropriately.

- To enable cinder store, ``cinder`` must be added to the ``stores`` option in
  the glance-api.conf.

- To place the image volume into the specific tenant, authentication information
  for the tenant must also be provided.

- The glance-rootwrap must be installed. The rootwrap config path should also be
  configured in glance-api.conf.

- To offload the image copy on volume creation to the storage array, the
  ``allowed_direct_url_schemes`` option should contain ``cinder`` in
  cinder.conf. [3]_ Also, the glance-api host must be able to attach the
  Cinder volumes onto itself.


Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  tsekiyam

Reviewers
---------

Core reviewer(s):
  flaper87

Work Items
----------

* Import os-brick and oslo-rootwrap into glance_store.
* Extend current cinder backend driver to support upload, download and deletion.

Dependencies
============

None

Testing
=======

* Enable cinder backend in the devstack.

* Test uploading of an image to the cinder backend.

* Then test downloading of the image again.

* Delete the image and check if the volume is deleted.

* Test the other normal glance store operations such as owner changes and
  sharing.

Documentation Impact
====================

The documentation should be expanded to describe how to enable and use
cinder store. Especially, it should explain new options to configure cinder
authentication (tenant id, username, password) to store the volume into the
specific tenant.

It also needs to cover the requirement to Glance node being the part of storage
network (iSCSI, FC etc.) and having sufficient bandwidth towards the storage.

References
==========

.. [1] Blueprint: Adding a store driver to allow Cinder as a block storage
       backend for Glance:
       https://blueprints.launchpad.net/glance/+spec/glance-cinder-driver

.. [2] Rootwrap filter for os-brick:
       https://github.com/openstack/os-brick/blob/master/etc/os-brick/rootwrap.d/os-brick.filters

.. [3] Cloud Administrator Guide: Volume-backed image:
       http://docs.openstack.org/admin-guide-cloud/blockstorage_volume_backed_image.html
