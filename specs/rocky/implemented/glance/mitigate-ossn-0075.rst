..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==================
Mitigate OSSN-0075
==================

https://blueprints.launchpad.net/glance/+spec/mitigate-ossn-0075

OpenStack Security Note `OSSN-0075`_, "Deleted Glance image IDs may be
reassigned", was made public on 13 September 2016.  The current situation is
that due to a lack of agreement of how to fix it, we've left operators in a bad
state: our advice is that soft-deleted rows in the 'images' table in the Glance
database should *not* be purged from the database, yet at the same time, the
``glance-manage`` tool deletes such rows without warning.

Problem description
===================

Briefly, the problem is that Glance has always allowed a user with permission
to make the image-create call the option of specifying an image_id.  If the
specified image_id clashed with an existing image_id, the image-create
operation would fail; otherwise, the specified image_id would be applied to the
new image.  Consistency is enforced by a uniqueness constraint on the 'id'
column in the 'images' table in the database.  Since Glance database entries
are soft-deleted, a proposed image_id will be checked against all image_ids
that were assigned since the last purge of the 'images' table.

As described in `OSSN-0075`_, this problem becomes a security exploit when (a)
a popular public or community image is deleted, (b) the database is purged,
and (c) a user creates a new image with that same image_id.  Users consuming an
image by image_id, which is the way Nova and Cinder consume images, may then
wind up booting virtual machines using an image different from the one they
intend to use.

Note that the new image would have its own data and checksum that would be
different from the original data and checksum, but there would be no way for
Nova, for instance, to know that these had changed.  Were someone to boot a
server using the image_id, Nova would receive image data and then verify the
checksum against whatever checksum Glance has recorded as associated with the
image, which would be the *new* checksum.

The idea that once an image goes to 'active' status, the (image_id, image data,
checksum) will not change is called *image immutability*.  It's important to
note that image immutability is required for Glance or else it cannot function
as an image catalog.  If each consumer had to keep track of the image_id *and*
checksum *and* other essential properties in order to verify the downloaded
data, then there'd be no point in having Glance maintain this information.

.. note::

   The primary use case for allowing end-users to specify an image_id at the
   time of image creation is to make it easy to find the "same" image data
   (that is, the data is bit-for-bit identical although it's stored in
   different locations) in different regions of a cloud.  It's important to
   note that the "sameness" of images in different regions is *not* guaranteed
   by Glance.  (A Glance installation can guarantee the immutability of images
   within its own region, but it has no way of knowing what's happening in
   other regions.)  Thus, under the current situation, when an end user relies
   on the image_id as the guarantor that they're getting the "same" data in
   different cloud regions, the end user is actually relying upon the
   trustworthiness of the *image owner*.

   This is a separate issue from `OSSN-0075`_ and is independent of whether or
   not the Glance database is ever purged.  We point it out as something for
   operators to keep in mind.  To be clear about the issue, here's an example.
   Suppose that a cloud operator puts an image with image_id A in regions R, S,
   T, though for some reason the operator does not put that image in region U.
   Any cloud user in region U could create an image with image_id A in
   region U.  The image could then be made available to some target user by
   image sharing, or with the entire cloud by giving it 'community' visibility.

   An operator can avoid this scenario by creating an image record with
   image_id A in region U and not uploading any data to it.  The image will
   remain in 'queued' status, and if the visibility is not changed to 'public'
   or 'community', the image will not appear in any end user's image-list
   response.

   There is also room for end user education here, namely, that image
   consumers should *not* rely solely upon image_id to guarantee that they are
   receiving the same image data in cross-region scenarios.

Through discussions with operators, it's clear that the ability to set the
image_id on image creation is being used out in the field, so we can't simply
block this ability.  At the same time, we must allow the database to be
occasionally purged, as there is evidence that for large deployments, having a
large number of soft-deleted rows in the 'images' table affects the response
time of the image-list API call.

Proposed change
===============

Modify the current ``glance-manage db purge`` command so that it will not purge
the images table.

Introduce a new command, ``glance-manage db purge-images-table`` to purge the
images table.  The new command will take the same options as the current purge,
namely, ``--age-in-days`` and ``--max-rows``.  The rationale for this being a
new command (rather than a ``--force`` option to the current command) is
twofold: (1) it's likely that the age-in-days used will be different for the
images table, and (2) given that purging the images table has a security
impact, having it as a completely separate command emphasizes this.

Alternatives
------------

1. Introduce a policy governing whether or not a user is allowed to specify
   the image_id at the time of image creation.  The downside of this proposal
   is twofold:

   * it breaks backward compatibility given that this ability has been allowed
     up to now in both the v1 and v2 versions of the Image API
   * it breaks interoperability in that end uses will have the ability in some
     clouds but not in others

   A further problem with this proposal is that if the cross-region use of
   a particular image_id is denied to end users, they will have to use some
   other piece of image metadata for this purpose.  Since cinder and nova both
   use the image_id when services are requested, user workflows will have to
   change to introduce an extra call to the image service to find the image
   record before the image_id to pass to cinder or nova is determined.

2. Instead of introducing a new column in the images table, introduce a new
   single-column table with a uniqueness constraint to record "used" UUIDs.
   The image-create operation would try to insert a proposed UUID into this
   table instead of the 'images' table and fail as it currently does if the
   uniqueness constraint were violated.  This "used" UUID table would *never*
   be purged, but the glance-manage tool could continue to purge all other
   tables.

   This alternative has the advantage of not impacting the image-list call.  It
   would eventually introduce a small delay into the image-create operation,
   but that's probably acceptable.

   The downside is that this proposal introduces an unpurgable table that is
   unbounded in size.

3. A variation on alternative #2: instead of a single-column table, have at
   least a deleted_at column in addition to the image_id.  This table would not
   be touched by the "normal" ``glance-manage`` database purge operation.
   Rather, an additional purge operation could be introduced for this table
   that would purge rows that were, say, 5 years old from the table.

   A problem with this suggestion is that a determined attacker could
   nonetheless flood the "used" image_ids table.  This is possible because
   while it might make sense to limit the number of existing images a user
   owns, it doesn't make sense to limit the number of deleted images a user
   owns.  For example, an end user who creates an image of some important
   server every day, but only keeps around a week's worth, will accumulate many
   deleted images (multiplied by the number of servers this is being done for),
   but this is perfectly legitimate behavior.  So I'm not sure how flooding the
   "used" image_id table could be prevented, except by something like
   rate-limiting, though that would have to be set in such a way as not to
   impact legitimate use cases.

4. Introduce a new field, ``preserve_id``, for use in the images table.  This
   field will be for internal Glance use only and will not be exposed through
   the API.  This field will be null by default and will be set true whenever
   the 'visibility' field of an image is set to 'public' or 'community'.  There
   will be no way to unset the value of the field.  In addition to this, modify
   the glance-manage tool so that it will never delete an entry from the images
   table that has ``preserve_id`` == True.

   As with alternatives 2 and 3, the database table will continue to grow, but
   this growth is constrained by keeping only rows relevant to the OSSN-0075
   exploit.  On the other hand, all an attacker has to do is read this spec to
   realize that by creating image records with community visibilty, the images
   table can still be flooded with spurious image records.  Thus this strategy
   is too easily defeated to be worth implementing, especially as it might give
   operators a false sense of security.

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

This change will enhance security by providing operators with a means of
mitigating the exploit described in `OSSN-0075`_.

Notifications impact
--------------------

None

Other end user impact
---------------------

None

Performance Impact
------------------

The images table will grow indefinitely, though the associated tables
(image_properties, image_tags, image_members, image_locations) can be purged by
the ``glance-manage`` tool.

The images table can be partially purged at appropriate intervals.

Other deployer impact
---------------------

Operators will have to monitor Glance for abnormal usage patterns and take
appropriate action.

Additionally, operators should be made aware of the cross-region version of the
OSSN-0075 exploit (as discussed in the Note in the Problem Description
section).

Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:

* brian-rosmaita

Other contributors:

* undetermined

Work Items
----------

1. Modify the ``glance-manage`` tool:

   * The current behavior is that it purges all tables of soft-deleted rows.
     Change the behavior so that the images table is not purged by default.

   * Add a new command to purge the images table.  It should take the
     ``--age-in-days`` and ``--max-rows`` options just like the current purge
     command.

2. update operator documentation

3. release note

Dependencies
============

No new dependencies.

Testing
=======

Appropriate unit tests to ensure the changes to glance and the glance-manage
tool function correctly.

Documentation Impact
====================

The Glance Administrator Guide will need to be updated.

References
==========

`OSSN-0075`_: `Deleted Glance image IDs may be reassigned`.

.. _OSSN-0075: https://wiki.openstack.org/wiki/OSSN/OSSN-0075
