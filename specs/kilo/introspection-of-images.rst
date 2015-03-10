..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===========================
  Introspection of Images
===========================

https://blueprints.launchpad.net/glance/+spec/introspection-of-images

Several image formats include metadata inside the image data. This spec
proposes that Glance expose that metadata through introspection of the image.
For example, we can read the metadata from a ``vmdk`` formatted image to know
that the disk type of the image is "streamOptimized". Allowing Glance to
perform the introspection removes the burden from the administrator. Exposing
this metadata also helps the consumer of the image; Nova's workflow is very
different based on the disk type of the image.


Problem description
===================

Several image formats include metadata inside the image data. A stream
optimized ``vmdk`` image could be introspected like so:

.. code::

    $ head -20 so-disk.vmdk

    # Disk DescriptorFile
    version=1
    CID=d5a0bce5
    parentCID=ffffffff
    createType="streamOptimized"

    # Extent description
    RDONLY 209714 SPARSE "generated-stream.vmdk"

    # The Disk Data Base
    #DDB

    ddb.adapterType = "buslogic"
    ddb.geometry.cylinders = "102"
    ddb.geometry.heads = "64"
    ddb.geometry.sectors = "32"
    ddb.virtualHWVersion = "4"

When a user of the image looks at the metadata they will see important
information like the required disk type, "streamOptimized". Extracting the
metadata in Glance and exposing it through Glance's API, means that
administrators and image users alike do not need to perform the introspection
themselves. Consumers like Nova will have very different workflows based on
disk type alone and could also optimize the rest of its workflow based on
other image metadata.


Proposed change
===============

Using `Glance's Asynchronous Workers`_, we can extract the image metadata
without requiring a separate node and without suffering significant
performance degradation.

.. _Glance's Asynchronous Workers:
    https://blueprints.launchpad.net/glance/+spec/async-glance-workers

Alternatives
------------

A separate worker node could ostensibly be controlled to prevent degradation
on the Glance API nodes but is an unnecessary addition to the architecture.

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
configured for the introspection workspace, performance could be negatively
affected if the operator misconfigures their maximum number of workers and
allocated workspace.

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
  jokke\_

Reviewers
---------

Core reviewer(s):
  nikhil-komawar
  kragniz
  icordasc

Work Items
----------

- Create specific workers for different introspection tasks

- Create workflows for tasks

- Update configuration files with additions

- Update configuration documentation


Dependencies
============

This depends on `Glance's Asynchronous Workers`_.


Testing
=======

Unit testing will be needed for the introspection tasks and for the new task
flows.


Documentation Impact
====================

This may have an impact on the upgrade and installation parts of the
documentation. For operators upgrading, they'll need to understand how to
properly configure a system for image introspection. For new users, they'll
need to be warned about appropriately allocating space for the workers to use
and possibly choosing a more conservative maximum worker number than is
default until they can determine the appropriate number.


References
==========

None
