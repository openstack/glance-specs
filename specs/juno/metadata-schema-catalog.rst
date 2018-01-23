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

In addition, cloud operators should be able to selectively control the
property metadata that they want to be visible in the CLI or horizon UI.
Just because an enabled driver or scheduler filter supports a certain property
doesn't mean that the cloud operator wants that property to be readily visible
for selection in the UI.

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
often used by the system to potentially drive runtime behavior, such as
scheduling, quality of service, or driver behavior.  Other times, key / value
pairs are only intended for end user use and are not directly used to drive
runtime behavior. The metadata may also be used by an external entity such
as a 3rd party policy engine. Some service APIs mix the metadata into a single
bucket and don’t differentiate between the two uses of the metadata.

The terminology for key / value pairs varies across services.

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

In this proposal, we use the term "object" to describe a group of 1…* key /
value pairs that may be applied to different kinds of resources for different
purposes.

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

**Properties (Juno release)**

A property describes a single property and its primitive constraints. Each
property can ONLY be a primitive type:

* string, integer, number, boolean, array

Each primitive type is described using simple JSON schema notation. This
means NO nested objects and no definition referencing.

**Objects (Juno release)**

An object describes a group of one to many properties and their primitive
constraints. Each property in the group can ONLY be a primitive type:

* string, integer, number, boolean, array

Each primitive type is described using simple JSON schema notation. This
means NO nested objects.

The object may optionally define required properties under the semantic
understanding that a user who uses the object should provide all required
properties.

Object derivation with property inheritance was considered, but we will defer
this complexity until it is proven to be necessary.

**Namespaces (Juno release)**

Metadata definitions are contained in namespaces.

- Specify the access controls (CRUD) for everything defined in it. Allows for
  admin only, different projects, or the entire cloud to define and use the
  definitions in the namespace
- Associates the contained definitions to different types of resources

**Tags (Future release)**

A catalog of possible tags that can be used to help ensure tag name consistency
across users, resource types, and services. So, when a user goes to apply a tag
on a resource, they will be able to either create new tags or choose from tags
that have been used elsewhere in the system on different types of resources.
For example, the same tag could be used for Images, Volumes, and Instances.
Tags are case insensitive (BigData is equivalent to bigdata but is different
from Big-Data).

**Tag Hierarchy (Future release)**

The notion of hierarchy has come up in various application related
discussions. It is very simple to support hierarchy. For example, tags of
"MySQL" and "Postgres" could be created and set as having a parent of the
"Database" tag. A user could then tag just "MySQL" on something like an image
or software template. Subsequent searches for resources could be performed for
all "Databases" by simply retrieving the list of tags that are children of the
"Database" tag.


Diagram:

https://wiki.openstack.org/w/images/6/61/Glance-Metadata-Namespace.png

If needed in the future, it may make sense for there to be a default public
namespace visible to all cloud users for all resource types. Having a
default public namespace will make it very easy to manage general metadata
without the overhead of a full multi-tenant environment.

**Resource Type Association (Juno release)**

Resource type association specifies the relationship between resource
types and the namespaces that are applicable to them. This information can be
used to drive UI and CLI views. For example, the same namespace of
objects, properties, and tags may be used for images, snapshots, volumes, and
flavors. Or a namespace may only apply to images.

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

Services may always support a way to discover their available metadata. This
API does not prevent that from occurring. However, this does provide a single
central API to publish and discover metadata without every service having to
implement such a facility. In addition, cloud operators should be able to
selectively control the property metadata that they want to be visible in the
CLI or horizon UI. Just because an enabled driver or scheduler filter supports
a certain property doesn't mean that the cloud operator wants that property to
be readily visible for selection in the UI. This API allows for cloud operators
to have full control over what is made visible.

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

    Table: metadef_namespaces

    +--------------+--------------+------+-----+----------------+
    | Field        | Type         | Null | Key | Extra          |
    +--------------+--------------+------+-----+----------------+
    | id           | int(11)      | NO   | PRI | auto_increment |
    | namespace    | varchar(80)  | NO   | UNI |                |
    | display_name | varchar(80)  | YES  |     |                |
    | description  | text         | YES  |     |                |
    | visibility   | varchar(32)  | YES  |     |                |
    | protected    | tinyint(1)   | YES  |     |                |
    | owner        | varchar(255) | NO   |     |                |
    | created_at   | datetime     | NO   |     |                |
    | updated_at   | datetime     | YES  |     |                |
    +--------------+--------------+------+-----+----------------+

    Table: metadef_objects

    +--------------+-------------+------+-----+----------------+
    | Field        | Type        | Null | Key | Extra          |
    +--------------+-------------+------+-----+----------------+
    | id           | int(11)     | NO   | PRI | auto_increment |
    | namespace_id | int(11)     | NO   | MUL |                |
    | name         | varchar(80) | NO   |     |                |
    | description  | text        | YES  |     |                |
    | required     | text        | YES  |     |                |
    | json_schema  | text        | YES  |     |                |
    | created_at   | datetime    | NO   |     |                |
    | updated_at   | datetime    | YES  |     |                |
    +--------------+-------------+------+-----+----------------+

    Table: metadef_properties

    +--------------+-------------+------+-----+----------------+
    | Field        | Type        | Null | Key | Extra          |
    +--------------+-------------+------+-----+----------------+
    | id           | int(11)     | NO   | PRI | auto_increment |
    | namespace_id | int(11)     | NO   | MUL |                |
    | name         | varchar(80) | NO   |     |                |
    | json_schema  | text        | YES  |     |                |
    | created_at   | datetime    | NO   |     |                |
    | updated_at   | datetime    | YES  |     |                |
    +--------------+-------------+------+-----+----------------+

    Table: metadef_resource_types

    +------------+-------------+------+-----+----------------+
    | Field      | Type        | Null | Key | Extra          |
    +------------+-------------+------+-----+----------------+
    | id         | int(11)     | NO   | PRI | auto_increment |
    | name       | varchar(80) | NO   | UNI |                |
    | protected  | tinyint(1)  | NO   |     |                |
    | created_at | datetime    | NO   |     |                |
    | updated_at | datetime    | YES  |     |                |
    +------------+-------------+------+-----+----------------+

    Table: metadef_namespace_resource_types

    +-------------------+-------------+------+-----+-------+
    | Field             | Type        | Null | Key | Extra |
    +-------------------+-------------+------+-----+-------+
    | resource_type_id  | int(11)     | NO   | PRI |       |
    | namespace_id      | int(11)     | NO   | PRI |       |
    | properties_target | varchar(80) | YES  |     |       |
    | prefix            | varchar(80) | YES  |     |       |
    | created_at        | datetime    | NO   |     |       |
    | updated_at        | datetime    | YES  |     |       |
    +-------------------+-------------+------+-----+-------+


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

**Common Response Codes**

* Create Success: `201 Created`
* Modify Success: `200 OK`
* Delete Success: `204 No Content`
* Failure: `400 Bad Request` with details.
* Forbidden: `403 Forbidden`
* Not found: `404 Not found`       e.g. if specific entity not found
* Not found: `405 Not allowed`     e.g. if trying to delete on a list resource
* Not found: `501 Not Implemented` e.g. HEAD not implemented

**API Version**

All URLS will be under the v2 Glance API.  If it is not explicitly specified
assume /v2/<url>

Create a namespace:
    POST /metadefs/namespaces/

Namespace may optionally contain the following in addition to basic fields.

* resource_type_associations
* properties
* objects
* tags (future release)

Example Body (with no resource types, properties, objects, or tags)::

  {
    "namespace": "MyNamespace",
    "display_name": "My User Friendly Namespace",
    "description": "My description",
    "visibility": "public",
    "protected": true
  }

Replace a namespace definition (not including properties, objects, or tags):
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
        "next": "/v2/metadefs/namespaces?marker=namespace2Here&limit=2",
        "schema": "/v2/schemas/metadefs/namespaces"
    }

    With example namespace:

    {
        "first": "/v2/metadefs/namespaces?sort_key=created_at&sort_dir=asc",
        "namespaces": [
            {
                "namespace": "OS::Compute::Quota",
                "display_name": "Flavor Quota",
                "description": "Compute drivers may enable quotas on...",
                "visibility": "public",
                "protected": true,
                "owner": "admin",
                "resource_type_associations": [
                    {
                        "name": "OS::Nova::Flavor",
                        "created_at": "2014-08-28T17:13:06Z",
                        "updated_at": "2014-08-28T17:13:06Z"
                    }
                ],
                "created_at": "2014-08-28T17:13:06Z",
                "updated_at": "2014-08-28T17:13:06Z",
                "self": "/v2/metadefs/namespaces/OS::Compute::Quota",
                "schema": "/v2/schemas/metadefs/namespace"
            },
            {
                "namespace": "OS::Compute::VirtCPUTopology",
                "display_name": "Virtual CPU Topology",
                "description": "This provides the preferred...",
                "visibility": "public",
                "protected": true,
                "owner": "admin",
                "resource_type_associations": [
                    {
                        "name": "OS::Glance::Image",
                        "prefix": "hw_",
                        "created_at": "2014-08-28T17:13:06Z",
                        "updated_at": "2014-08-28T17:13:06Z"
                    },
                    {
                        "name": "OS::Cinder::Volume",
                        "prefix": "hw_",
                        "properties_target": "image",
                        "created_at": "2014-08-28T17:13:06Z",
                        "updated_at": "2014-08-28T17:13:06Z"
                    },
                    {
                        "name": "OS::Nova::Flavor",
                        "prefix": "hw:",
                        "created_at": "2014-08-28T17:13:06Z",
                        "updated_at": "2014-08-28T17:13:06Z"
                    }
                ],
                "created_at": "2014-08-28T17:13:06Z",
                "updated_at": "2014-08-28T17:13:06Z",
                "self": "/v2/metadefs/namespaces/OS::Compute::VirtCPUTopology",
                "schema": "/v2/schemas/metadefs/namespace"
            }
        ],
        "schema": "/v2/schemas/metadefs/namespaces"
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
                  returning the namespace. For example, if a
                  resource_type_association in the namespace for
                  OS::Nova::Flavor specifies a prefix of hw:, then all
                  properties in the namespace will be returned with
                  hw:<prop_name>. However if, OS::Glance::Image is specified
                  and the prefix is set to hw_, then the property will be
                  returned as hw_<prop_name>.

Example Body::


    {
        "namespace": "MyNamespace",
        "display_name": "My User Friendly Namespace",
        "description": "My description",
        "resource_type_associations" : [
            {
               "name" :"OS::Nova::Aggregate",
               "created_at": "2014-08-28T17:13:06Z",
               "updated_at": "2014-08-28T17:13:06Z"
            },
            {
               "name" : "OS::Nova::Flavor",
               "prefix" : "aggregate_instance_extra_specs:",
               "created_at": "2014-08-28T17:13:06Z",
               "updated_at": "2014-08-28T17:13:06Z"
            }
        ],
        "properties": {
            "nsprop1": {
                "title": "My namespace property1",
                "description": "More info here",
                "type": "boolean",
                "default": true
            }
        },
        "visibility": "public",
        "protected": true,
        "owner": "The Test Owner"
    }


Delete a namespace including all content (properties, objects and tags(future release))
    DELETE /v2/metadefs/namespaces/{namespace}

List resource types associated with a namespace
    GET /v2/metadefs/namespaces/{namespace}/resource_types

Example::

  {
    "resource_type_associations": [
        {
            "name": "OS::Glance::Image",
            "prefix": "hw_",
            "created_at": "2014-08-28T17:13:06Z",
            "updated_at": "2014-08-28T17:13:06Z"
        },
        {
            "name": "OS::Cinder::Volume",
            "prefix": "hw_",
            "properties_target": "image_metadata",
            "created_at": "2014-08-28T17:13:06Z",
            "updated_at": "2014-08-28T17:13:06Z"
        },
        {
            "name": "OS::Nova::Flavor",
            "prefix": "hw:",
            "created_at": "2014-08-28T17:13:06Z",
            "updated_at": "2014-08-28T17:13:06Z"
        }
    ]
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
    "prefix" : "hw_",
    "created_at": "2014-08-28T17:13:06Z",
    "updated_at": "2014-08-28T17:13:06Z"
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
            "description": "The minimum IOPs required",
            "default": 100,
            "minimum": 100,
            "maximum": 30000
        },
        "burstIOPS": {
            "type": "integer",
            "description": "The expected burst IOPs",
            "default": 1000,
            "minimum": 100,
            "maximum": 30000
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

  POST /metadefs/namespaces/OS::Compute::Hypervisor/properties

  {
        "name": "hypervisor_type",
        "type": "array",
        "description": "The type of hypervisor required",
        "items": {
            "type": "string",
            "enum": ["hyperv", "qemu", "kvm"]
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


**Namespace membership management (Deferred to Future Release)**

Allows different projects to have visibility to a non-public namespace.

For example, a cloud operator may have special hardware that is capable of
running cloud and weather simulations. Images that have a certain property
on it will get scheduled for that hardware and the operator only wants certain
projects to see that property and hide it from other projects so that the
cloud hardware isn't misused.


**Schema**

JSON Schema for Namespace::

  {
    "required": [
        "namespace"
    ],
    "properties": {
        "namespace": {
            "type": "string",
            "description": "The unique namespace text.",
            "maxLength": 80
        },
        "description": {
            "type": "string",
            "description": "Provides a user friendly description of the namespace.",
            "maxLength": 500
        },
        "display_name": {
            "type": "string",
            "description": "The user friendly name for the namespace. Used by UI if available.",
            "maxLength": 80
        },
        "owner": {
            "type": "string",
            "description": "Owner of the namespace.",
            "maxLength": 255
        },
        "visibility": {
            "enum": [
                "public",
                "private"
            ],
            "type": "string",
            "description": "Scope of namespace accessibility."
        },
        "protected": {
            "type": "boolean",
            "description": "If true, namespace will not be deletable."
        },
        "created_at": {
            "type": "string",
            "description": "Date and time of namespace creation (READ-ONLY)",
            "format": "date-time"
        },
        "updated_at": {
            "type": "string",
            "description": "Date and time of the last namespace modification (READ-ONLY)",
            "format": "date-time"
        },
        "properties": {
            "$ref": "#/definitions/property"
        },
        "objects": {
            "items": {
                "type": "object",
                "properties": {
                    "properties": {
                        "$ref": "#/definitions/property"
                    },
                    "required": {
                        "$ref": "#/definitions/stringArray"
                    },
                    "name": {
                        "type": "string"
                    },
                    "description": {
                        "type": "string"
                    }
                }
            },
            "type": "array"
        },
        "resource_type_associations": {
            "items": {
                "type": "object",
                "properties": {
                    "prefix": {
                        "type": "string"
                    },
                    "properties_target": {
                        "type": "string"
                    },
                    "name": {
                        "type": "string"
                    }
                }
            },
            "type": "array"
        },
        "schema": {
            "type": "string"
        },
        "self": {
            "type": "string"
        },
        "additionalProperties": false
    }
  }

.. note:: See Schema Definitions below for $ref.

Variations on Namespace schema:

Namespace can also contain the following:

* resource_type_associations
* properties
* objects
* tags (future release)

JSON Schema for Resource Types::

  {
    "name": "resource_type_associations",
    "links": [
        {
            "href": "{first}",
            "rel": "first"
        },
        {
            "href": "{next}",
            "rel": "next"
        },
        {
            "href": "{schema}",
            "rel": "describedby"
        }
    ],
    "properties": {
        "schema": {
            "type": "string"
        },
        "next": {
            "type": "string"
        },
        "resource_type_associations": {
            "items": {
                "additionalProperties": false,
                "required": [
                    "name"
                ],
                "name": "resource_type_association",
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
                    },
                    "created_at": {
                        "type": "string",
                        "description": "Date and time of resource type association (READ-ONLY)",
                        "format": "date-time"
                    },
                    "updated_at": {
                        "type": "string",
                        "description": "Date and time of the last resource type association modification (READ-ONLY)",
                        "format": "date-time"
                    }
                }
            },
            "type": "array"
        },
        "first": {
            "type": "string"
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
.. note:: See Schema Definitions below for property definition.

JSON Schema for Objects::

  {
    "required": [
        "name"
    ],
    "name": "object",
    "additionalProperties": false,
    "properties": {
        "name": {
            "type": "string"
        },
        "required": {
            "$ref": "#/definitions/stringArray"
        },
        "properties": {
            "$ref": "#/definitions/property"
        },
        "description": {
            "type": "string"
        },
        "created_at": {
            "type": "string",
            "description": "Date and time of object creation (READ-ONLY)",
            "format": "date-time"
        },
        "updated_at": {
            "type": "string",
            "description": "Date and time of the last object modification (READ-ONLY)",
            "format": "date-time"
        },
        "schema": {
            "type": "string"
        },
        "self": {
            "type": "string"
        }
    }
  }

Objects also contain "properties" as mentioned above.
.. note:: See Schema Definitions below for $ref.


JSON Schema common definitions::

  {
    "definitions": {
        "property": {
            "additionalProperties": {
                "required": [
                    "title",
                    "type"
                ],
                "type": "object",
                "properties": {
                    "additionalItems": {
                        "type": "boolean"
                    },
                    "enum": {
                        "type": "array"
                    },
                    "name": {
                        "type": "string"
                    },
                    "title": {
                        "type": "string"
                    },
                    "default": {},
                    "minLength": {
                        "$ref": "#/definitions/positiveIntegerDefault0"
                    },
                    "required": {
                        "$ref": "#/definitions/stringArray"
                    },
                    "maximum": {
                        "type": "number"
                    },
                    "minItems": {
                        "$ref": "#/definitions/positiveIntegerDefault0"
                    },
                    "readonly": {
                        "type": "boolean"
                    },
                    "minimum": {
                        "type": "number"
                    },
                    "maxItems": {
                        "$ref": "#/definitions/positiveInteger"
                    },
                    "maxLength": {
                        "$ref": "#/definitions/positiveInteger"
                    },
                    "uniqueItems": {
                        "default": false,
                        "type": "boolean"
                    },
                    "pattern": {
                        "type": "string",
                        "format": "regex"
                    },
                    "items": {
                        "type": "object",
                        "properties": {
                            "enum": {
                                "type": "array"
                            },
                            "type": {
                                "enum": [
                                    "array",
                                    "boolean",
                                    "integer",
                                    "number",
                                    "object",
                                    "string",
                                    null
                                ],
                                "type": "string"
                            }
                        }
                    },
                    "type": {
                        "enum": [
                            "array",
                            "boolean",
                            "integer",
                            "number",
                            "object",
                            "string",
                            null
                        ],
                        "type": "string"
                    },
                    "description": {
                        "type": "string"
                    }
                }
            },
            "type": "object"
        },
        "positiveIntegerDefault0": {
            "allOf": [
                {
                    "$ref": "#/definitions/positiveInteger"
                },
                {
                    "default": 0
                }
            ]
        },
        "stringArray": {
            "uniqueItems": true,
            "items": {
                "type": "string"
            },
            "type": "array"
        },
        "positiveInteger": {
            "minimum": 0,
            "type": "integer"
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
tags (future) or key / value pairs onto things likes images and volumes.
This API would be hit for them to get available metadata.

Other deployer impact
---------------------
DB Schema Creation for new API will now be a newer version

Default resource types will be hardcoded:
* OS::Glance::Image
* OS::Cinder::Volume
* OS::Nova::Flavor
* OS::Nova::Aggregate
* OS::Nova::Instance

glance-manage will have new commands for loading, unloading, and exporting
metadata definitions:
* db_load_metadefs - Loads metadata definitions from a specified directory
* db_unload_metadefs - Unloads all metadata definitions in the database
* db_export_metadefs - Exports metadata definitions to s a specified directory

The python-glanceclient will also support a new set of API and CLI commands
for fine grained management of the metadata definitions in the catalog.

Default definition files will be checked into glance under etc/metadefs

Please note, the default definitions are only suggestions based on potential
metadata in a given OpenStack deployment. The configuration of the actual
deployment environment will likely require the cloud operator to limit
what metadata should be made available in this catalog. They may limit it
based on enabled drivers and filters or may choose to only offer a subset
of the options offered by those drivers and filters. Just because an enabled
driver or scheduler filter supports certain properties doesn't mean that
the cloud operator wants all the properties to be readily visible for selection
in the UI.

Deployers can customize the definitions to be suitable to their cloud
deployment by deleting namespaces, modifying namespaces, creating new
namespaces, and changing namespace to resource type associations.

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
 #. The database API layer to add support for CRUD operations on resource type associations
 #. The REST API for CRUD operations on the namespaces
 #. The REST API for CRUD operations on the objects
 #. The REST API for CRUD operations on the properties
 #. The REST API for CRUD operations on the resource type associations
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
resources through tags (future release).

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
    "resource_type_associations" : [
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
                "default": true
            }
        }
    },
    "visibility": "public",
    "protected": true,
    "owner": "The Test Owner"
  }

*Sample Namespace with properties and objects*

/metadefs/namespace/MyNamespace/detail

Example::

  {
    "namespace": "MyNamespace",
    "display_name": "My User Friendly Namespace",
    "description": "My description",
    "resource_type_associations": [
        {
            "name": "OS::Glance::Image",
            "prefix": "hw_",
            "created_at": "2014-08-28T17:13:06Z",
            "updated_at": "2014-08-28T17:13:06Z"
        },
        {
            "name": "OS::Cinder::Volume",
            "prefix": "hw_",
            "properties_target": "image_metadata",
            "created_at": "2014-08-28T17:13:06Z",
            "updated_at": "2014-08-28T17:13:06Z"
        },
        {
            "name": "OS::Nova::Flavor",
            "prefix": "filter1:",
            "created_at": "2014-08-28T17:13:06Z",
            "updated_at": "2014-08-28T17:13:06Z"
        }
    ],
    "properties": {
        "nsprop1": {
            "title": "My namespace property1",
            "description": "More info here",
            "type": "boolean",
            "default": true
        },
        "nsprop2": {
            "title": "My namespace property2",
            "description": "More info here",
            "type": "string",
            "default": "value1"
        }
    },
    "objects": [
        {
            "name": "object1",
            "namespace": "MyNamespace",
            "description": "My object1 description",
            "properties": {
                "prop1": {
                    "title": "My object1 property1",
                    "description": "More info here",
                    "type": "array",
                    "items": {
                        "type": "string"
                    }
                }
            }
        },
        {
            "name": "object2",
            "namespace": "MyNamespace",
            "description": "My object2 description",
            "properties": {
                "prop1": {
                    "title": "My object2 property1",
                    "description": "More info here",
                    "type": "integer",
                    "default": 20
                }
            }
        }
    ],
    "visibility": "public",
    "protected": true,
    "owner": "The Test Owner"
  }
