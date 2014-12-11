Image Metadata API calls
========================

The following calls allow you to create, modify, and delete image
metadata records.

Create image
------------

**POST /v2/images**

Request body must be JSON-encoded and conform to the ``image`` JSON
schema. For example:

::

    {
        "id": "e7db3b45-8db7-47ad-8109-3fb55c2c24fd",
        "name": "Ubuntu 12.10",
        "tags": ["ubuntu", "quantal"]
    }

Successful HTTP response is 201 Created with a Location header
containing the newly-created URI for the image. The response body shows
the created ``image`` entity. For example:

::

    {
        "id": "e7db3b45-8db7-47ad-8109-3fb55c2c24fd",
        "name": "Ubuntu 12.10",
        "status": "queued",
        "visibility": "public",
        "tags": ["ubuntu", "quantal"],
        "created_at": "2012-08-11T17:15:52Z",
        "updated_at": "2012-08-11T17:15:52Z",
        "self": "/v2/images/e7db3b45-8db7-47ad-8109-3fb55c2c24fd",
        "file": "/v2/images/e7db3b45-8db7-47ad-8109-3fb55c2c24fd/file",
        "schema": "/v2/schemas/image"
    }

Update an image
---------------

**PATCH /v2/images/{image\_id}**

Request body must conform to the
'application/openstack-images-v2.1-json-patch' media type, documented in
Appendix B. Using **PATCH
/v2/images/e7db3b45-8db7-47ad-8109-3fb55c2c24fd** as an example:

::

    [
        {"op": "replace", "path": "/name", "value": "Fedora 17"},
        {"op": "replace", "path": "/tags", "value": ["fedora", "beefy"]}
    ]

The response body shows the updated ``image`` entity. For example:

::

    {
        "id": "e7db3b45-8db7-47ad-8109-3fb55c2c24fd",
        "name": "Fedora 17",
        "status": "queued",
        "visibility": "public",
        "tags": ["fedora", "beefy"],
        "created_at": "2012-08-11T17:15:52Z",
        "updated_at": "2012-08-11T17:15:52Z",
        "self": "/v2/images/e7db3b45-8db7-47ad-8109-3fb55c2c24fd",
        "file": "/v2/images/e7db3b45-8db7-47ad-8109-3fb55c2c24fd/file",
        "schema": "/v2/schemas/image"
    }

The PATCH method can also be used to add or remove image properties. To
add a custom user-defined property such as "login-user" to an image, use
the following example request.

::

    [
        {"op": "add", "path": "/login-user", "value": "kvothe"}
    ]

Similarly, to remove a property such as "login-user" from an image, use
the following example request.

::

    [
        {"op": "remove", "path": "/login-user"}
    ]

See Appendix B for more details about the
'application/openstack-images-v2.1-json-patch' media type.

**Property protections**

Version 2.2 of the Images API acknowledges the ability of a cloud
provider to employ *property protections*. Thus, there may be image
properties that may not be updated or deleted by non-admin users.

Add an image tag
----------------

**PUT /v2/images/{image\_id}/tags/{tag}**

The the tag you want to add should be encoded into the request URI. For
example, to tag image e7db3b45-8db7-47ad-8109-3fb55c2c24fd with
'miracle', you would **PUT
/v2/images/e7db3b45-8db7-47ad-8109-3fb55c2c24fd/tags/miracle**. The
request body is ignored.

An image tag can be up to 255 characters in length. See the 'image'
json-schema to determine which characters are allowed.

An image can only be tagged once with a specific string. Multiple
attempts to tag an image with the same string will result in a single
instance of that string being added to the image's tags list.

An HTTP status of 204 is returned.

Delete an image tag
-------------------

**DELETE /v2/images/{image\_id}/tags/{tag}**

The tag you want to delete should be encoded into the request URI. For
example, to remove the tag 'miracle' from image
e7db3b45-8db7-47ad-8109-3fb55c2c24fd, you would **DELETE
/v2/images/e7db3b45-8db7-47ad-8109-3fb55c2c24fd/tags/miracle**. The
request body is ignored.

An HTTP status of 204 is returned. Subsequent attempts to delete the tag
will result in a 404.

List images
-----------

**GET /v2/images**

Request body ignored.

Response body will be a list of images available to the client. For
example:

::

    {
        "images": [
            {
                "id": "da3b75d9-3f4a-40e7-8a2c-bfab23927dea",
                "name": "cirros-0.3.0-x86_64-uec-ramdisk",
                "status": "active",
                "visibility": "public",
                "size": 2254249,
                "checksum": "2cec138d7dae2aa59038ef8c9aec2390",
                "tags": ["ping", "pong"],
                "created_at": "2012-08-10T19:23:50Z",
                "updated_at": "2012-08-10T19:23:50Z",
                "self": "/v2/images/da3b75d9-3f4a-40e7-8a2c-bfab23927dea",
                "file": "/v2/images/da3b75d9-3f4a-40e7-8a2c-bfab23927dea/file",
                "schema": "/v2/schemas/image"
            },
            {
                "id": "0d5bcbc7-b066-4217-83f4-7111a60a399a",
                "name": "cirros-0.3.0-x86_64-uec",
                "status": "active",
                "visibility": "public",
                "size": 25165824,
                "checksum": "2f81976cae15c16ef0010c51e3a6c163",
                "tags": [],
                "created_at": "2012-08-10T19:23:50Z",
                "updated_at": "2012-08-10T19:23:50Z",
                "self": "/v2/images/0d5bcbc7-b066-4217-83f4-7111a60a399a",
                "file": "/v2/images/0d5bcbc7-b066-4217-83f4-7111a60a399a/file",
                "schema": "/v2/schemas/image"
            },
            {
                "id": "e6421c88-b1ed-4407-8824-b57298249091",
                "name": "cirros-0.3.0-x86_64-uec-kernel",
                "status": "active",
                "visibility": "public",
                "size": 4731440,
                "checksum": "cfb203e7267a28e435dbcb05af5910a9",
                "tags": [],
                "created_at": "2012-08-10T19:23:49Z",
                "updated_at": "2012-08-10T19:23:49Z",
                "self": "/v2/images/e6421c88-b1ed-4407-8824-b57298249091",
                "file": "/v2/images/e6421c88-b1ed-4407-8824-b57298249091/file",
                "schema": "/v2/schemas/image"
            }
        ],
        "first": "/v2/images?limit=3",
        "next": "/v2/images?limit=3&marker=e6421c88-b1ed-4407-8824-b57298249091",
        "schema": "/v2/schemas/images"
    }

Get images schema
-----------------

**GET /v2/schemas/images**

Request body ignored.

The response body contains a json-schema document that shows an
``images`` entity (a container of ``image`` entities). For example:

::

    {
        "name": "images",
        "properties": {
            "images": {
                "items": {
                    "type": "array",
                    "name": "image",
                    "properties": {
                        "id": {"type": "string"},
                        "name": {"type": "string"},
                        "visibility": {"enum": ["public", "private"]},
                        "status": {"type": "string"},
                        "protected": {"type": "boolean"},
                        "tags": {
                            "type": "array",
                            "items": {"type": "string"}
                        },
                        "checksum": {"type": "string"},
                        "size": {"type": "integer"},
                        "created_at": {"type": "string"},
                        "updated_at": {"type": "string"},
                        "file": {"type": "string"},
                        "self": {"type": "string"},
                        "schema": {"type": "string"}
                    },
                    "additionalProperties": {"type": "string"},
                    "links": [
                        {"href": "{self}", "rel": "self"},
                        {"href": "{file}", "rel": "enclosure"},
                        {"href": "{schema}", "rel": "describedby"}
                    ]
                }
            },
            "schema": {"type": "string"},
            "next": {"type": "string"},
            "first": {"type": "string"}
        },
        "links": [
            {"href": "{first}", "rel": "first"},
            {"href": "{next}", "rel": "next"},
            {"href": "{schema}", "rel": "describedby"}
        ]
    }

Get image schema
----------------

**GET /v2/schemas/image**

Request body ignored.

The response body contains a json-schema document that shows an
``image``. For example:

::

    {
        "name": "image",
        "properties": {
            "id": {"type": "string"},
            "name": {"type": "string"},
            "visibility": {"enum": ["public", "private"]},
            "status": {"type": "string"},
            "protected": {"type": "boolean"},
            "tags": {
                "type": "array",
                "items": {"type": "string"}
            },
            "checksum": {"type": "string"},
            "size": {"type": "integer"},
            "created_at": {"type": "string"},
            "updated_at": {"type": "string"},
            "file": {"type": "string"},
            "self": {"type": "string"},
            "schema": {"type": "string"}
        },
        "additionalProperties": {"type": "string"},
        "links": [
            {"href": "{self}", "rel": "self"},
            {"href": "{file}", "rel": "enclosure"},
            {"href": "{schema}", "rel": "describedby"}
        ]
    }

