..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

================================
Barbican secret deletion support
================================

https://blueprints.launchpad.net/glance/+spec/barbican-secret-deletion-support

The Block Storage Service (Cinder) offers end users the ability to create
images from encrypted volume types.  When it does this, Cinder stores a secret
in Barbican in a 1-1 relation to the image and puts the Barbican ID of the
secret as an image property, ``cinder_encryption_key_id``.  When a user deletes
such an image, the Barbican secret is no longer applicable to any resource, but
it persists in Barbican.  As a result, deployers have a situation where useless
secrets are piling up in Barbican.  This would be mitigated if Glance deleted
the unique Barbican secret of an image at the time of image deletion.

Problem description
===================

Cinder would like Glance to delete a resource (the Barbican secret) that Glance
has not created.  Given that most deployments allow users to set custom image
properties, it's possible for a user to put the ``cinder_encryption_key_id``
metadata on any image, which could result in the premature deletion of an
in-use key since the 1-1 relation between Barbican secret ID and Glance image
has been broken.  Hence Glance is reluctant to implement functionality that
could result in end user data loss.

Proposed change
===============

Add the Glance common image property ``cinder_encryption_key_deletion_policy``.
At this time, ``cinder_encryption_key_id`` will also be added as a common image
property.  Since the common image properties are stored in the image_properties
table, they must have a JSON type of ``string``.  As common image properties,
they will be added to the default **schema-image.json** file as follows::

  {
      "cinder_encryption_key_id": {
         "description": "Identifier in the OpenStack Key Management Service for the encryption key for the Block Storage Service to use when mounting a volume created from this image",
         "type": "string"
      },
      "cinder_encryption_key_deletion_policy": {
          "description": "States the condition under which the Image Service will delete the object associated with the 'cinder_encryption_key_id' image property.  If this property is missing, the Image Service will take no action",
          "type": "string",
          "enum": [
              "on_image_deletion",
              "do_not_delete"
          ]
      }
  }

.. note::
   Note: The common image properties are interoperability suggestions but are
   not mandatory features of Glance.  As such, there is no guarantee that a
   particular Glance installation will allow them to be listed in the
   image-schema response.  Thus, we cannot rely on schema-validation of the
   value for this property.  Note that this does not affect Cinder writing
   these properties to images (as long as the Glance configuration option
   ``allow_additional_image_properties`` is True, which is its default value).

.. note::
   We should seriously consider deprecating the
   ``allow_additional_image_properties`` configuration option during this
   cycle.  I believe it was originally introduced to prevent users from
   flooding the image_properties table with junk and it predated the
   ``image_property_quota`` option.  Now that we have the latter option, it's
   really unnecessary, and if an operator were to set it False, all sorts of
   stuff would break as multiple OpenStack services currently write/rely on
   custom image properties.

.. note::
   There's a bug someone asked me about in IRC once (I can't find it in
   Launchpad, it may not have been filed) that an operator can modify
   /etc/schema-image.json to include arbitrary properties (which was that
   file's original purpose) and assign them JSON types other than 'string'.
   The type is enforced by image create/update but you get a 500 because it has
   to be a string in the database (but the API won't accept a string if the
   schema says it's boolean or something).  We should document that these
   things *must* be strings.

The presence of this property with the appropriate value gives Glance explicit
permission to delete the key, even though Glance has not created it.  When this
property is present on an image with the value 'on_image_deletion', Glance will
search the image's properties for the property ``cinder_encryption_key_id``.
If it exists, Glance will make a request to Barbican to delete the secret whose
ID is the value of the image property.

Because ``cinder_encryption_key_deletion_policy`` is a custom image property,
it can be added/deleted/updated by the image owner.  Hence, if the image owner
has a reason to preserve a key, permission to delete can be revoked by changing
the value to 'do_not_delete' or by simply deleting the
``cinder_encryption_key_deletion_policy`` property.

Error conditions:

* If ``cinder_encryption_key_id`` is not present on the image, image deletion
  will not be affected by the presence of
  ``delete_encryption_key_on_image_deletion: on_image_deletion``.

* If ``cinder_encryption_key_id`` indicates a nonexistent Barbican ID, this
  should be logged, but will not affect image deletion.

* If ``cinder_encryption_key_deletion_policy`` has a value other than
  ``on_image_deletion`` or ``do_not_delete``, Glance will do the following:

  * take no action with respect to the ``cinder_encryption_key_id``
  * delete the image

Alternatives
------------

1. Do nothing and leave it up to the end user to explicitly delete the secret
   from Barbican.  This is problematic for the Cinder workflow, which has kept
   secret management hidden from the user, hence the user may not be aware
   until sometime after the image has been deleted (and its metadata gone) that
   the Barbican secret can be deleted, and the secret ID is no longer
   available.  Since it's impossible to know for any secret whether anything
   might be holding a reference to it, the user can't simply go to Barbican and
   determine what secrets are no longer in use.  So this is not a really a
   viable alternative.

2. Leave the ``cinder_encryption_key_id`` as the only metadatum, and have
   its presence be sufficient for Glance to delete the secret upon image
   deletion.  This has the drawback that an end user who's using the Cinder
   feature in a nonstandard way has no way to prevent Glance from deleting
   a Barbican secret that may still be in use.

3. Do not make ``cinder_encryption_key_deletion_policy`` a common image
   property, but instead let it be a regular custom image property, similar
   to the custom image properties that are recognized by the Nova scheduler.
   Because of the data loss possibility posed by automatic secret deletion,
   it would be better to have its function clearly documented in the image
   schema, rather than leaving this to documentation only.

4. Make ``cinder_encryption_key_deletion_policy`` a boolean instead of an
   enumerated string type.  Unfortunately, it cannot actually be a boolean
   type because it must be stored as a string, which is confusing for tooling
   developers because its value would be ``"true"``, not the JSON ``true``
   value.  Additionally, an image-show response containing::

     cinder_encryption_key_deletion_policy: on_image_deletion

   is self-documenting with respect to what this image property means.

Data model impact
-----------------

None.  A common image property appears in the image schema, but is stored in
the image_properties table with the custom image properties.

REST API impact
---------------

None.

Security impact
---------------

No impact on the security of Glance.  This arguably makes the Cinder-Glance
volume-to-image functionality more secure.  It no longer leaves a user in
the position of having to clear out a bunch of excess secrets from Barbican,
one of which may actually be in use.  Additionally, it doesn't require a
user to manually delete a key (the user might delete the wrong one).

Notifications impact
--------------------

None.

Other end user impact
---------------------

The Cinder workflow is designed to hide key handling from the user; this
is consistent with that design.

Performance Impact
------------------

Glance will need to make a call to Barbican as part of the image delete
process.

Other deployer impact
---------------------

This will be a bonus to deployers who will no longer have to worry about
useless Barbican secrets piling up.

Developer impact
----------------

None.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  brian-rosmaita or abhishek-kekane

Work Items
----------

1. Modify the image schema to include the new common image property and
   to make the current property Cinder uses, ``cinder_encryption_key_id``,
   an official common image property.

2. Implement the code to delete the secret in Barbican upon image deletion.

Dependencies
============

None.

Testing
=======

Since the scenario we're interested in is whether Glance can delete a secret
from Barbican under certain conditions, a tempest test could be implemented
that creates a secret, puts the appropriate metadata on an image, deletes the
image and verifies that the Barbican secret is/is not deleted.

If there's an existing tempest test that actually creates an image of an
encrypted volume in Glance, then we could piggyback on that to verify that key
deletion occurs.  This, of course, would have to wait until Cinder has
implemented putting the new ``cinder_encryption_key_deletion_policy`` flag on
images created from encrypted volumes.

Documentation Impact
====================

Document the new properties along with the rest of the common image properties.

References
==========

* Train PTG discussion: https://etherpad.openstack.org/p/cinder-train-ptg-planning
