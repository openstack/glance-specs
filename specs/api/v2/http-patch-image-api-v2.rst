Image API v2 HTTP PATCH media types
===================================

Overview
--------

The HTTP PATCH request must provide a media type for the server to
determine how the patch should be applied to an image resource. An
unsupported media type will result in an HTTP error response with the
415 status code. For image resources, two media types are supported:

-  ``application/openstack-images-v2.1-json-patch``
-  ``application/openstack-images-v2.0-json-patch``

The ``application/openstack-images-v2.1-json-patch`` media type is
intended to provide a useful and compatible subset of the functionality
defined in JavaScript Object Notation (JSON) Patch
`RFC6902 <http://tools.ietf.org/html/rfc6902>`__, which defines the
``application/json-patch+json`` media type.

The ``application/openstack-images-v2.0-json-patch`` media type is based
on `draft
4 <http://tools.ietf.org/html/draft-ietf-appsawg-json-patch-04>`__ of
the standard. Its use is deprecated.

Restricted JSON pointers
------------------------

The 'application/openstack-images-v2.1-json-patch' media type defined in
this appendix adopts a restricted form of
`JSON-Pointers <http://tools.ietf.org/html/draft-pbryan-zyp-json-pointer>`__.
A restricted JSON pointer is a
`Unicode <http://tools.ietf.org/html/draft-ietf-appsawg-json-pointer-03#ref-Unicode>`__
string containing a sequence of exactly one reference token, prefixed by
a '/' (%x2F) character.

If a reference token contains '~' (%x7E) or '/' (%x2F) characters, they
must be encoded as '~0' and '~1' respectively.

Its ABNF syntax is:

::

    restricted-json-pointer = "/" reference-token
    reference-token = *( unescaped / escaped )
    unescaped = %x00-2E / %x30-7D / %x7F-10FFFF
    escaped = "~" ( "0" / "1" )

Restricted JSON Pointers are evaluated as ordinary JSON pointers per
`JSON-Pointer <http://tools.ietf.org/html/draft-pbryan-zyp-json-pointer>`__.

For example, given the ``image`` entity:

::

    {
        "id": "da3b75d9-3f4a-40e7-8a2c-bfab23927dea",
        "name": "cirros-0.3.0-x86_64-uec-ramdisk",
        "status": "active",
        "visibility": "public",
        "size": 2254249,
        "checksum": "2cec138d7dae2aa59038ef8c9aec2390",
        "~/.ssh/": "present",
        "tags": ["ping", "pong"],
        "created_at": "2012-08-10T19:23:50Z",
        "updated_at": "2012-08-10T19:23:50Z",
        "self": "/v2/images/da3b75d9-3f4a-40e7-8a2c-bfab23927dea",
        "file": "/v2/images/da3b75d9-3f4a-40e7-8a2c-bfab23927dea/file",
        "schema": "/v2/schemas/image"
    }

The following restricted JSON pointers evaluate to the accompanying
values:

::

    "/name"        "cirros-0.3.0-x86_64-uec-ramdisk"
    "/size"        2254249
    "/tags"        ["ping", "pong"]
    "/~0~1.ssh~1"  "present"

Operations
----------

The application/openstack-images-v2.1-json-patch media type supports a
subset of the operations defined in the application/json-patch+json
media type. Specify the operation in the "op" member of the request
object.

-  The supported operations are add, remove, and replace.
-  If an operation object contains no recognized operation member, an
   error occurs.

Specify the location where the requested operation is to be performed in
the target image in the "path" member of the operation object.

-  The member value is a string containing a restricted JSON-pointer
   value that references the location where the operation is to be
   performed within the target image.

Where appropriate (that is, for the "add" and "replace" operations), the
operation object must contain the "value" data member.

-  The member value is the actual value to add (or to use in the replace
   operation) expressed in JSON notation. (For example, strings must be
   quoted, numeric values are unquoted.)

The payload for a PATCH request must be a *list* of JSON objects. Each
object must adhere to one of the following formats.

-  add

The add operation adds a new value at a specified location in the target
image. The location must reference an image property to add to an
existing image.

The operation object specifies a "value" member and associated value.

Example:

::

    PATCH /images/{image_id}

    [
       {
          "op":"add",
          "path":"/login-name",
          "value":"kvothe"
       }
    ]

You can also use the add operation to add a location to the set of
locations that are associated with a specified image ID, as follows:

Example:

::

    PATCH /images/{image_id}

    [
       {
          "op":"add",
          "path":"/locations/1",
          "value":"scheme4://path4"
       }
    ]

-  remove

The remove operation removes the specified image property in the target
image. If an image property does not exist at the specified location, an
error occurs.

Example:

::

    PATCH /images/{image_id}

    [
       {
          "op":"remove",
          "path":"/login-name"
       }
    ]

You can also use the remove operation to remove a location from a set of
locations that are associated with a specified image ID, as follows:

Example:

::

    PATCH /images/{image_id}

    [
       {
         "op":"remove",
         "path":"/locations/2"
       }
    ]

-  replace

The replace operation replaces the value of a specified image property
in the target image with a new value. The operation object contains a
"value" member that specifies the replacement value.

Example:

::

    [
       {
          "op":"replace",
          "path":"/login-name",
          "value":"kote"
       }
    ]

This operation is functionally identical to expressing a "remove"
operation for an image property, followed immediately by an "add"
operation at the same location with the replacement value.

If the specified image property does not exist for the target image, an
error occurs.

You can also use the replace operation to replace a location in the set
of locations that are associated with a specified image ID, as follows:

Example:

::

    PATCH /images/{image_id}

    [
       {
          "op":"replace",
          "path":"/locations",
          "value":[
             "scheme5://path5",
            "scheme6://path6"
          ]
      }
    ]
