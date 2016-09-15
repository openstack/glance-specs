==================================
Adding a New Virtual Machine Image
==================================

.. include:: deprecation-note.inc

We have created a new virtual machine image in some way (created a
"golden image" or snapshotted/backed up an existing image) and we wish
to do two things:

-  Store the disk image data in Glance

-  Store metadata about this image in Glance

We can do the above two activities in a single call to the Glance API.
Assuming, like in the examples above, that a Glance API server is
running at ``glance.example.com``, we issue a ``POST`` request to add an
image to Glance:

.. code::

    POST http://glance.example.com/images/

The metadata about the image is sent to Glance in HTTP headers. The body
of the HTTP request to the Glance API will be the MIME-encoded disk
image data.

Adding Image Metadata in HTTP Headers
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Glance will view as image metadata any HTTP header that it receives in a

.. code::

    ``POST`` request where the header key is prefixed with the strings
    ``x-image-meta-`` and ``x-image-meta-property-``.

The list of metadata headers that Glance accepts are listed below.

-  ``x-image-meta-name``

   This header is optional . Its value should be the name of the image.

   Note that the name of an image *is not unique to a Glance node*. It
   would be an unrealistic expectation of users to know all the unique
   names of all other user's images.

-  ``x-image-meta-id``

   This header is optional.

   When present, Glance will use the supplied identifier for the image.
   If the identifier already exists in that Glance node, then a **409
   Conflict** will be returned by Glance.

   When this header is *not* present, Glance will generate an identifier
   for the image and return this identifier in the response (see below)

-  ``x-image-meta-store``

   This header is optional. Valid values are one of ``file``, ``s3``, or
   ``swift``

   When present, Glance will attempt to store the disk image data in the
   backing store indicated by the value of the header. If the Glance
   node does not support the backing store, Glance will return a **400
   Bad Request**.

   When not present, Glance will store the disk image data in the
   backing store that is marked default. See the configuration option
   ``default_store`` for more information.

-  ``x-image-meta-disk-format``

   This header is optional. Valid values are one of ``aki``, ``ari``,
   ``ami``, ``raw``, ``iso``, ``vhd``, ``vdi``, ``qcow2``, or ``vmdk``.

   For more information, see :doc:\`About Disk and Container Formats
   <formats>\`

-  ``x-image-meta-container-format``

   This header is optional. Valid values are one of ``aki``, ``ari``,
   ``ami``, ``bare``, or ``ovf``.

   For more information, see :doc:\`About Disk and Container Formats
   <formats>\`

-  ``x-image-meta-size``

   This header is optional.

   When present, Glance assumes that the expected size of the request
   body will be the value of this header. If the length in bytes of the
   request body *does not match* the value of this header, Glance will
   return a **400 Bad Request**.

   When not present, Glance will calculate the image's size based on the
   size of the request body.

-  ``x-image-meta-checksum``

   This header is optional. When present it shall be the expected
   **MD5** checksum of the image file data.

   When present, Glance will verify the checksum generated from the
   backend store when storing your image against this value and return a
   **400 Bad Request** if the values do not match.

-  ``x-image-meta-is-public``

   This header is optional.

   When Glance finds the string "true" (case-insensitive), the image is
   marked as a public image, meaning that any user may view its metadata
   and may read the disk image from Glance.

   When not present, the image is assumed to be *not public* and
   specific to a user.

-  ``x-image-meta-owner``

   This header is optional and only meaningful for admins.

   Glance normally sets the owner of an image to be the tenant or user
   (depending on the "owner\_is\_tenant" configuration option) of the
   authenticated user issuing the request. However, if the authenticated
   user has the Admin role, this default may be overridden by setting
   this header to null or to a string identifying the owner of the
   image.

-  ``x-image-meta-property-*``

   When Glance receives any HTTP header whose key begins with the string
   prefix ``x-image-meta-property-``, Glance adds the key and value to a
   set of custom, free-form image properties stored with the image. The
   key is the lower-cased string following the prefix
   ``x-image-meta-property-`` with dashes and punctuation replaced with
   underscores.

   For example, if the following HTTP header were sent:

   .. code::

       x-image-meta-property-distro  Ubuntu 10.10

   Then a key/value pair of "distro"/"Ubuntu 10.10" will be stored with
   the image in Glance.

   There is no limit on the number of free-form key/value attributes
   that can be attached to the image. However, keep in mind that the 8K
   limit on the size of all HTTP headers sent in a request will
   effectively limit the number of image properties.

Updating an Image
~~~~~~~~~~~~~~~~~

Glance will view as image metadata any HTTP header that it receives in a

.. code::

    ``PUT`` request where the header key is prefixed with the strings
    ``x-image-meta-`` and ``x-image-meta-property-``.

If an image was previously reserved, and thus is in the ``queued``
state, then image data can be added by including it as the request body.
If the image already as data associated with it (e.g. not in the
``queued`` state), then including a request body will result in a **409
Conflict** exception.

On success, the ``PUT`` request will return the image metadata encoded
as HTTP headers.

See more about image statuses here: :doc:\`Image Statuses <statuses>\`

