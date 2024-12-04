Sharing Images using the Image API v2
=====================================

The OpenStack Image Service API v2 allows users to share images with
each other in the following ways:

* An image can be shared with specific other users of the cloud.  This mode of
  sharing has been available since version 2.1 of the API.  Thus when we speak
  about "shared" images in this document, we're talking about this kind of
  sharing.  It's described in the section :ref:`one-one-sharing`, below.

* An image can be shared with all users of the cloud.  This mode of sharing
  became available in version 2.5 of the API.  Images shared in this way are
  referred to as "community" images because they're available to the entire
  community of users in a cloud (and because we couldn't think of a better
  name).  Community images are discussed below in the section
  :ref:`one-all-sharing`.

To keep the discussion to follow clear, here's some terminology that will be
used.

producer
  A user who owns an image that's going to be shared with other users.

consumer
  A user who wants to use an image.

shared image
  An image that's been made accessible to specific other users, as described in
  :ref:`one-one-sharing`.  Since version 2.5 of the API, the ``visibility``
  property of such an image is ``shared``.  (If you are using a prior version
  of the API, the ``visibility`` is ``private``.)

community image
  An image that's been made accessible to all users in a cloud, as described in
  :ref:`one-all-sharing`.  Since version 2.5 of the API, the ``visibility``
  property of such an image is ``community``.  (This type of image is not
  available prior to version 2.5.)

.. _one-one-sharing:

Sharing Images with Particular Users
------------------------------------

Let the "producer" be the owner of image 71c675ab-d94f-49cd-a114-e12490b328d9,
and let the "consumer" be a user who would like to boot an instance from that
image.

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

.. _owner_is_tenant:

How do you identify a producer or consumer?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

As an image producer, you know who you are, but how do you identify a potential
consumer of your image?  As an image consumer, how do you refer to yourself,
and if you want to consume community images, what do you use to identify the
producer of an image you're looking for?  These are actually complicated
questions, because Glance allows an operator to decide whether images will be
owned by *projects* or whether they will be owned by *users*.  The default is
that images are owned by *projects*, so that's what you'll see most often.

.. note::
   Sometimes you'll see a *project* referred to as a *tenant*.  A "tenant"
   was the original OpenStack term for a project.  It's been phased out
   because the word "tenant" in English is often used to refer to a person,
   and this makes it easy to confuse a tenant with an *owner*.  But when
   documentation or members of the OpenStack community refer to a "tenant"
   or "tenant ID", they really mean "project" or "project ID".

* In clouds where an image owner is a *project*, the way to identify an image
  producer or consumer is to use their **project ID**.

  - In such a cloud, images are shared project-to-project.  Thus *all* users
    within the consuming project will have access to the image.  In such a
    cloud, there is no way to share an image with only a single user.

* In clouds where an image owner is a *user*, an image producer or consumer is
  identified by their **user ID**.

  - In such a cloud, images are shared user-to-user.  Thus only the specific
    users who are image members have access to the image.  This extends to
    other users in the same project as the user owning the image.  Even though
    they are in the same project, they must explictly be made members in order
    to have access to the image.

Note that image producers or consumers do *not* get to decide which identifier
to use.  This is decided for the entire cloud by the cloud administrator.
Consult your cloud's local documentation to find out which applies in a
particular cloud you're using.  (As mentioned above, the default is that images
are owned by *projects*, so if the local documentation doesn't say anything,
it's a good bet that the default is being used.)

Producer-Consumer Communication
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

No provision is made in this API for producer-consumer communication.
All such communication must be done independently of the API.

An example workflow for shared images is:

1. The producer posts the availability of specific images on a public
   website.
2. A potential consumer provides the producer with his/her appropriate
   identifier and email address.  (See :ref:`owner_is_tenant` if you're
   not sure what the appropriate identifier is.)
3. The producer uses the Images v2 API to share the image with the
   consumer.
4. The producer notifies the consumer via email that the image has been
   shared and what its UUID is.
5. If the consumer wishes the shared image to appear in his/her image list, the
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

There is no request body.

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
                "description": "An identifier for the image member",
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

There is no request body.

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
                            "description": "An identifier for the image member",
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

.. include:: shared-viz-note.inc

Create an Image Member
^^^^^^^^^^^^^^^^^^^^^^

**POST /v2/images/<IMAGE\_ID>/members**

The request body must be JSON in the following format:

::

    {
        "member": "<MEMBER_ID>"
    }

where the MEMBER\_ID is the ID of the consumer with whom the image is to
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

There is no request body.

A successful response is 204 (No Content).

The call returns HTTP status code 404 if MEMBER\_ID is not an image
member of the specified image.

The call returns HTTP status code 404 if the user making the call is not
the image owner.

Image Consumer Calls
~~~~~~~~~~~~~~~~~~~~

The following calls pertain to a user who wishes to act as a consumer of
shared images.

.. include:: shared-viz-note.inc

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
identifier does not match the MEMBER\_ID, the response is HTTP status
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

.. include:: shared-viz-note.inc

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

The image owner (the producer) may make this call successfully for each image
member. An image member (a consumer) may make this call successfully only when
MEMBER\_ID is the correct identifier for that consumer. For any other
MEMBER\_ID, the consumer receives a 404 response.

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
example, if the call is made by consumer 8989447062e04a818baf9e073fd04fa7,
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

If the call is made by a consumer with whom the image is *not* shared, the
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
-  ``owner=<OWNER_ID>``: show only images shared with me by the producer
   whose identifier is OWNER\_ID

.. _one-all-sharing:

Sharing Images with All Users
-----------------------------

Since version 2.5, the Image Service API v2 offers another kind of image
sharing, *Community Images*.  A community image is made available to all
users in a cloud without the requirement of creating members on the image.

A community image is an image whose ``visibility`` value is ``community``.  The
ability to communitize an image may be prohibited or restricted to specific
users at the discretion of the cloud operator.  To make an image a community
image, use the image update call to change the image's visibility
appropriately.  (See :ref:`image-update` for more information.)

Community images do not appear in the default image list of any user other
than the image owner.  In order to discover community images, make the
image-list call with a 'visibility' filter:

``GET v2/images?visibility=community``

As with the standard image-list call, other filters may be applied to the
request.  For example, to see the community images supplied by the image
producer identified by ``931efe8a-0ad7-4610-9116-c199f8807cda``, the
following call would be made:

``GET v2/images?visibility=community&owner=931efe8a-0ad7-4610-9116-c199f8807cda``

.. note::
   See :ref:`owner_is_tenant` for information about how to determine
   an image producer's identifier.

Keep in mind that the ``name`` property of an image is not required to be
unique, so filtering by name may result in multiple matches.  For example,
there may be multiple image producers promoting something named "Fred's
Excellent OS", and thus the following call (remembering to URL encode the
apostrophe and spaces):

``GET v2/images?visibility=community&name=Fred%27s%20Excellent%20OS``

may result in several image records for different image producers.  If you
want to find only images supplied by some particular producer, filtering by
``owner`` will give you more accurate results.  Additionally, if "Fred's
Excellent OS" image is ever deleted by Fred, who you trust, some other
producer George, who you don't even know, could create a "Fred's Excellent OS"
image.  If you are searching by name only, you'll find George's image---which
you probably don't want to use until you've figured out who George is, whether
he's trustworthy, and what exactly he's put on the image.

No provision is made in this API for producer-consumer communication.
All such communication must be done independently of the API.

An example workflow for community images is:

1. The producer posts information about community images on a public website.
   This information would be a description of the image including the image's
   UUID.

2. A consumer uses the UUID in Images v2 API calls to access the image.

An alternative workflow is:

1. The producer posts information about community images on a public website.
   This post would include the producer's identifier.

2. A potential consumer uses the producer's identifier in an image-list
   call as in the example above to discover the available images and to
   determine the UUID of an image to be consumed.

3. The consumer uses the UUID in Images v2 API calls to access the image.
