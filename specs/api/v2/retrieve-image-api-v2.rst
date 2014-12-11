Get an Image
------------

**GET /v2/images/<IMAGE\_ID>**

Request body ignored.

Response body is a single image entity. Using **GET
/v2/image/da3b75d9-3f4a-40e7-8a2c-bfab23927dea** as an example:

::

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
    }

**Property Protections**

Version 2.2 of the Images API acknowledges the ability of a cloud
provider to employ *property protections*. Thus, there may be some image
properties that will not appear in the image detail response for
non-admin users.

