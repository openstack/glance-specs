..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

============================================
Tag Catalog Support For Metadata Definitions
============================================

https://blueprints.launchpad.net/glance/+spec/metadefs-tags

This blueprint adds the basic tag catalog back after it was deferred from Juno
due to time constraints. The original, approved spec included supporting tag
libraries in the metadata definitions catalog. However, at the end of
Juno, the original spec was updated to remove tags since they weren't
implemented.

This spec is actually a reduction of the tag concepts in the original
approved Juno spec. In the original Juno spec, tags had a dynamic hierarchy
capability.  This spec does not include the tag hierarchy in order to
simplify this spec. That aspect of tags will be deferred to a later spec.

The implemented juno spec is here for reference:

https://github.com/openstack/glance-specs/blob/master/specs/juno/metadata-schema-catalog.rst

Problem description
===================

A challenge with using OpenStack is discovering, sharing, and correlating
tags across services and different types of resources. We believe this
affects both end users and administrators.

For example, a cloud operator or vendor may have a predefined set of "tags"
they want to be used as a starting point for images and instances. Currently,
OpenStack does not have a facility for the cloud operator to include that base
set of tags. This means that every deployment and every project may end up
with its own disparate set of tags. This leads to inconsistencies, but also is
extra hassle for end users who end up reinventing all the "tags" in every
project.

For example, is the tag "postgres" the same as "PostgreSQL"? If a
base library of tags is used, any user typing "pos" would be prompted with
the one that already exists in the tag library and would choose it.
Future searches based on tags would ensure consistent results.

**Terminology**

The term metadata can become very overloaded and confusing.  This proposed
enhancement is about the additional metadata that is set as "tags" (name only)
across various artifacts and OpenStack services.

Different APIs may use tags and key / value pairs differently. Tags typically
are not used to drive runtime behavior.  However, key / value pairs are
often used by the system to potentially drive runtime, such as scheduling,
quality of service, or driver behavior.

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

Proposed change
===============

We are proposing enhancements to the Metadata Definitions Catalog. The
following subsections detail the enhancements to the catalog.

**Tags**

A catalog of possible tags that can be used to help ensure tag name consistency
across users, resource types, and services. So, when a user goes to apply a tag
on a resource, they will be able to either create new tags or choose from tags
that have been used elsewhere in the system on different types of resources.
For example, the same tag could be used for Images, Volumes, and Instances.
Tags are not case sensitive (BigData is equivalent to bigdata but is different
from Big-Data).


Alternatives
------------

A key use case is the collaboration on tags using a common catalog. This
is complementary to tags being added ad-hoc across all services. We think the
metadata API could also be backed by a search indexer across services to
include ad-hoc metadata as well as defined metadata. However, that is not the
focus of this blueprint.

Data model impact
-----------------

This will use a relational database and exist in the same database as the
existing Glance Metadata Definitions Catalog. It will be additive to the
existing schema.

The following DB schema is the initial suggested schema. We will improve and
take comments during code review. Constraints not shown for readability.

Suggested Basic Schema::

  CREATE TABLE `metadef_tags` (
    `id`                     int(11) NOT NULL AUTO_INCREMENT,
    `namespace_id`           int(11) NOT NULL,
    `name`                   varchar(80) NOT NULL,
    `created_at`             timestamp NOT NULL,
    `updated_at`             timestamp
  )

This will not include Tag descriptions in this revision.

REST API impact
---------------

In the REST API everything is referred by namespace and name rather than
synthetic IDs. This helps to achieve portability (import / export using JSON).

APIs should allow coarse grain and fine grain access to information in order
to control data transfer bandwidth requirements.

Working with Namespaces
Basic interaction is:

 #. Get list of namespaces with overview info based on the desired filters.
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

Namespace may optionally contain the following in addition to basic fields.

* resource_types
* properties
* objects
* tags

This spec adds Tags.

**Tags**

List All Tags in a namespace:
    GET /metadefs/namespace/{namespace}/tags

Filters by adding query parameters::

 limit          = Use to request a specific page size. Expect a response
                  to a limited request to return between zero and limit items.
 marker         = Specifies the name of the last-seen tag.
                  The typical pattern of limit and marker is to make an initial
                  limited request and then to use the last tag from the
                  response as the marker parameter in a subsequent limited
                  request.

Design note: We want a format that allows for additional information
such as description to be added without changing the base response. For this
reason, we used a dictionary for each tag rather than just a flat list of
tags.

Example Body::

    {
        "tags": [
            {
                "name": "Databases"
            },
            {
                "name": "BigData"
            },
            {
                "name": "MySQL",
            },
            {
                "name": "PostgreSQL",
            },
            {
                "name": "MongoDB",
            }
        ]
    }


Create / Replace all tags in a specific namespace:
    POST /metadefs/namespaces/{namespace}/tags/

Add tag in a specific namespace:
    POST /metadefs/namespaces/{namespace}/tags/{tag}

Delete tag in specific namespace:
    DELETE /metadefs/namespaces/{namespace}/tags/{tag}

Delete all tags in specific namespace:
    DELETE /metadefs/namespaces/{namespace}/tags

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

None anticipated.

This is expected to be called from Horizon when an admin wants to annotate
tags onto things likes images and instances. This API would be hit for them to
get available tags or create new ones.

Other deployer impact
---------------------
DB Schema Creation for new API

Default / Sample tag libraries will be checked into Glance.

Deployers can customize these and provide additional definition files suitable
to their cloud deployment.

glance-manage will include loading tags.

Developer impact
----------------
None (New API)

Implementation
==============

Assignee(s)
-----------

Primary assignee:
 wayne-okuma

Other contributors:
 None

Reviewers
---------

Core reviewer(s):
  zhiyan

Other reviewer(s):
  lakshmi-sampath
  travis-tripp

Work Items
----------

 Changes would be made to:

 #. The database API layer to add support for CRUD operations on tags
 #. The REST API for CRUD operations on the namespaces (add tags)
 #. The REST API for CRUD operations on the tags
 #. The python-glanceClient to support operations
 #. glance-manage to handle tags

Dependencies
============

Same dependencies as Glance.

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

`Youtube summit recap of Graffiti Juno POC demo that included tags.
<https://www.youtube.com/watch?v=Dhrthnq1bnw>`_

`Current glance metadata definition catalog documentation.
<http://docs.openstack.org/developer/glance/metadefs-concepts.html>`_

*Simple application category tags (no hierarchy)*

Images, volumes, software applications can be assigned to a category.
Similarly, a flavor or host aggregate could be "tagged" with supporting a
category of application, such as "BigData" or "Encryption". Using the
matching of categories, flavors or host aggregates that support that category
of application can be easily paired up.

Note: If a resource type doesn’t provide a "Tag" mechanism (only key value
pairs), a blueprint should be added to support tags on that type of resource.
In lieu of that, a key of "tags" with a comma separated list of tags as the
value be set on the resource
