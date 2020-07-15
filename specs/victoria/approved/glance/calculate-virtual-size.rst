===============================
Calculate virtual size of image
===============================

https://blueprints.launchpad.net/glance/+spec/calculate-virtual-size

'virtual_size' should be set on image to avoid running `qemu_img`
operations on consumer nodes.

Problem description
===================

Image has virtual_size field in images table but it is never set unless
we use taskflow `introspect` to create image. Consumers of glance
like nova or cinder never consume image before calculating virtual
size, which means every time they call for image, they need to
perform `qemu_img info` call to calculate the virtual size of the image.

Use Case:
---------

'virtual_size' should be set on image to avoid running `qemu_img`
operations on consumer nodes.

Proposed change
===============

All supported sparse disk image formats (i.e. what glance calls disk_format)
simulate a larger virtual disk than the actual data that is stored, and
record that virtual size in metadata. We propose to add a handler for each of
the formats that can examine the chunks while streaming the image to extract
the relevant metadata to determine the virtual disk size.

In glance, users can create images using two ways.
1) Create image API
2) Import image API

With this change virtual size will be set to image even user tries to use any
of above two methods to create the image. Also images created by nova
(nova-snapshot except 'direct-to-backend snapshot') or cinder
(volume-upload-to-image) will be able to set the virtual size to image as well.

NOTE: To start with we are going to calculate virtual size for images which
will have container-format ``bare`` or other ``uncompressed`` formats only.
Later as and when required or expected we will enhance it for other
container-formats.

We will be performing this operation during uploading image data to glance
store, so for image import this will happen during the actual import phase
and not the stage phase.

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
  danms

Other contributors:
  None

Reviewers
---------

Core reviewer(s):
    abhishek-kekane
    jokke
    rosmaita

Other reviewer(s):
    whoami-rajat

Work Items
----------

- Add handler for each of the disk-format
- Add wrapper around chunked reader to calculate virtual size
- Add unit tests for coverage
- Add functional tests

Dependencies
============

None

Testing
=======

Tempest test to verify that virtual size is set on image using glance,
nova snapshot and cinder upload-to-image operations.

Documentation Impact
====================

Please refer to 'Other deployer impact'

References
==========

https://review.opendev.org/#/c/744234
