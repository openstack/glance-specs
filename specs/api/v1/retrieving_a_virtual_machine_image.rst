==================================
Retrieving a Virtual Machine Image
==================================

.. include:: deprecation-note.inc

We want to retrieve that actual raw data for a specific virtual machine
image that the Glance server knows about.

We have queried the Glance server for a list of public images and the
data returned includes the \`uri\` field for each available image. This
\`uri\` field value contains the exact location needed to get the
metadata for a specific image.

Continuing the example from above, in order to get metadata about the
first public image returned, we can issue a ``HEAD`` request to the
Glance server for the image's URI.

We issue a ``GET`` request to ``http://glance.openstack.example.org/images/1``
to retrieve metadata for that image as well as the image itself encoded
into the response body.

The metadata is returned as a set of HTTP headers that begin with the
prefix ``x-image-meta-``. The following shows an example of the HTTP
headers returned from the above ``GET`` request:

.. code::

    x-image-meta-name             Ubuntu 10.04 Plain 5GB
    x-image-meta-disk-format      vhd
    x-image-meta-container-format ovf
    x-image-meta-size             5368709120
    x-image-meta-checksum         c2e5db72bd7fd153f53ede5da5a06de3
    x-image-meta-location         swift://account:key/container/image.tar.gz.0
    x-image-meta-created_at       2010-02-03 09:34:01
    x-image-meta-updated_at       2010-02-03 09:34:01
    x-image-meta-deleted_at
    x-image-meta-status           available
    x-image-meta-is-public        true
    x-image-meta-owner            null
    x-image-meta-property-distro  Ubuntu 10.04 LTS

.. code::

    All timestamps returned are in UTC

    The `x-image-meta-updated_at` timestamp is the timestamp when an
    image's metadata was last updated, not its image data, as all
    image data is immutable once stored in Glance

    There may be multiple headers that begin with the prefix
    `x-image-meta-property-`.  These headers are free-form key/value pairs
    that have been saved with the image metadata. The key is the string
    after `x-image-meta-property-` and the value is the value of the header

    The response's `Content-Length` header shall be equal to the value of
    the `x-image-meta-size` header

    The response's `ETag` header will always be equal to the
    `x-image-meta-checksum` value

    The response's `x-image-meta-is-public` value is a boolean indicating
    whether the image is publicly available

    The response's `x-image-meta-owner` value is a string which may either
    be null or which will indicate the owner of the image

    The image data itself will be the body of the HTTP response returned
    from the request, which will have content-type of
    `application/octet-stream`.

