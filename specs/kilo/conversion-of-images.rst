..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==============================
  Basic conversion of Images
==============================

https://blueprints.launchpad.net/glance/+spec/basic-import-conversion

Some store engines work better when working with specific image
formats. For example, in the case of ceph, having a raw image improves
performance and allows ceph to do smarter things with the image
data. Therefore, this spec proposes adding a basic support to image
conversion that will give operators full control on the destination
format. The proposed change is the starting point for more complex
conversion operations.


Problem description
===================

With the support of asynchronous operations and the new import
workflow in Glance (see the dependency tree), it will be possible to
have an image format conversion on the fly while importing an image.

The conversion will be provided by a plugin of the import
workflow. This plugin can be activated or not based on the deployer
configuration. This means that the deployer will need to specify the
preferred format of images for the deployment.

This blueprint will handle the conversion of formats supported by
qemu-img convert: raw, qcow2, vdi, vmdk and vpc.

Internally, Glance will receive the bits of the image in a XX
format. These bits will be stored in a temporary location. The plugin
will be triggered to convert the image to its target format YY and
moved to its final destination. When the task is finished, the
temporary location is deleted.  This means that the format uploaded
initially is not kept by Glance.


Proposed change
===============

Using `Glance's Asynchronous Workers`_, we can execute a background
task that converts images from the source format to a pre-configured
format.

.. _Glance's Asynchronous Workers:
    https://blueprints.launchpad.net/glance/+spec/async-glance-workers

Alternatives
------------

Let the user convert images themselves and upload the final, converted, file.

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

Based on the maximum number of workers and the size that the administrator has
configured for the conversion workspace, performance could be negatively
affected if the operator misconfigures their maximum number of workers and
allocated workspace.

In addition to the above, it's also important to consider the time
required to download the image locally, convert it and then upload it
to the final store. The implementation proposes using ``qemu-image``,
which executes random accesses to the image data.

Other deployer impact
---------------------

When configuring this feature, operators will need to know the average size of
the images that they are managing and appropriately configure the
``max_workers`` setting and an appropriate amount of space for the workers to
use.

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  flaper87

Other contributors:
    None

Reviewers
---------

Core reviewer(s):
  jokke\_
  nikhil-komawar
  kragniz
  icordasc

Work Items
----------

- Create specific workers for different conversion tasks

- Create workflows for tasks

- Update configuration files with additions

- Update configuration documentation


Dependencies
============

This depends on `Glance's Asynchronous Workers`_.


Testing
=======

Unit testing will be needed for the conversion tasks and for the new task
flows.


Documentation Impact
====================

This may have an impact on the upgrade and installation parts of the
documentation. For operators upgrading, they'll need to understand how to
properly configure a system for image conversion. For new users, they'll
need to be warned about appropriately allocating space for the workers to use
and possibly choosing a more conservative maximum worker number than is
default until they can determine the appropriate number.


References
==========

None
