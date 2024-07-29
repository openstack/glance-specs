..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=====================================================
Glance as first-line defense for image format attacks
=====================================================

https://blueprints.launchpad.net/glance/+spec/glance-as-defender

Glance is the point of entry for images into the cloud. It is the orifice
through which an untrusted (but authenticated) user brings an image into the
system, after which it will be processed by backend routines either for format
conversion or preparation for boot.

It is at this stage in the pipeline where we are best positioned to do sanity
checking about the images we accept, and the point at which we can validate
some of the metadata provided by the user to ensure that downstream services
(such as nova, glance, ironic and others) can reasonably assume that metadata
to be correct.


Problem description
===================

Glance will (for the most part) allow a user to upload literally content and
declare its format to be any of the valid values we have for ``disk_format`` and
``container_format``. This is certainly surprising to downstream services,
external consumers, and humans which expect the format stated on the image to
be in line with the actual content.

A further problem is in the use of the ``raw`` value for ``disk_format``. In
general, we use ``raw`` to mean "a byte-for-byte image of a block device",
usually with a partition table and often a bootloader (in the case of a root
disk). However, in reality ``raw`` has come to mean "anything in a format for
which we do not have another name". This catch-all behavior means that if we
want to support images of full-disk formats, we also need to support
"anything else we don't know about" to some degree.


Proposed change
===============

This spec proposes two major changes to glance:

First, we will start enforcing that the format of the uploaded content matches
the ``disk_format`` declared on the image. Since our ``format_inspector`` module
is already in the data pipeline for both *upload* and *import* we simply need
to remove the "never fail" behavior we currently have and abort the process
if we determine that the format does not match what was claimed. Consider the
following two examples:

1. An image is declared to be of format ``qcow2`` but the content uploaded is
   something else (either another complex format such as ``vmdk`` or something
   we do not recognize).
2. An image is declared to be of format ``raw`` but the content uploaded is
   detected as a ``qcow2``.

Ideally, we would reject both of these cases. However, the second is more
complex because there are situations where a service handling a disk image
that it does not assume any particular format may be stopped from storing it
in glance if the user of that image has given it a specific format. Thus, for
the first iteration of this work, we will only enforce the first case, which
means that ``raw`` could contain a ``qcow2``, but a ``vmdk`` could not.

The use of ``[image_format]/disk_formats`` will effectively
allow an admin to limit the types of disks they accept. Today, that only
limits "honest" users, but this change will make it enforced on content as
well.

The second major change is significant in terms of the model and behavior
of existing users, but is small in absolute terms and impact to glance itself.
A new ``disk_format`` option of ``gpt`` will be added, which will henceforth
serve to signify that "this is an image of a raw block device with a partition
table" thus removing our need to overlap that definition with "this is
something we do not recognize" for ``raw``. The definition of ``gpt`` is
actually a superset of the legacy PC MBR (Master Boot Record) format, which
means an inspector for this format should have no problem detecting and
allowing images of very old (read: Windows XP/2003 vintage) disk images. Thus,
many of the images we now legitimately use ``raw`` for will be (and need to be
converted to be) a ``disk_format`` of ``gpt`` going forward.

We will add a configuration option to disable this behavior as a relief valve
to support migration to this stricter model and/or to account for false
positive detections.

* ``require_image_format_match``: Default to true, but allow setting to false
  to avoid aborting the upload/import if the format does not match the content.

Alternatives
------------

Glance could continue to be ambivalent about the content uploaded and the
mismatch between that and the metadata it stores. Services like nova and
cinder will have to continue treating glance as untrustworthy and remain
highly suspicious of its metadata.

Data model impact
-----------------

The only data model change that should be required here is one to allow the
new ``disk_format`` value of ``gpt`` to be specified in the API and stored in
the database.

There will, of course, be a need to convert existing ``raw`` images in the
database to ``gpt``, and thus some tooling will be required. Options for that
could be a ``glance-manage`` command to automatically (or manually) do this,
or allow it to be done through the API. Alternately, we could also annotate
existing images and have the API report them as ``gpt`` if the client is
determined to be new enough.

REST API impact
---------------

The main REST API impact comes from allowing ``gpt`` as one of the valid
options for ``disk_format``. Additional impact could come if we decide to
provide format conversion (or reporting) through the API.

Security impact
---------------

In general, this will improve security for the entire cloud by allowing nova,
cinder, and other users of glance some amount of trust in the image content
and associated metadata. It is important to avoid the other services
thinking they no longer need to inspect image content entirely. Security for
this sort of thing is best provided in layers and services need to continue
to be vigilant about images they download from glance, certainly applying
context-specific checks before using them.

Notifications impact
--------------------

None (aside from the new format).

Other end user impact
---------------------

Users will defintitely be impacted as the muscle memory of (over) using raw as
both a catch-all and as meaning "an image of a whole disk" will take some
time to un-learn.

Performance Impact
------------------

We are already using ``format_inspector`` in the data pipeline. We will need to
run all the inspectors in parallel instead of just the declared-format one
we are currently using. However, these are designed to be as memory-efficient
as possible, and thus the overhead should be minimal. Actual performance of
the upload itself should not be impacted.

Other deployer impact
---------------------

Deployers will have work to do here for sure, specifically as existing disks
marked as ``raw`` will (mostly) need to be converted to ``gpt``. We can not
just convert any ``raw``, as many of those may be kernel images, or other
formats that we do not (but probably need to) support identifying.

Options for that would be:

1. Tell operators to just do it themselves and provide some way to change the
   ``disk_format`` of an image in the database.
2. Provide a tool to detect and convert the images based on content. We can,
   in many cases, do this without seeing the whole image, as things that
   should be ``gpt`` will be identified within the first sector or two of
   the content. This could be used only for converting ``raw`` to ``gpt``, but
   could be written generically in a way that allows operators to audit all
   their images to make sure they are in the format they claim to be.

Developer impact
----------------

No specific impact, although as more formats need to be supported, additional
inspector modules will need to be written.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  danms

Work Items
----------

* Make the ``format_inspector`` in the data pipeline detect all formats and
  abort the upload if the format is determined and does not match
* Make glance depend on ``oslo.utils`` for ``format_inspector``
* Add ``gpt`` as a valid ``disk_format``
* Write tooling for converting ``raw`` disks to ``gpt`` in the database
* Add config options for new/fallback behaviors

Dependencies
============

The `gpt` part of this depends on the `oslo port of the inspector 
<https://review.opendev.org/q/topic:%22add-format-inspector%22>`_ code.

Testing
=======

We will need negative tempest tests for format mismatches, which can be written
without much drama. Most of the formats require just a few 512-byte sectors of
data to be detected and we can generate those inline in tempest tests to make
sure that glance rejects mismatches.

Documentation Impact
====================

We will definitely need documentation about the raw-to-gpt behavior change,
and we could definitely use better documentation about when to use ``raw``,
which will be easier to explain in the context of ``gpt``.

References
==========

* `QCOW data-file security bug <https://bugs.launchpad.net/nova/+bug/2059809>`_
* `VMDK safety security bug <https://bugs.launchpad.net/nova/+bug/1996188>`_
* `GPT format specification <https://uefi.org/specs/UEFI/2.10/05_GUID_Partition_Table_Format.html#id5>`_
