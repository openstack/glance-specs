Image API v2 Sharing
--------------------

The OpenStack Image Service API v2 allows users to share images with
each other.

Let the "producer" be a tenant who owns image
71c675ab-d94f-49cd-a114-e12490b328d9, and let the "consumer" be a tenant
who would like to boot an instance from that image.

The producer can share the image with the consumer by making the
consumer a **member** of that image.

To prevent spamming, the consumer must **accept** the image before it
will be included in the consumer's image list.

The consumer can still boot from the image, however, if the consumer
knows the image ID.

In summary:

-  The image producer may add or remove image members, but may not
   modify the member status of an image member.
-  An image consumer may change his or her member status, but may not
   add or remove him or herself as an image member.
-  A consumer may boot an instance from a shared image regardless of
   whether he/she has "accepted" the image.

Producer-Consumer Communication
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

No provision is made in this API for producer-consumer communication.
All such communication must be done independently of the API.

An example workflow is:

1. The producer posts the availability of specific images on a public
   website.
2. A potential consumer provides the producer with his/her tenant ID and
   email address.
3. The producer uses the Images v2 API to share the image with the
   consumer.
4. The producer notifies the consumer via email that the image has been
   shared and what its UUID is.
5. If the consumer wishes the image to appear in his/her image list, the
   Images v2 API is used to change the image status to ``accepted``.
6. If the consumer subsequently wishes to hide the image, the Images v2
   API may be used to change the member status to ``rejected``. If the
   consumer wishes to hide the image, but is open to the possibility of
   being reminded by the producer that the image is available, the
   Images v2 API may be used to change the member status to ``pending``.

Note that as far as this API is concerned, the member status has only
two effects:

-  If the member status is *not* ``accepted``, the image will not appear
   in the consumer's default image list.
-  The consumer's image list may be filtered by status to see shared
   images in the various member statuses. For example, the consumer can
   discover images that have been shared with him or her by filtering on
   ``visibility=shared&member_status=pending``.

Image Sharing Schemas
~~~~~~~~~~~~~~~~~~~~~

JSON schema documents are provided at the URIs listed below.

Recall that the schemas contained in this document are only examples and
should not be used to validate your requests.

Get Image Member Schema
^^^^^^^^^^^^^^^^^^^^^^^

**GET /v2/schemas/member**

Request body ignored.

Response body contains a json-schema document representing an image
``member`` entity.

The response from the API should be considered authoritative. The schema
is reproduced here solely for your convenience:

::

    {
        "name": "member",
        "properties": {
            "created_at": {
                "description": "Date and time of image member creation",
                "type": "string"
            },
            "image_id": {
                "description": "An identifier for the image",
                "pattern": "^([0-9a-fA-F]){8}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){12}$",
                "type": "string"
            },
            "member_id": {
                "description": "An identifier for the image member (tenantId)",
                "type": "string"
            },
            "status": {
                "description": "The status of this image member",
                "enum": [
                    "pending",
                    "accepted",
                    "rejected"
                ],
                "type": "string"
            },
            "updated_at": {
                "description": "Date and time of last modification of image member",
                "type": "string"
            },
            "schema": {
                "type": "string"
            }
        }
    }

Get Image Members Schema
^^^^^^^^^^^^^^^^^^^^^^^^

**GET /v2/schemas/members**

Request body ignored.

Response body contains a json-schema document representing an image
``members`` entity (a container of ``member`` entities).

The response from the API should be considered authoritative. The schema
is reproduced here solely for your convenience:

::

    {
        "name": "members",
        "properties": {
            "members": {
                "items": {
                    "name": "member",
                    "properties": {
                        "created_at": {
                            "description": "Date and time of image member creation",
                            "type": "string"
                        },
                        "image_id": {
                            "description": "An identifier for the image",
                            "pattern": "^([0-9a-fA-F]){8}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){12}$",
                            "type": "string"
                        },
                        "member_id": {
                            "description": "An identifier for the image member (tenantId)",
                            "type": "string"
                        },
                        "status": {
                            "description": "The status of this image member",
                            "enum": [
                                "pending",
                                "accepted",
                                "rejected"
                            ],
                            "type": "string"
                        },
                        "updated_at": {
                            "description": "Date and time of last modification of image member",
                            "type": "string"
                        },
                        "schema": {
                            "type": "string"
                        }
                    }
                },
                "type": "array"
            },
            "schema": {
                "type": "string"
            }
        },
        "links": [
            {
                "href": "{schema}",
                "rel": "describedby"
            }
        ]
    }

Image Producer Calls
~~~~~~~~~~~~~~~~~~~~

The following calls are germane to a user who wishes to act as a
producer of shared images.

Create an Image Member
^^^^^^^^^^^^^^^^^^^^^^

**POST /v2/images/<IMAGE\_ID>/members**

The request body must be JSON in the following format:

::

    {
        "member": "<MEMBER_ID>"
    }

where the MEMBER\_ID is the ID of the tenant with whom the image is to
be shared.

The member status of a newly created image member is ``pending``.

If the user making the call is not the image owner, the response is HTTP
status code 404.

The response conforms to the JSON schema available at
**/v2/schemas/member**, for example,

::

    {
        "created_at": "2013-09-19T20:36:53Z",
        "image_id": "71c675ab-d94f-49cd-a114-e12490b328d9",
        "member_id": "8989447062e04a818baf9e073fd04fa7",
        "schema": "/v2/schemas/member",
        "status": "pending",
        "updated_at": "2013-09-19T20:36:53Z"
    }

Delete an Image Member
^^^^^^^^^^^^^^^^^^^^^^

**DELETE /v2/images/<IMAGE\_ID>/members/<MEMBER\_ID>**

A successful response is 204 (No Content).

The call returns HTTP status code 404 if MEMBER\_ID is not an image
member of the specified image.

The call returns HTTP status code 404 if the user making the call is not
the image owner.

Image Consumer Calls
~~~~~~~~~~~~~~~~~~~~

The following calls pertain to a user who wishes to act as a consumer of
shared images.

Update an Image Member
^^^^^^^^^^^^^^^^^^^^^^

**PUT /v2/images/<IMAGE\_ID>/members/<MEMBER\_ID>**

The body of the request is a JSON object specifying the member status to
which the image member should be updated:

::

    {
        "status": "<STATUS_VALUE>"
    }

where STATUS\_VALUE is one of { ``pending``, ``accepted``, or
``rejected`` }.

The response conforms to the JSON schema available at
**/v2/schemas/member**, for example,

::

    {
        "created_at": "2013-09-20T19:22:19Z",
        "image_id": "a96be11e-8536-4910-92cb-de50aa19dfe6",
        "member_id": "8989447062e04a818baf9e073fd04fa7",
        "schema": "/v2/schemas/member",
        "status": "accepted",
        "updated_at": "2013-09-20T20:15:31Z"
    }

If the call is made by the image owner, the response is HTTP status code
403 (Forbidden).

If the call is made by a user who is not the image owner and whose
tenant ID does not match the MEMBER\_ID, the response is HTTP status
code 404.

Image Member Status Values
^^^^^^^^^^^^^^^^^^^^^^^^^^

There are three image member status values:

-  ``pending``: When a member is created, its status is set to
   ``pending``. The image is not visible in the member's image-list, but
   the member can still boot instances from the image.
-  ``accepted``: When a member's status is ``accepted``, the image is
   visible in the member's image-list. The member can boot instances
   from the image.
-  ``rejected``: When a member's status is ``rejected``, the member has
   decided that he or she does not wish to see the image. The image is
   not visible in the member's image-list, but the member can still boot
   instances from the image.

Calls for Both Producers and Consumers
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

These calls are applicable to users acting either as producers or
consumers of shared images.

Show Image Member
^^^^^^^^^^^^^^^^^

**GET /v2/images/<IMAGE\_ID>/members/<MEMBER\_ID>**

The response conforms to the JSON schema available at
**/v2/schemas/member**, for example,

::

    {
        "created_at": "2014-02-20T04:15:17Z",
        "image_id": "634985e5-0f2e-488e-bd7c-928d9a8ea82a",
        "member_id": "46a12bfd09c8459483c03e1b0d71bda8",
        "schema": "/v2/schemas/member",
        "status": "pending",
        "updated_at": "2014-02-20T04:15:17Z"
    }

The image owner (the producer) may make this call successfully for each
image member. An image member (a consumer) may make this call
successfully only when MEMBER\_ID matches that consumer's tenant ID. For
any other MEMBER\_ID, the consumer receives a 404 response.

List Image Members
^^^^^^^^^^^^^^^^^^

**GET /v2/images/<IMAGE\_ID>/members**

The response conforms to the JSON schema available at
**/v2/schemas/members**, for example,

::

    {
        "members": [
            {
                "created_at": "2013-09-20T19:16:53Z",
                "image_id": "a96be11e-8536-4910-92cb-de50aa19dfe6",
                "member_id": "818baf9e073fd04fa78989447062e04a",
                "schema": "/v2/schemas/member",
                "status": "pending",
                "updated_at": "2013-09-20T19:16:53Z"
            },
            {
                "created_at": "2013-09-20T19:22:19Z",
                "image_id": "a96be11e-8536-4910-92cb-de50aa19dfe6",
                "member_id": "8989447062e04a818baf9e073fd04fa7",
                "schema": "/v2/schemas/member",
                "status": "pending",
                "updated_at": "2013-09-20T19:22:19Z"
            }
        ],
        "schema": "/v2/schemas/members"
    }

If the call is made by a user with whom the image has been shared, the
member-list will contain *only* the information for that user. For
example, if the call is made by tenant 8989447062e04a818baf9e073fd04fa7,
the response is:

::

    {
        "members": [
            {
                "created_at": "2013-09-20T19:22:19Z",
                "image_id": "a96be11e-8536-4910-92cb-de50aa19dfe6",
                "member_id": "8989447062e04a818baf9e073fd04fa7",
                "schema": "/v2/schemas/member",
                "status": "pending",
                "updated_at": "2013-09-20T19:22:19Z"
            }
        ],
        "schema": "/v2/schemas/members"
    }

If the call is made by a user with whom the image is *not* shared, the
response is a 404.

List Shared Images
^^^^^^^^^^^^^^^^^^

Shared images are listed as part of the normal image list call. In this
section we emphasize some useful filtering options.

-  ``visibility=shared``: show only images shared with me where my
   member status is 'accepted'
-  ``visibility=shared&member_status=accepted``: same as above
-  ``visibility=shared&member_status=pending``: show only images shared
   with me where my member status is 'pending'
-  ``visibility=shared&member_status=rejected``: show only images shared
   with me where my member status is 'rejected'
-  ``visibility=shared&member_status=all``: show all images shared with
   me regardless of my member status
-  ``owner=<OWNER_ID>``: show only images shared with me by the user
   whose tenant ID is OWNER\_ID
