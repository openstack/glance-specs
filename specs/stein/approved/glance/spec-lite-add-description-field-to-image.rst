..
   This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=========================================
Spec Lite: Add description field to image
=========================================

:project: glance

:problem: Currently there is not a dedicated image property to record the
          description of an image. In most of our customer environments,
          users typically upload multiple images. Because of the large
          number of users, it is difficult to distinguish the purpose of
          an image through the ``name`` field (possibly with duplicate names).

          For example: Nova and Cinder have the ``description`` field,
          and the ``description`` field allows you to record the specific
          purpose of the object.

:solution: Add ``description`` field as a "common image property" to image.
           This way it will appear in the image schema (good for
           interoperability purposes) but will be stored as a user-defined
           image property (so will not require any database changes).
           You can set ``--property`` to add ``description`` properties when
           executing the CLI.

           This is an exception to the Glance policy that new image properties
           should be prefixed with ``os_``. It's not necessary for this spec
           for the following reasons.

           * Under this proposal, ``description`` will be stored as a user
             specified ("custom") image property in the ``image_properties``
             database table.  Because it is not stored as a new column in
             the ``images`` table, it will not block the display of any
             ``description`` property on currently existing images.

           * It's to be expected that a property named ``description`` will
             in fact contain some kind of description of the image it's a
             property of.  Thus we do not expect that there will be an
             inconsistency between any existing ``description`` image
             properties and the description of ``description`` that will
             appear in the image schema.

           * Using the name ``description`` is consistent with the other
             services (for example, Nova and Cinder) that recognize
             description metadata on resources.

           CLI execution example::

             $ openstack image create \
                 --property description='This is a test image file.' \
                 --file cirros-0.3.4-x86_64-disk.img \
                 --disk-format qcow2 \
                 --container-format bare \
                 test_image

:alternatives: Do nothing, given that users can already create such a property.
               This alternative, however, has the disadvantage that it does not
               provide a guideline for local practices to conform with, which
               in turn makes interoperability problematic.

:timeline: Include in Stein release.

:link: https://review.openstack.org/620433

:reviewers: Brian Rosmaita

:assignee: Brin Zhang
