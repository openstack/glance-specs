..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================================
Metadata Definitions Catalog
==========================================

https://blueprints.launchpad.net/glance/+spec/metadata-schema-catalog

A common API hosted by the Glance service for vendors, admins, services, and
users to meaningfully define available key / value pair and tag metadata.
The intent is to enable better metadata collaboration across artifacts,
services, and projects for OpenStack users.

This is about the definition of the available metadata that can be used on
different types of resources (images, artifacts, volumes, flavors, aggregates,
etc). A definition includes the properties type, its key, it's description,
and it's constraints. This catalog will not store the values for specific
instance properties.

For example, a definition of a virtual CPU topology property for number of
cores will include the key to use, a description, and value constraints like
requiring it to be an integer. So, a user, potentially through Horizon, would
be able to search this catalog to list the available properties they can add to
a flavor or image. They will see the virtual CPU topology property in the list
and know that it must be an integer. In the Horizon example, when the user adds
the property, its key and value will be stored in the service that owns that
resource (Nova for flavors and in Glance for images).

Diagram: https://wiki.openstack.org/w/images/b/bb/Glance-Metadata-API.png

Problem description
===================

A challenge we've experienced with using OpenStack is discovering, sharing,
and correlating metadata across services and different types of resources. We
believe this affects both end users and administrators.

Various OpenStack services provide techniques to abstract low level resource
selection to one level higher, such as flavors, volume types, or artifact
types. These resource abstractions often allow "metadata" in terms of tags or
key-value pairs to further specialize and describe instances of each resource
type. However, collaborating and understanding what metadata to use on each
type of resource can be a disconnected and difficult process. This often
involves searching wikis and opening the source code. There is no common way
for vendors or operators to publish their metadata definitions. It becomes more
difficult as a cloud's scale grows and the number of resources being managed
increases.

**Background and Examples**

At the Juno Atlanta summit, the Graffiti team demonstrated the concepts
running under a POC. The following video is a recap of what was demo’d at
the summit and helps to set context:

* https://www.youtube.com/watch?v=Dhrthnq1bnw

We received very positive feedback from members of multiple dev projects
as well as numerous operators.  We were specifically asked multiple times
about getting the metadata definition catalog concepts into Glance so that we
can start to officially support the ideas we demonstrated in Horizon.

Additional examples are at the end of this document.

**Terminology**

The term metadata can become very overloaded and confusing.  This proposed
catalog is about the additional metadata that is passed as either arbitrary
key / value pairs or assigned as "tags" (name only) across various artifacts
and OpenStack services.

Different APIs may use tags and key / value pairs differently. Tags often
are not used to drive runtime behavior.  However, key / value pairs are
often used by the system to potentially drive runtime, such as scheduling,
quality of service, or driver behavior.  Other times, key / value pairs are
only intended for end user use or external use such as a 3rd party policy
engine and are not directly used to drive runtime behavior. Sometimes,
the service API use is mixed because the service doesn’t differentiate
between the two uses of the metadata.

The terminology for key / value pairs varies across services. In this
proposal, we use the term "object" to describe a group of 1…* key /
value pairs that may be applied to different kinds of resources for different
purposes.

A few examples of metadata today:

+-------------------------+---------------------------+----------------------+
|  Nova                   | Cinder                    | Glance               |
+-------------------------+---------------------------+----------------------+
| Flavor                  | Volume & Snapshot         | Image & Snapshot     |
|  + extra specs          |  + image metadata         |  + properties        |
| Host Aggregate          |  + metadata               |  + tags              |
|  + metadata             | VolumeType                |                      |
| Instances               |  + extra specs            |                      |
|  + metadata             |  + qos specs              |                      |
|  + tags                 |                           |                      |
+-------------------------+---------------------------+----------------------+


**Relationship to proposed artifacts API**

This is not about artifact storage, such as Heat templates or various
application packages. This API is about the additional metadata that is beyond
the syntax of the base artifact. Once defined, the metadata can often be
applied to different types of artifacts and resources. For example,
application category tags like "Big Data" may apply to an image or volume that
provides Hadoop or may apply to a Host Aggregate or Flavor that is suitable
for "Big Data" applications.

Proposed change
===============

We are proposing a new Metadata Definitions Catalog.  The following subsections
detail the concepts managed by the catalog.

**Tags**

A catalog of possible tags that can be used to help ensure tag name consistency
across users, resource types, and services. So, when a user goes to apply a tag
on a resource, they will be able to either create new tags or choose from tags
that have been used elsewhere in the system on different types of resources.
For example, the same tag could be used for Images, Volumes, and Instances.
Tags are case insensitive (BigData is equivalent to bigdata but is different
from Big-Data).

**Properties**

A property describes a single property its primitive
constraints. Each property can ONLY be a primitive type:

* string, integer, number, boolean, array

Each primitive type is described using simple JSON schema notation. This
means NO nested objects and no definition referencing.

**Objects**

An object describes a group of one to many properties and their primitive
constraints. Each property can ONLY be a primitive type:

* string, integer, number, boolean, array

Each primitive type is described using simple JSON schema notation. This
means NO nested objects.

The object may optionally define required properties under the semantic
understanding that a user who uses the object should provide all required
properties.

**Hierarchy**

The notion of hierarchy has come up in various application related
discussions. It is very simple to support hierarchy. For example, tags of
"MySQL" and "Postgres" could be created and set as having a parent of the
"Database" tag. A user could then tag just "MySQL" on something like an image
or software template. Subsequent searches for resources could be performed for
all "Databases" by simply retrieving the list of tags that are children of the
"Database" tag.

Object derivation with property inheritance is possible, but we
aren’t sure that the complexity is useful at this time.

**Namespaces**

Object and tag definitions are contained in namespaces. Namespaces are the
containment unit for managing object and tag definitions.

- Specify the access controls (CRUD) for everything defined in it. Allows for
  admin only, different projects, or the entire cloud to define and use the
  definitions in the namespace
- Allow for managing the associations to different types of resources

Diagram:

https://wiki.openstack.org/w/images/6/61/Glance-Metadata-Namespace.png

We think it makes sense for there to be a default public namespace visible
to all cloud users for all resource types. It could be disabled, but having a
default public namespace will make it very easy to manage general metadata
without the overhead of a full multi-tenant environment.

**Resource Type Association**

Resource type association specifies the relationship between resource
types and the namespaces that are applicable to them. This information can be
used to drive UI and CLI views. For example, the same namespace of
objects, properties, and tags may be used for images, snapshots, volumes, and
flavors.

Resource types should be aligned with Heat resource types.
http://docs.openstack.org/developer/heat/template_guide/openstack.html

It is important to note that the same base property key can require different
prefixes depending on the target resource type. Below are a few examples:

The desired virtual CPU topology can be set on both images and flavors
via metadata. The keys have different prefixes on images than on flavors.
On flavors keys are prefixed with ``hw:``, but on images the keys are prefixed
with ``hw_``.

For more: http://git.openstack.org/cgit/openstack/nova-specs/tree/specs/juno/virt-driver-vcpu-topology.rst

Another example is the AggregateInstanceExtraSpecsFilter and scoped properties
(e.g. properties with something:something=value). For scoped / namespaced
properties, the AggregateInstanceExtraSpecsFilter requires a prefix of
"aggregate_instance_extra_specs:" to be used on flavors but not on the
aggregate itself. Otherwise, the filter will not evaluate the property during
scheduling.

So, on a host aggregate, you may see:

companyx:fastio=true

But then when used on the flavor, the AggregateInstanceExtraSpecsFilter needs:

aggregate_instance_extra_specs:companyx:fastio=true

In some cases, there may be multiple different filters that may use
the same property with different prefixes. In this case, the correct prefix
needs to be set based on which filter is enabled.

This spec handles the above cases.

Alternatives
------------

This could be done as a completely separate service. However, it was suggested
by numerous community members at the Juno summit that it made sense to be part
of the expanded Glance mission, since many of the primary targets of the
metadata would be artifacts hosted in Glance. In addition, this also allows
the associated UI components to be built out in Horizon natively rather
than as plug-ins.

We also discussed a Horizon only solution with the Horizon PTL and found some
technical reasons why that wouldn’t make sense:

 + Horizon is a stateless server by design at this point. The only place any
   persistent data can exist is if you choose to store session information
   on the server in a database. The default setup for Horizon now uses
   signed cookies to maintain session data and avoids a DB requirement.
 + There is no privileged account running on the Horizon server and thus no
   way to build a persistent datastore only the admin can obtain. A persistent
   privileged session as this creates many security issues.
 + Horizon can be set up in an HA manner, which would require either duplicate
   DB on multiple Horizon servers or another server dedicated to the DB backend
   for Horizon.

A key use case is the collaboration on metadata using a common catalog. This
is complementary to tags and key / value pairs being added ad-hoc across all
services. We think in the future the metadata API could also be backed by
a search indexer across services to include ad-hoc metadata as well as defined
metadata. However, that is not the focus of this blueprint.

Data model impact
-----------------

This will use a relational database and exist in the same database as the
existing Glance relational data, but there is not anticipated impact to
existing Glance data models. This is all new functionality.

This is about the definition of the available metadata that can be used on
different types of resources (images, artifacts, volumes, flavors, aggregates,
etc). A definition is not just a key and value, so we will not be using a
key / value store database. The definition includes the properties type, its
key, it's description, and it's constraints.  When metadata is used on a
resource, a key with user supplied value will be stored on whatever service
owns that resource and is out of the scope of this spec. For example, an
instance of a key / value pair would be in the Cinder database or the
Glance registry.

Support will be added to:
* glance/db/sqlalchemy/api.py
* registry/api.py
* simple/api.py

A new package will be added at glance/db/sqlalchemy/metadata_defs_api

The table classes will be in glance/db/sqlalchemy/models_metadata_defs.py

The following DB schema is the initial suggested schema. We will improve and
take comments during code review. Constraints not shown for readability.

Suggested Basic Schema::

  CREATE TABLE `metadef_namespaces` (
    `id`                     int(11) NOT NULL AUTO_INCREMENT,
    `namespace`              varchar(80) NOT NULL,
    `display_name`           varchar(80) DEFAULT NULL,
    `description`            text,
    `visibility`             varchar(32) DEFAULT NULL,
    `protected`              tinyint(1) DEFAULT NULL,
    `owner`                  varchar(255) DEFAULT NULL,
    `created_at`             timestamp NOT NULL,
    `updated_at`             timestamp
  )

  CREATE TABLE `metadef_properties` (
    `id`                     int(11) NOT NULL AUTO_INCREMENT,
    `namespace_id`           int(11) NOT NULL,
    `name`                   varchar(80) NOT NULL,
    `schema`                 text,
    `created_at`             timestamp NOT NULL,
    `updated_at`             timestamp
  )

  CREATE TABLE `metadef_objects` (
    `id`                     int(11) NOT NULL AUTO_INCREMENT,
    `namespace_id`           int(11) NOT NULL,
    `name`                   varchar(80) NOT NULL,
    `description`            text,
    `schema`                 text,
    `required`               text,
    `created_at`             timestamp NOT NULL,
    `updated_at`             timestamp
  )

  CREATE TABLE `metadef_tags` (
    `id`                     int(11) NOT NULL AUTO_INCREMENT,
    `namespace_id`           int(11) NOT NULL,
    `name`                   varchar(80) NOT NULL,
    `created_at`             timestamp NOT NULL,
    `updated_at`             timestamp
  )

  CREATE TABLE `metadef_tag_parents` (
    `child_tag_id`           int(11) NOT NULL,
    `parent_tag_id`          int(11) NOT NULL
  )

  CREATE TABLE `metadef_resource_types` (
    `id`                     int(11) NOT NULL AUTO_INCREMENT,
    `resource_type`          varchar(80) NOT NULL,
    `protected`              tinyint(1)  DEFAULT 0
  )

  CREATE TABLE `metadef_namespace_resource_types` (
    `resource_type_id`       int(11) NOT NULL,
    `namespace_id`           int(11) NOT NULL,
    `properties_target`      varchar(80) NULL,
    `prefix`                 varchar(80) NULL
  )


REST API impact
---------------

In the REST API everything is referred by namespace and name rather than
synthetic IDs. This helps to achieve portability (import / export using JSON).

APIs should allow coarse grain and fine grain access to information in order
to control data transfer bandwidth requirements.

Working with Namespaces
Basic interaction is:

 #. Get list of namespaces with overview info based on the desired filters.
    (e.g. key / values for images).
 #. Get objects
 #. Get tags

**Common Response Codes**

* Create Success: `201 Created`
* Modify Success: `200 OK`
* Delete Success: `204 No Content`
* Failure: `400 Bad Request` with details.
* Forbidden: `403 Forbidden`
* Not found: `404 Not found` if specific entity not found

**API Version**

All URLS will be under the v2 Glance API.  If it is not explicitly specified
assume /v2/<url>

Create a namespace:
    POST /metadefs/namespaces/

Namespace may optionally contain the following in addition to basic fields.

* resource_types
* properties
* objects
* tags

Example Body (with no resource types, properties, objects, or tags)::

  {
    "namespace": "MyNamespace",
    "display_name": "My User Friendly Namespace",
    "description": "My description",
    "visibility": "public",
    "protected": true
  }

Replace a namespace definition (not including properties, objects, and tags):
    PUT /metadefs/namespaces/{namespace}

List Namespaces: Returns just the list of namespaces without any objects
  properties, or tags.
    GET /metadefs/namespaces/

Example Body::

    {
        "namespaces": [
            {namespace1Here},
            {namespace2Here}
        ],
        "first": "/v2/metadefs/namespaces?limit=2",
        "next": "/v2/metadefs/namespaces?marker=namespace2Here&limit=2"
    }

    With example namespace:

    {
        "namespaces": [
            {
                "namespace": "MyNamespace",
                "display_name": "My User Friendly Namespace",
                "description": "My description",
                "property_count": 0,
                "object_count": 2,
                "tag_count": 0,
                "resource_types" : [
                    {
                       "name" :"OS::Nova::Aggregate"
                    },
                    {
                       "name" : "OS::Nova::Flavor",
                       "prefix" : "aggregate_instance_extra_specs:"
                    }
                ],
                "visibility": "public",
                "protected": true,
                "owner": "The Test Owner",
                "self": "/v2/metadefs/namespace/MyNamespace"
            }
        ],
        "first": "/v2/metadefs/namespaces?limit=1",
        "next": "/v2/metadefs/namespaces?marker=MyNamespace&limit=1"
    }


Filter by adding query parameters::

 resource_types = <comma separated list> e.g. OS::Glance::Image
 visibility     = Valid values are public, private.
                  Default is to return both public namespaces and private
                  namespaces visible to the user making the request.
 limit          = Use to request a specific page size. Expect a response
                  to a limited request to return between zero and limit items.
 marker         = Specifies the namespace of the last-seen namespace.
                  The typical pattern of limit and marker is to make an initial
                  limited request and then to use the last namespace from the
                  response as the marker parameter in a subsequent limited
                  request.

Returns specific namespace including metadata definitions (properties,
  objects or tags).
    GET /metadefs/namespaces/{namespace}

Query parameters::

 resource_type  = When specified, the API will look up the prefix associated
                  with the specified resource type and will apply the prefix
                  to all properties (including object properties) prior to
                  returning the result. For example, if a
                  resource_type_association in the namespace for
                  OS::Nova::Flavor specifies a prefix of hw:, then all
                  properties in the namespace will be returned with
                  hw:<prop_name>.

Example Body::


    {
        "namespace": "MyNamespace",
        "display_name": "My User Friendly Namespace",
        "description": "My description",
        "property_count": 1,
        "object_count": 0,
        "tag_count": 0,
        "resource_types" : [
            {
               "name" :"OS::Nova::Aggregate"
            },
            {
               "name" : "OS::Nova::Flavor",
               "prefix" : "aggregate_instance_extra_specs:"
            }
        ],
        "properties": {
            "nsprop1": {
                "title": "My namespace property1",
                "description": "More info here",
                "type": "boolean",
                "readonly": true,
                "default": true
            }
        },
        "visibility": "public",
        "protected": true,
        "owner": "The Test Owner"
    }


Delete a namespace including all content (tags, properties, and objects)
    DELETE /v2/metadefs/namespaces/{namespace}

List resource types associated with a namespace
    GET /v2/metadefs/namespaces/{namespace}/resource_types

Example::

  {
    "resource_types" : [
        {
           "name" : "OS::Glance::Image",
           "prefix" : "hw_"
        },
        {
           "name" :"OS::Cinder::Volume",
           "prefix" : "hw_",
           "properties_target" : "image_metadata"
        },
        {
           "name" : "OS::Nova::Flavor",
           "prefix" : "hw:"
        }
    }
  }

Field descriptions::

 name               - (required) Resource type names should be aligned with
                                 Heat resource types whenever possible:
                                 http://docs.openstack.org/developer/heat/template_guide/openstack.html
 prefix             - (optional) Specifies the prefix to use for the given
                                 resource type. Any properties in the
                                 namespace should be prefixed with this
                                 prefix when being applied to the specified
                                 resource type. Must include prefix separator
                                 (e.g. a colon :).
                                 Must include prefix separator (e.g. a colon :).
 properties_target  - (optional) Some resource types allow more than one
                                 key / value pair per instance.  For example,
                                 Cinder allows user and image metadata on
                                 volumes. Only the image properties metadata
                                 is evaluated by Nova (scheduling or drivers).
                                 This property allows a namespace target
                                 to remove the ambiguity.

Associate Namespace to resource type
    POST /metadefs/namespaces/{namespace}/resource_types

Example::

  {
    "name" :"OS::Cinder::Volume",
    "properties_target" : "image_metadata",
    "prefix" : "hw_"
  }

De-associate Namespace from resource type
    DELETE /metadefs/namespaces/{namespace}/resource_types/{resource_type}

Get list of all possible resource types
    GET /metadefs/resource_types

**Objects**

Add Object in a specific namespace:
    POST /metadefs/namespaces/{namespace}/objects

Example::

  POST /metadefs/namespaces/CompanyXNamespace/objects

  {
    "name": "StorageQOS",
    "description": "Our available storage QOS.",
    "required": [
        "minIOPS"
    ],
    "properties": {
        "minIOPS": {
            "type": "integer",
            "readonly": false,
            "description": "The minimum IOPs required",
            "default": 100,
            "minimum": 100,
            "maximum": 30000369
        },
        "burstIOPS": {
            "type": "integer",
            "readonly": false,
            "description": "The expected burst IOPs",
            "default": 1000,
            "minimum": 100,
            "maximum": 30000377
        }
    }
  }

Replace an object definition in a namespace:
    PUT /metadefs/namespaces/{namespace}/objects/{object_name}

Delete all objects in specific namespace:
    DELETE /metadefs/namespaces/{namespace}/objects

Delete specific object in specific namespace:
    DELETE /metadefs/namespaces/{namespace}/objects/{object_name}

Get a specific object in a namespace:
    GET /metadefs/namespaces/{namespace}/objects/{object_name}

List objects in a specific namespace:

Return all objects including its schema properties
    GET /metadefs/namespaces/{namespace}/objects

Filters by adding query parameters::

 limit          = Use to request a specific page size. Expect a response
                  to a limited request to return between zero and limit items.
 marker         = Specifies the namespace of the last-seen namespace.
                  The typical pattern of limit and marker is to make an initial
                  limited request and then to use the last namespace from the
                  response as the marker parameter in a subsequent limited
                  request.

Example Body::

  {
        "objects": [
        {
            "name": "object1",
            "namespace": "my-namespace",
            "description": "my-description",
            "properties": {
                "prop1": {
                    "title": "My Property",
                    "description": "More info here",
                    "type": "boolean",
                    "readonly": true,
                    "default": true
                }
            }
        }
    ],
    "first": "/v2/metadefs/objects?limit=1",
    "next": "/v2/metadefs/objects?marker=object1&limit=1",
    "schema": "/v2/schema/metadefs/objects"
  }

**Properties (not in an object)**

Add Property in a specific namespace:
    POST /metadefs/namespaces/{namespace}/properties

Example::

  POST /metadefs/namespaces/OS::Glance::CommonImageProperties/properties

  {
        "name": "hypervisor_type",
        "type": "array",
        "description": "The type of hypervisor required",
        "items": {
            "type": "string",
            "enum": ["hyperv", "qemu", "kvm"]
         }
     }
  }

Replace a property definition in a namespace:
    PUT /metadefs/namespaces/{namespace}/properties/{property_name}

Delete all properties in specific namespace:
    DELETE /metadefs/namespaces/{namespace}/properties

Delete Property in specific namespace:
    DELETE /metadefs/namespaces/{namespace}/properties/{property_name}

Get a specific property in a namespace:
    GET /metadefs/namespaces/{namespace}/properties/{property_name}

List properties in a specific namespace:

Returns details of all properties in a namespace including property schema:
    GET /metadefs/namespaces/{namespace}/properties

Filters by adding query parameters::

 limit          = Use to request a specific page size. Expect a response
                  to a limited request to return between zero and limit items.
 marker         = Specifies the namespace of the last-seen namespace.
                  The typical pattern of limit and marker is to make an initial
                  limited request and then to use the last namespace from the
                  response as the marker parameter in a subsequent limited
                  request.


**Tags**

List All Tags visible to user:
    GET /metadefs/tags

Filters by adding query parameters::

 tag_prefix     = Support now with only case insensitive, prefix search,
                   e.g. "CEN" would find CENTOS
 namespaces     = <comma separated list>
 resource_types = <comma separated list> e.g. OS::Glance::Image
 visibility     = Valid values are public, private.
                  Default is to return both public namespaces and private
                  namespaces visible to the user making the request.
 limit          = Use to request a specific page size. Expect a response
                  to a limited request to return between zero and limit items.
 marker         = Specifies the namespace of the last-seen namespace.
                  The typical pattern of limit and marker is to make an initial
                  limited request and then to use the last namespace from the
                  response as the marker parameter in a subsequent limited
                  request.



Pattern filter could be supported in future blueprint that incorporates
elasticsearch across OpenStack.

Example Body::

    {
        "tags" : [
            "tag-one",
            "tag-n"
        ]
    }

Create / Replace all tags in a specific namespace:
    POST /metadefs/namespaces/{namespace}/tags/

Example Body::

    {
        "tags" : [
            "tag-one",
            "tag-n"
        ]
    }

Add tag in a specific namespace:
    POST /metadefs/namespaces/{namespace}/tags/{tag}

Delete tag in specific namespace:
    DELETE /metadefs/namespaces/{namespace}/tags/{tag}

Delete all tags in specific namespace:
    DELETE /metadefs/namespaces/{namespace}/tags

List Tags that are immediate children of a specific tag (Hierarchy):
    GET /metadefs/namespaces/{namespace}/tags/{tag}/children

e.g. /metadefs/namespaces/default/tags/database/children

Example Body::

    {
        "tags" : [
            "mysql",
            "oracle",
            "postgres"
        ]
    }

Add parent tag to a tag:
    PUT /metadefs/namespaces/{namespace}/tags/{tag}/parent/{tag}

e.g. PUT /metadefs/namespaces/default/tags/mysql/parent/database

List Tags that are children of a specific tag (Hierarchy):
    GET /metadefs/namespaces/{namespace}/tags/{tag}/descendants

e.g. /metadefs/namespaces/{namespace}/tags/database/descendants

Example Body::

    {
        "tags" : [
            "mysql",
            "oracle",
            "postgres"
        ]
    }

**Namespace membership management (Potentially Deferred to Future Spec)**

Allows different projects to have visibility to a non-public namespace.

Add a member to having access to a namespace
    POST /metadefs/namespaces/{namespace}/members/

Example Body::

  {
    "member": "8987754tst4feggw37"
  }

Remove a member from having access to a namespace
    DELETE /metadefs/namespaces/{namespace}/members/{member_id}

List all members that have access to a namespace
    GET metadata/namespaces/{namespace}/members/

Example Body::

  {
    "members": [
        {
            "created_at": "2013-10-07T17:58:03Z",
            "member_id": "8987754tst4feggw37",
            "namespace": "sample_namespace"
        },
        {
            "created_at": "2013-10-07T17:58:55Z",
            "member_id": "8987754tst4feggw37ads",
            "namespace": "sample_namespace"
        }
    ],
    "schema": "/schemas/metadefs/members"
  }

**Schema**

Note, this is not complete and similar to artifacts, will be updated later.

JSON Schema for Namespace::

  {
    "name": "namespace",
    "properties": {
        "namespace": {
            "type": "string",
            "description": "The unique namespace text.",
            "maxLength": 80
        },
        "display_name": {
            "type": "string",
            "description": "The user friendly name for the namespace.  Used by UI if available.",
            "maxLength": 80
        },
        "description": {
            "type": "string",
            "description": "Provides a user friendly description of the namespace",
            "maxLength": 500
        },
        "property_count": {
            "type": "integer",
            "description": "The number of properties defined in this namespace, not including those defined within objects.",
            "minimum": 0
        },
        "object_count": {
            "type": "integer",
            "description": "The number of objects defined in this namespace.",
            "minimum": 0
        },
        "tag_count": {
            "type": "integer",
            "description": "The number of objects defined in this namespace.",
            "minimum": 0
        },
        "visibility": {
            "type": "string",
            "enum": [
                    "public",
                    "private"
                ]
        },
        "protected": {
           "type": "boolean",
           "description": "If true, image will not be deletable."
        },
        "owner": {
            "type": "string",
            "description": "Owner of the namespace",
            "maxLength": 255
        },
        "created_at": {
            "type": "string",
            "description": "Date and time of registration (READ-ONLY)",
            "format": "date-time"
        },
        "updated_at": {
            "type": "string",
            "description": "Date and time of the last modification (READ-ONLY)",
            "format": "date-time"
        }
    }
  }

Variations on Namespace schema:

Namespace can also contain the following:

* resource_types
* properties
* objects
* tags

JSON Schema for Resource Types::

  {
    "required": ["name"],
    "properties": {
        "name": {
            "type": "string",
            "description": "Resource type names should be aligned with Heat resource types whenever possible: http://docs.openstack.org/developer/heat/template_guide/openstack.html",
            "maxLength": 80
        },
        "prefix": {
            "type": "string",
            "description": "Specifies the prefix to use for the given resource type. Any properties in the namespace should be prefixed with this prefix when being applied to the specified resource type. Must include prefix separator (e.g. a colon :).",
            "maxLength": 80
        },
        "properties_target": {
            "type": "string",
            "description": "Some resource types allow more than one key / value pair per instance.  For example, Cinder allows user and image metadata on volumes. Only the image properties metadata is evaluated by Nova (scheduling or drivers). This property allows a namespace target to remove the ambiguity.",
            "maxLength": 80
        }
    }
  }

JSON Schema for Properties

Namespaces and Objects also contain "properties".  Properties conform to
JSON schema v4 syntax.  But are limited to the following types:
* string
* integer
* number
* boolean
* array

Each primitive type is described using simple JSON schema notation. This
means NO nested objects and no definition referencing.


JSON Schema for Objects::

  {
    "name": {
        "type": "string",
        "description": "Name of the metadata object",
        "maxLength": 80
    },
    "description": {
        "type": "string",
        "description": "Description of the metadata object",
        "maxLength": 500
    },
    "required": {
        "type": "array",
        "items": {
            "type": "string"
        },
        "description": "required properties for the metadata object."
    }
  }

Objects also contain "properties" as mentioned above.

JSON Schema for Tags::

    {
        "properties": {
            "tags": {
                "type": "array",
                "items": {
                    "type": "string",
                }
            }
        }
    }



Security impact
---------------
None

Notifications impact
--------------------
None

Other end user impact
---------------------

We intend to expose this via Horizon and are working on related blueprints.

Update python-glanceclient as needed.

Performance Impact
------------------

No changes to existing APIs or code.

This is expected to be called from Horizon when an admin wants to annotate
tags or key / value pairs onto things likes images and volumes. This API would
be hit for them to get available metadata.

Other deployer impact
---------------------
DB Schema Creation for new API

A new configuration entry to specify additional resource types to which
namespaces should be associated.

Default resource types will be hardcoded:
* OS::Glance::Image
* OS::Cinder::Volume
* OS::Nova::Flavor
* OS::Nova::Aggregate
* OS::Nova::Instance

glance-manage will have new commands for loading, unloading, and exporting
metadata definitions.

Default definition files will be checked into glance.
Deployers can customize these and provide additional definition files suitable
to their cloud deployment.

devstack will be modified to call this command to load in all the default
metadata definitions.

Developer impact
----------------
None (New API)

Implementation
==============

Assignee(s)
-----------

Primary assignee:
 lakshmi-sampath

Other contributors:
 wayne-okuma
 michal-dulko-f
 pawel-skowron
 pawel-koniszewski
 facundo-n-maldonado
 santiago-b-baldassin
 travis-tripp

Work Items
----------

 #. Investigate Pecan / WSME (Pecan ruled out, WSME chosen)

Changes would be made to:

 #. The database API layer to add support for CRUD operations on namespaces
 #. The database API layer to add support for CRUD operations on properties
 #. The database API layer to add support for CRUD operations on objects
 #. The database API layer to add support for CRUD operations on tags
 #. The REST API for CRUD operations on the namespaces
 #. The REST API for CRUD operations on the objects
 #. The REST API for CRUD operations on the objects
 #. The REST API for CRUD operations on the tags
 #. The python-glanceClient to support operations

Dependencies
============

Same dependencies as Glance, except for WSME.

The implementation will be adding WSME object marshalling.

Testing
=======

Unit tests will be added for all possible code with a goal of being able to
isolate functionality as much as possible.

Tempest tests will be added wherever possible.

Documentation Impact
====================

Docs needed for new API extension and usage

References
==========

.. Had to format links strangely in order to meet 80 character limit

`Youtube summit recap of Graffiti POC demo.
<https://www.youtube.com/watch?v=Dhrthnq1bnw>`_

`Mailing list thread after Juno summit.
<https://www.mail-archive.com/
openstack-dev@lists.openstack.org/msg25556.html>`_

`Meeting log where markwash discussed graffiti after summit.
<http://eavesdrop.openstack.org/meetings/glance/2014/
glance.2014-05-29-20.00.log.html>`_

Current glance metadata properties in documentation:

`Current documented Glance metadata properties.
<http://docs.openstack.org/cli-reference/content/chapter_cli-glance-property.html>`_

Hierarchical tagging concepts were partially inspired by AWS marketplace. In
the marketplace, you can filter by a hierarchy of categories. It made sense to
us that this would be easy to achieve across various kinds of artifacts and
resources through tags.

`AWS Categories
<https://aws.amazon.com/marketplace/help/200901100#step1>`_

**Additional Examples**

*Libvirt Driver Options*

Images / Snapshots / Volumes (image metadata)

Today you can provide options to various drivers by putting metadata on
images, snapshots, and volumes.  The drivers read this information and use
them. Currently this is only documented on the wiki.

Driving it from the metadata catalog using the common format we can expose
them for easy use in the UI or CLI.  This kind of metadata ideally could be
published to the catalog programmatically.  It would be associated with
images, snapshots, and volumes.

UI Concept:

https://wiki.openstack.org/w/images/f/f7/Libvirtdriveroptions-objects.PNG

Example Data (subset)::

  {
    "objects": {
        "name": "LibVirtDriverOptions",
        "properties": {
            "hw_video_model": {
                "type": "array",
                "description": "The video image driver used.",
                "items": {
                    "type": "string",
                    "enum": [
                        "vga",
                        "cirrus",
                        "vmvga",
                        "xen",
                        "gxl"
                    ]
                }
            },
            "hw_machine_type": {
                "type": "string",
                "description": "Enables booting an ARM system using the
                                specified machine type. etc"
            },
            "hw_rng_model": {
                "type": "string",
                "description": "Adds a random-number generator device to
                                the image's instances. etc",
                "defaultValue": "virtio"
            }
        }
    }
  }


*Simple application category tags (no hierarchy)*

Images, volumes, software applications can be assigned to a category.
Similarly, a flavor or host aggregate could be "tagged" with supporting a
category of application, such as "Big Data" or "Encryption". Using the
matching of categories, flavors or host aggregates that support that category
of application can be easily paired up.

Note: If a resource type doesn’t provide a "Tag" mechanism (only key value
pairs), a blueprint should be added to support tags on that type of resource.
In lieu of that, a key of "tags" with a comma separated list of tags as the
value be set on the resource

*Namespace with hierarchical tags*

Images, volumes, software applications can be assigned to a category.
Similarly, a flavor or host aggregate could be "tagged" with supporting a
category of application, such as "CRM". Using the matching of categories,
flavors or hosts that support that category of application can be easily
paired up.  Adding the notion of hierarchy allows searching based on the
hierarchy (show me all applications that are type "BusinessSoftware").

- Application Categories

  - Business Software
     + Business Intelligence
     + Collaboration
     + Content Management

*Basic Host Aggregate / Flavor pairing of properties*

Today you can ensure that flavors are launched on specific hosts using host
aggregates.  The basic way to do that is to put the same key / value pair on
both the flavor and the host aggregate.  With a metadata catalog, an admin
could easily describe in detail the key / value pairs and their meaning in an
exportable format for use in a single cloud / region or to import for reuse in
another cloud deployment. As a very trivial example, you could use a property
to collaborate on hosts and flavors that provide SSD. A more advanced
object would be one that has different properties for things like min
IOPS, burst IOPS, etc.

/metadefs/namespace/MyHostGroups/detail

Diagram::                   

 +------------------------+
 |  MyHostGroups          |    +-----------------+
 |  +------------------+  +--> | Flavor          |
 |  |SSD               |  +    +-----------------+
 |  +------------------+  |    +-----------------+
 |                        +--> | Host Aggregate  |
 +------------------------+    +-----------------+

Example::

  {
    "namespace": "MyHostGroups",
    "title": "My Host Groups",
    "description": "Different ways that we like to group our private cloud",
    "property_count": 0,
    "object_count": 2,
    "tag_count": 0,
    "resource_types" : [
        {
           "name" :"OS::Nova::Aggregate"
        },
        {
           "name" : "OS::Nova::Flavor",
           "prefix" : "aggregate_instance_extra_specs:"
        }
    ],
    "objects": {
        "name": "SSD",
        "properties": {
            "MyHostGroups:SSD": {
                "title": "SSD",
                "description": "Describe instances with SSD storage.",
                "type": "boolean",
                "readonly": true,
                "default": true
            }
        }
    },
    "visibility": "public",
    "protected": true,
    "owner": "The Test Owner"
  }

*Sample Namespace with properties, objects and tags*

/metadefs/namespace/MyNamespace/detail

Example::

  {
    "namespace": "MyNamespace",
    "display_name": "My User Friendly Namespace",
    "description": "My description",
    "property_count": 2,
    "object_count": 2,
    "tag_count": 3,
    "resource_types" : [
        {
           "name" : "OS::Glance::Image",
           "prefix" : "hw_"
        },
        {
           "name" :"OS::Cinder::Volume",
           "prefix" : "hw_",
           "properties_target" : "image_metadata"
        },
        {
           "name" : "OS::Nova::Flavor",
           "prefix" : "filter1:"
        }
    ],
    "properties": {
        "nsprop1": {
            "title": "My namespace property1",
            "description": "More info here",
            "type": "boolean",
            "readonly": true,
            "default": true
        },
        "nsprop2": {
            "title": "My namespace property2",
            "description": "More info here",
            "type": "string",
            "readonly": true,
            "default": "value1"
        }
    },
    "objects": [
        {
            "name": "object1",
            "namespace": "my-namespace",
            "description": "my-description",
            "properties": {
                "prop1": {
                    "title": "My object1 property1",
                    "description": "More info here",
                    "type": "array",
                    "items": {
                        "type": "string"
                    },
                    "readonly": false
                }
            }
        },
        {
            "name": "object2",
            "namespace": "my-namespace",
            "description": "my-description",
            "properties": {
                "prop1": {
                    "title": "My object2 property1",
                    "description": "More info here",
                    "type": "integer",
                    "readonly": true,
                    "default": 20
                }
            }
        }
    ],
    "tags": [
        "tag1",
        "tag2",
        "tag3"
    ],
    "visibility": "public",
    "protected": true,
    "owner": "The Test Owner"
  }
