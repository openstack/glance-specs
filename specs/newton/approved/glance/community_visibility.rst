..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=================================
Add community-level image sharing
=================================


*This spec is mostly based on an earlier blueprint created by Iccha Sethi, and
later picked up by Louis Taylor. We at Symantec have already implemented a
similar function within our local environment.  We want to re-target this
feature to Newton release.*

The blueprint may be found at:
https://blueprints.launchpad.net/glance/+spec/community-level-v2-image-sharing

This feature will allow image owners to share images across multiple
tenants/projects without explicitly creating members individually through the
glance API V2. "Community images" will not appear in users' default image
listings.

This new feature adds a new value for the visibility of an image to the
underlying data model, named ``community``.


Problem description
===================

Currently, there is no provision for an image to be available for use by users
other than the owner of the image, unless the image is either made public or
explicitly shared by the owner of the image with other users. If the number of
users who require access to the image is large, the overhead of explicit
sharing can become a burden on the owner of the image. Also, if such images
are not needed by the majority of users, then the image listing results will be
spammed if they are all made public.

Public images appear in ``image-list`` for all users. This can be undesirable
because:

1. An open source project wants to make a prepared VM image available so users
   simply boot an instance from that image to use the project's software. The
   developers of the project are too busy writing software to worry about the
   hassle of maintaining a list of "customers" as they'd have to do with
   current v2 image sharing. At the same time, the cloud provider hosting the
   prepared image doesn't want to make this image public, as that would imply
   a support relationship that doesn't exist between image consumers and the
   cloud provider. Moreover, if too many such images get published,
   then image listing will be spammed as this type of image should not be seen
   by most of the users.

2. A cloud provider wants to discourage users from using a public image that is
   getting old. For example, an image which is missing some security patches or
   is no longer supported by the vendor. The cloud provider doesn't want to
   delete the image because some users still require it. Users could need the
   old image to rebuild a server, or because they have custom patches for that
   particular image.

In both cases, the vendor can make the image a "community" image and alleviate
the challenges presented above. This means that:

   a) The community image won't appear in users' default image lists. This
   means they won't know about it unless they are motivated to seek it out, for
   example by asking other users for the UUID.

   b) Since the image is no longer "public," it doesn't imply the same level of
   support from the vendor as a provider-supplied public image.


Proposed change
===============

An additional value for the ``visibility`` enum will be added in the JSON
schema, named ``'community'``.  This makes the possible values of
``visibility``:

.. code:: python

    ['public', 'private', 'shared', 'community']

Images with these ``visibility`` values have the following properties:

* **public**:

  - Who: all users:

    + have this image in the default ``image-list``

    + can see ``image-detail`` for this image

    + can boot from this image

* **private**:

  - Who: users with ``tenant_id == owner_tenant_id`` only:

    + have this image in the default ``image-list``

    + see ``image-detail`` for this image

    + can boot from this image

* **shared**:

  - Who: users with ``tenant_id == owner_tenant_id``:

    + have this image in the default ``image-list``

    + can see ``image-detail`` for this image

    + can boot from this image

    + can see full member list for this image

  - Who: users with ``tenant_id`` in the ``member-list`` with
    ``member_status == 'accepted'`` of the image:

    + have this image in the default ``image-list``

    + can see ``image-detail`` for this image

    + can boot from this image

    + can see a member list containing only themselves for this image

  - Who: users with ``tenantId`` in the ``member-list``
    with ``member_status == 'pending'`` or ``member_status == 'rejected'``:

    + do not have this image in their default ``image-list``

    + can see ``image-detail`` for this image

    + can boot from this image

    + can see a member list containing only themselves for this image

* **community**:

  - Who: users with ``tenant_id == owner_tenant_id``:

    + have this image in the default ``image-list``

    + can see ``image-detail`` for this image

    + can boot from this image

  - Who: all users:

    + do not have this image in their default ``image-list``

    + can see ``image-detail`` for this image

    + can boot from this image


Membership Behaviour and Transitions
------------------------------------

After much discussion, it has been decided that this topic is complex enough
to break out into its own separate proposal. Between the significant number
of state transitions, and the problem use cases brought up by several people,
fully designing what the "correct" behaviour shall be is outside the scope of
this spec.

The behaviour for the initial implementation for community images shall
respect the current paradigm in glance - where changing visiblities does not
affect an image's internal member-list.


Alternatives
------------

Adding image aliases
~~~~~~~~~~~~~~~~~~~~

A completely different way of solving the usecase for cloud providers
(discouraging users from using an older version of a public image) could be to
create a mechanism to make an image alias, which could point at the newest
version of the public image. There is an abandoned blueprint for this feature
[#]_. This, however, is much harder to implement and does not fit with the
other use cases.

.. [#] https://blueprints.launchpad.net/glance/+spec/glance-image-aliases


Adding a special case of image sharing
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Another method of implementing this functionality is to add a membership record
for an image that has a target of ``"community"`` (i.e. it is shared with all
tenants) with ``membership_status = "community"``. This marks it as a community
image very simply and requires few modifications to existing code.

This respects the current anti-spam provisions in the glance v2 API. When an
image owner makes an image a "community" image, any other tenant should be able
to boot an instance from that image. The image will not show up in any
tenant's default image-list.

This method can cause a few corner cases which result in surprising API calls
and some less than desirable mappings between data model level and API level
values of visibility.


Data model impact
-----------------

Schema changes
~~~~~~~~~~~~~~

The visibility of the image will be stored in the database within the images
table inside a new column named ``visibility``. The visibility will be in the
set of ``['public', 'private', 'shared', 'community']``.

The default value for ``visibility`` is ``'private'``.

This change makes the ``is_public`` column redundant. If no v1 code actually
uses ``is_public``, the column will be removed.

Appropriate indexes will be added to facilitate quick responses.

Database migrations
~~~~~~~~~~~~~~~~~~~

1. All rows with ``is_public == 1``:

   - ``visibility = 'public'``

2. For all unique ``image_id`` in ``image_members`` where ``deleted != 1``:

   - ``visibility = 'shared'``

3. For all other rows:

   - ``visibility = 'private'``

REST API impact
---------------

The changes described in this document will require an API version bump.

Image discovery
~~~~~~~~~~~~~~~

If you want to list all community images, and only community images, then you
would use: ::

    GET /v2/images?visibility=community


All other appropriate filters will be respected. Of note is the use of an
``owner`` parameter. This, when supplied together with the
``visibility=community`` filter, allows a user to request only those community
images owned by that particular tenant: ::

    GET /v2/images?visibility=community&owner={owner_tenant_id}

Note that ``visiblity`` will be considered a core property of the image object,
and as such included within image lists generated via the v2 interface.


Making an image a "community image"
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

As permitted by the new policy.json rule ``communitize_images``, an admin or
owner would use the existing image-update call to change an image's visiblity
to ``'community'``: ::

    PATCH /v2/images/{image_id}

Request body: ::

    [{ "op": "replace", "path": "/visibility", "value": "community" }]

The response and other behaviour remains the same as was previously defined for
this call.


Removing community level access from an image
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

An admin or owner of an image can remove community-level access from an image
by using the image-update call. For example, instead of setting it to
``'community'`` as before, we set it to ``'private'``: ::

    PATCH /v2/images/{image_id}

Request body: ::

    [{ "op": "replace", "path": "/visibility", "value": "private" }]

An admin or user with permission to publicize an image could replace community
visibility with ``public``.

As in the above case, the response and other behaviour remains the same as
was previously defined for this call.


Security impact
---------------

See "other deployer impact".

Notifications impact
--------------------

Current notifications contain the ``is_public`` attribute, which is true if and
only if the image is a public image. This must be maintained for backwards
compatibility.

An additional attribute of ``visibility`` will be added for each image to
indicate its visiblity, with possible values of ``['public', 'private',
'shared', 'community']``.


Other end user impact
---------------------

In order to maintain consistency with how visibility is set, the current v2
image-sharing workflow will be impacted.

Currently sharing an image is simply a matter of putting a member on it. Since
this change adds an explicit ``shared`` value for visiblity, the new workflow
for image-sharing would then first require the owner or an admin to set it to
``shared`` with an image-update call: ::

    PATCH /v2/images/{image_id}

Request body: ::

    [{ "op": "replace", "path": "/visibility", "value": "shared" }]

This impact has been discussed with the API Workgroup, and they are okay with it.
(For reference, please see 16:26:47 on
eavesdrop.openstack.org/meetings/api_wg/2016/api_wg.2016-06-09-15.59.log.html)


Client changes
~~~~~~~~~~~~~~

OpenStackClient, as well as the library portion of python-glancelient, will
be updated to expose this feature. The CLI glanceclient will not be supported.

Users will be able to see all community images by using
``openstack image list --community``.

An option to ``openstack image set`` will be added named ``--visibility
<VISIBILITY_STATUS>``, where ``VISIBILTY_STATUS`` may be one of ``{public,
private, shared, community}``.

For example, to make an image a community image:

.. code:: bash

    $ openstack image set --visibility community <IMAGE>

To make the image private again:

.. code:: bash

    $ openstack image set --visibility private <IMAGE>


Performance Impact
------------------

None

Other deployer impact
---------------------

The ability to create community images is moderated using policy.json. As
mentioned above, a new rule will be created called ``communitize_image``, which
will have the default configuration of ``[role:admin or rule:owner]``.

Also users from Horizon will be able to see community images through
a separate tab. Details regarding the Horizon feature can be found at:
https://blueprints.launchpad.net/horizon/+spec/glance-community-images

Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  timothy-symanczyk


Reviewers
---------

Core reviewer(s):
  brian-rosmaita
  nikhil-komawar

Work Items
----------

- Refactor db API to use ``visibility`` rather than ``is_public``

- Add functionality for storing the community state in the interfaces to both
  db backends:

  + sqlalchemy

  + simple

- Add functionality to enable this and accept the image using the API

- Add unit tests to test various inputs to the API

- Add functional tests for the lifecycle of community images

- Update OpenStackClient to use the new API functionality

- Bump the API version


Dependencies
============

None

Testing
=======

A tempest test must be added to cover creating a community image and it
transitioning between public and private states.


Documentation Impact
====================

New features must be documented in both glance and OpenStackClient.

References
==========

* https://etherpad.openstack.org/p/newton-glance-image-sharing
* https://wiki.openstack.org/wiki/Glance-v2-community-image-sharing
* https://wiki.openstack.org/wiki/Glance-v2-community-image-sharing-faq
* https://wiki.openstack.org/wiki/Glance-v2-community-image-visibility-design
* https://wiki.openstack.org/wiki/Glance-v2-community-image-sharing-use-cases (old)
* https://wiki.openstack.org/wiki/Glance-v2-community-image-sharing-use-cases-newton (new)
* https://blueprints.launchpad.net/glance/+spec/community-level-v2-image-sharing
