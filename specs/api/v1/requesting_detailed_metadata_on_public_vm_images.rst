================================================
Requesting Detailed Metadata on Public VM Images
================================================

We want to see more detailed information on available virtual machine
images that the Glance server knows about.

We issue a ``GET`` request to
``http://glance.example.com/images/detail`` to retrieve this list of
available *public* images. The data is returned as a JSON-encoded
mapping in the following format:

.. code::

    {'images': [
      {'name': 'Ubuntu 10.04 Plain 5GB',
       'disk_format': 'vhd',
       'container_format': 'ovf',
       'size': '5368709120',
       'checksum': 'c2e5db72bd7fd153f53ede5da5a06de3',
       'location': 'swift://account:key/container/image.tar.gz.0',
       'created_at': '2010-02-03 09:34:01',
       'updated_at': '2010-02-03 09:34:01',
       'deleted_at': '',
       'status': 'active',
       'is_public': true,
       'owner': null,
       'properties': {'distro': 'Ubuntu 10.04 LTS'}},
      ...]}

.. code::

    All images returned from the above `GET` request are public images

    All timestamps returned are in UTC

    The `updated_at` timestamp is the timestamp when an image's metadata
    was last updated, not its image data, as all image data is immutable
    once stored in Glance

    The `properties` field is a mapping of free-form key/value pairs that
    have been saved with the image metadata

    The `checksum` field is an MD5 checksum of the image file data

    The `is_public` field is a boolean indicating whether the image is
    publicly available

    The `owner` field is a string which may either be null or which will
    indicate the owner of the image

