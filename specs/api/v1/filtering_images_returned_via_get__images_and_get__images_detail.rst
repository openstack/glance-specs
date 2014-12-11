================================================================
Filtering Images Returned via GET /images and GET /images/detail
================================================================

Both the ``GET /images`` and ``GET         /images/detail`` requests
take query parameters that serve to filter the returned list of images.
The following list details these query parameters.

-  ``name=NAME``

   Filters images having a ``name`` attribute matching ``NAME``.

-  ``container_format=FORMAT``

   Filters images having a ``container_format`` attribute matching
   ``FORMAT``

   For more information, see :doc:\`About Disk and Container Formats
   <formats>\`

-  ``disk_format=FORMAT``

   Filters images having a ``disk_format`` attribute matching ``FORMAT``

   For more information, see :doc:\`About Disk and Container Formats
   <formats>\`

-  ``status=STATUS``

   Filters images having a ``status`` attribute matching ``STATUS``

   For more information, see :doc:\`About Image Statuses <statuses>\`

-  ``size_min=BYTES``

   Filters images having a ``size`` attribute greater than or equal to
   ``BYTES``

-  ``size_max=BYTES``

   Filters images having a ``size`` attribute less than or equal to
   ``BYTES``

These two resources also accept sort parameters:

-  ``sort_key=KEY``

   Results will be ordered by the specified image attribute ``KEY``.
   Accepted values include ``id``, ``name``, ``status``,
   ``disk_format``, ``container_format``, ``size``, ``created_at``
   (default) and ``updated_at``.

-  ``sort_dir=DIR``

   Results will be sorted in the direction ``DIR``. Accepted values are
   ``asc`` for ascending or ``desc`` (default) for descending.

