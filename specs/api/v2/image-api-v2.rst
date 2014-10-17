General Image API v2.x information
==================================

The Image Service API v2 enables you to store and retrieve disk and
server images.

Versioning
----------

**Two-part versioning scheme**

The Image Service API v2 mimics API v1 and uses a major version and a
minor version. For example, v2.3 is major version 2 and minor version 3.

**Backwards-compatibility**

Minor version releases expand and do not reduce the interface. For
example, everything in v2.1 is available in v2.2.

**Property protections**

The Images API v2.2 enables a cloud provider to employ *property
protections*, an optional feature whereby CRUD protections are applied
to image properties.

Thus, in particular deployments, non-admin users might not be able to
view, update, or delete some image properties.

Additionally, non-admin users might be forced to follow a particular
naming convention when creating custom image properties.

It is left to the cloud provider to communicate policies concerning
property protections to users.

HTTP response status codes
--------------------------

The following HTTP status codes are all valid responses:

-  200 - generic successful response, expect a body
-  201 - entity created, expect a body and a Location header
-  204 - successful response without body
-  301 - redirection
-  400 - invalid request (syntax, value, etc)
-  401 - unauthenticated client
-  403 - authenticated client unable to perform action
-  409 - that action is impossible due to some (possibly permanent)
   circumstance
-  415 - unsupported media type

Responses that don't have a 200-level response code are not guaranteed
to have a body. If a response does happen to return a body, it is not
part of this spec and cannot be depended upon.

Authentication and authorization
--------------------------------

This spec does not govern how one might authenticate or authorize
clients of the v2 Images API. Implementors are free to decide how to
identify clients and what authorization rules to apply.

Note that the HTTP 401 and 403 status codes are included in this
specification as valid response codes.

Request and response content format
-----------------------------------

The Images Service API v2 primarily accepts and serves JSON-encoded
data. In certain cases it also accepts and serves binary image data.
Most requests that send JSON-encoded data must have the proper media
type in their Content-Type header: 'application/json'. HTTP PATCH
requests must use the patch media type defined for the entity they
intend to modify. Requests that upload image data should use the media
type 'application/octet-stream'.

Each call only responds in one format, so clients should not worry about
sending an Accept header. It is ignored. The response is formatted as
'application/json' unless otherwise stated in this spec.

Image entities
--------------

An image entity is represented by a JSON-encoded data structure and its
raw binary data.

An image entity has an identifier (ID) that is guaranteed to be unique
within the endpoint to which it belongs. The ID is used as a token in
request URIs to interact with that specific image.

An image is always guaranteed to have the following attributes: id,
status, visibility, protected, tags, created\_at, file and self. The
other attributes defined in the ``image`` schema below are guaranteed to
be defined, but is only returned with an image entity if they have been
explicitly set.

A client may set arbitrarily-named attributes on their images if the
``image`` json-schema allows it. These user-defined attributes appear
like any other image attributes. See
`documentation <http://tools.ietf.org/html/draft-zyp-json-schema-03#section-5.4>`__
of the additionalProperties json-schema attribute.

JSON schemas
------------

The necessary
`json-schema <http://tools.ietf.org/html/draft-zyp-json-schema-03>`__
documents are provided at predictable URIs. A consumer should be able to
validate server responses and client requests based on the published
schemas. The schemas contained in this document are only examples and
should not be used to validate your requests. A client should **always**
fetch schemas from the server.

**Property Protections**

Version 2.2 of the Images API acknowledges the ability of a cloud
provider to employ *property protections*. Thus, there may be image
properties that will not appear in the list images response for
non-admin users.

