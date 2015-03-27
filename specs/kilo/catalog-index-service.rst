..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=====================
Catalog Index Service
=====================

https://blueprints.launchpad.net/glance/+spec/catalog-index-service

This is intended to improve performance of Glance API services while
dramatically improving search capabilities.

It will improve performance by offloading user search queries from existing
API servers. In addition, we are working on numerous improvements in Horizon
which will include improvements to image, snapshot, artifact details and
searching. The desired user experience is greatly dependent upon a rich,
dynamic, near real time faceted and aggregated search capability with a strong
query language.

This will initially be considered "Experimental API". The API is intended to
be as close to final as possible, but we reserve the right to completely
abandon this or change it making it backwards in-compatible.

Problem description
===================

Glance has metadata for all images and provides listing of them.  If you want
to search for images based on criteria, the API is limited and somewhat
inflexible. Search currently is limited to union ("AND" operations) searching
of certain hard coded attributes. There is no support for intersection ( "OR"
operations).

Searching does not include searching descriptions and has limited support for
property based searches. Full text searching of descriptions is typically slow
with a traditional relational database. Adding full text indexing to the
database can degrade overall performance of the database (affects inserts).

With the addition of metadata definitions in Juno release, the new search API
should allow the users to specify the search criteria using the tags and
property type definition in addition to adhoc string search. They should
ideally get auto-completion of possible properties and property values with
near real time response.

Artifact definitions will support storing dynamic properties based on the
artifact type. However, proper indexing and search is not possible with a
traditional RDBMS. You end up with full table scans across tables that are not
applicable for a given query.  In addition, writing and understanding the
query engine is difficult to understand and maintain, especially after the
original authors move on.

Adding new properties with constraints for highly performant searching is
difficult to achieve in a relational database.

A search engine needs to be easily customizable so that the data being
collected can be changed dynamically and the way it is indexed and searched
can be easily modified without requiring source data migration. (e.g. a new
type of object to group namespaces together called "category")

Typical search interfaces should also provide facilities like auto-completion
and search suggestions with near real time performance.  This is not possible
with a traditional database.

Adding more attributes to a search query over time should be easy to extend
and maintain without exponentially increasing the complexity of the search
logic.

User should be able to combine the search query across resources (images,
metadata, artifacts) easily.

A search engine should not put additional load on the normal functions of the
primary service and should easily accommodate more users by distributing the
load on separate server instances. For example, a search query from Horizon
should not impact Nova.

Proposed change
===============

We are proposing a new catalog search service for Glance that will improve
performance of Glance API services while dramatically improving search
capabilities. The following subsections detail the concepts.

Block Diagram:

https://wiki.openstack.org/w/images/7/74/Index-service-block-diagram.png

The service will be based on Elasticsearch. Elasticsearch is a search server
based on Lucene. It provides a distributed, scalable, near real-time, faceted,
multitenant-capable full-text search engine with a RESTful web interface and
schema-free JSON documents. Elasticsearch is developed and released as open
source under the terms of the Apache License.  Notable users of Elasticsearch
include Wikimedia, StumbleUpon, Mozilla, Quora, Foursquare, Etsy, SoundCloud,
GitHub, FDA, CERN, and Stack Exchange.
(Source: http://en.wikipedia.org/wiki/Elasticsearch)

The elastic-recheck project also uses Elasticsearch (and kibana) to classify
and track OpenStack gate failures.
(Source: http://status.openstack.org/elastic-recheck)

**Indexing**

*Index*

This will serve as the cache for all search requests. It will be backed by
Elasticsearch.

*Index Loaders*

Index loaders define the data mappings for indexing and load the data from the
source. They are called during initialization of service and on-demand later
when required to index everything. They ensure that all appropriate RBAC
information is included in the index to facilitate appropriate authorization
on search responses.

The index loaders will attempt to maintain native API format as best as
possible with as much direct pass through as possible so that data manipulation
and maintenance is kept to a minimum.

An example Glance Image data mapping would be::

  {
    'dynamic': True,
    'properties': {
        'id': {'type': 'string'},
        'name': {'type': 'string'},
        'description': {'type': 'string'},
        'tags': {'type': 'string'},
        'disk_format': {'type': 'string'},
        'container_format': {'type': 'string'},
        'size': {'type': 'long'},
        'virtual_size': {'type': 'long'},
        'status': {'type': 'string'},
        'visibility': {'type': 'string'},
        'checksum': {'type': 'string'},
        'min_disk': {'type': 'long'},
        'min_ram': {'type': 'long'},
        'owner': {'type': 'string'},
        'protected': {'type': 'boolean'},
    },
  }

*Index Updates*

Once the index is initialized it needs to be constantly updated to keep it in
sync with the data source. Update clients will listen for notifications from
data sources to re-index the data for specific resources (e.g. an image or
artifact).

For glance, it would listen on message Topic for notifications like (image.create,
image.update, etc) and reindex for the effected image metadata.
(More info at http://docs.openstack.org/developer/glance/notifications.html)

*Index Management API*

Allows for CRUD management of loading, updating and deleting data in the index.
Indexing is allowed only for admin users.

Default policy.json will be::

 {
   "catalog_index": "role:admin",
   "catalog_search": ""
 }


**Searching**

The search API allows users to execute a search query and get back search hits
that match the query. The query can either be provided using a simple query
string as a parameter, or using a request body.

.. note:: Search query is not parsed and passed "as-is" to elastic search engine except for adding filters. Response from search engine could be filtered based on the plugin implementation of document type.

All search APIs can be applied across multiple types within an index, and
across multiple indices with support for the multi index syntax.

This will allow for search phrase completion as well as search suggestions(
such as handling misspellings)

The search will have two levels of RBAC.

1. API level policy checks using policy.json files.  This will allow coarse
grained RBAC support for simple deny / allow on API usage.

2. RBAC query filters.  These will be defined in conjunction with index loaders.
When a request comes in, the type(s) of resource(s) being requested will map
to an RBAC query filter.

The RBAC query filter will add any appropriate filters to the request being
sent into the elastic search service, such that only specific results that
the user is allowed to view will be returned.

For example, the image index loader will include indexing owner information
and visibility information. The RBAC filter will examine the incoming request
and adds filters to the request so that the results don't include non-shared /
non-public images from a different project than the user making the request.

Property protected fields will be read from the config file and will be added
as "source filtering" field(s) in elasticsearch query which will keep/remove the
protected fields from the search output based on the authorization of the user.

Alternatives
------------

Searching data could also be achieved by writing SQL queries on the Glance
database but there are several factors which do not make it an ideal
solution:

* Joins across multiple tables in real time will make the response time very
  slow
* Full text searching of descriptions is typically slow with a traditional
  relational database. Adding full text indexing to the database can degrade
  overall performance of the database
* Property types can be added dynamically using metadefs and proper indexing
  in relational databases is not possible
* Search queries will be running against the same database used by Glance core
  functions and inadvertently effecting their response time.
* Adding more attributes to search query over time should be easy to extend
  and maintain without exponentially increasing the complexity of the search
  logic

User should be able to combine the search query across resources (images,
artifacts) etc. and the search engine should not be tightly integrated with
any specific module.

Another alternative would be for clients to load the entire data set and
search within the client.  This means every user gets all the data every
time the user loads the page and has to keep it in sync with server side data.
This is increases the load and burden on the core OpenStack service providing
the data and is slower since the client has to load the entire dataset across
the network. In addition, the client has to recreate the logic for things like
search suggestions and complex queries with AND / OR logic.

It should be noted that NONE of these options also include an ability to do things
like get search request scoring of results returned with a configurable threshold
for results (something elastic search provides).

Data model impact
-----------------

The data being indexed will be stored outside the Glance SQL database and
therefore we don't expect any data model changes in Glance.

REST API impact
---------------

Common Response Codes

* Create Success: 201 Created
* Modify Success: 200 OK
* Delete Success: 204 No Content
* Failure: 400 Bad Request with details.
* Forbidden: 403 Forbidden
* Not found: 404 Not found e.g. if specific entity not found
* Method Not Allowed: 405 Not allowed e.g. if trying to delete on a list resource
* Not Implemented: 501 Not Implemented e.g. HEAD not implemented

This is an experimental API

**API Version**

Search images supports both GET and POST.
Elasticsearch supports GET with query params but its a limited subset of query DSL.
GET is implemented here with a request body to make use of all the available query options

Please refer to the following URI for the Query DSL
http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl.html

Search images(GET)::

  GET /v2/search

Example Request Body::

  {
    "index": ["glance"],
    "type": ["image"],
    "query": {
        "query_string": {
            "query": "cirros"
        }
    }
  }

Example Response Body::

  {
    "took": 5,
    "timed_out": false,
    "_shards": {
        "total": 10,
        "successful": 10,
        "failed": 0
    },
    "hits": {
        "total": 3,
        "max_score": 0.40409642,
        "hits": [
            {
                "_index": "search",
                "_type": "image",
                "_id": "75fbdd4c-3e5b-4552-8950-9bb5262babcd",
                "_score": 0.40409642,
                "_source": {
                    "status": "active",
                    "virtual_size": null,
                    "name": "cirros-0.3.2-x86_64-uec-ramdisk",
                    "property": [],
                    "container_format": "ari",
                    "min_ram": 0,
                    "disk_format": "ari",
                    "properties": [],
                    "owner": "f72690e85b2a4ff095f50b7fad99429a",
                    "protected": false,
                    "checksum": "68085af2609d03e51c7662395b5b6e4b",
                    "min_disk": 0,
                    "is_public": true,
                    "size": 3723817,
                    "id": "75fbdd4c-3e5b-4552-8950-9bb5262babcd",
                    "description": ""
                }
            },
            {
                "_index": "search",
                "_type": "image",
                "_id": "95467ea8-dd34-4bdd-8a6a-f52e47ee9bce",
                "_score": 0.23091224,
                "_source": {
                    "status": "active",
                    "virtual_size": null,
                    "name": "cirros-0.3.2-x86_64-uec",
                    "property": [
                        "kernel_id_d00ea383-a1fa-48d3-b56c-880093730b53",
                        "ramdisk_id_75fbdd4c-3e5b-4552-8950-9bb5262babcd",
                        "hypervisor_type_uml",
                        "hw_watchdog_action_poweroff"
                    ],
                    "container_format": "ami",
                    "min_ram": 0,
                    "disk_format": "ami",
                    "properties": [
                       {
                            "name": "kernel_id",
                            "value": "d00ea383-a1fa-48d3-b56c-880093730b53"
                        },
                        {
                            "name": "ramdisk_id",
                            "value": "75fbdd4c-3e5b-4552-8950-9bb5262babcd"
                        },
                        {
                            "name": "hypervisor_type",
                            "value": "uml"
                        },
                        {
                            "name": "hw_watchdog_action",
                            "value": "poweroff"
                        }
                    ],
                    "owner": "f72690e85b2a4ff095f50b7fad99429a",
                    "protected": false,
                    "checksum": "4eada48c2843d2a262c814ddc92ecf2c",
                    "min_disk": 0,
                    "is_public": true,
                    "size": 25165824,
                    "id": "95467ea8-dd34-4bdd-8a6a-f52e47ee9bce",
                    "description": ""
                }
            },
            {
                "_index": "search",
                "_type": "image",
                "_id": "d00ea383-a1fa-48d3-b56c-880093730b53",
                "_score": 0.067124054,
                "_source": {
                    "status": "active",
                    "virtual_size": null,
                    "name": "cirros-0.3.2-x86_64-uec-kernel",
                    "property": [],
                    "container_format": "aki",
                    "min_ram": 0,
                    "disk_format": "aki",
                    "properties": [],
                    "owner": "f72690e85b2a4ff095f50b7fad99429a",
                    "protected": false,
                    "checksum": "836c69cbcd1dc4f225daedbab6edc7c7",
                    "min_disk": 0,
                    "is_public": true,
                    "size": 4969360,
                    "id": "d00ea383-a1fa-48d3-b56c-880093730b53",
                    "description": ""
                }
            }
        ]
    }
  }

Search images(POST)::

  POST /v2/search

Please refer to the following URI for the Query DSL
http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl.html

Example Request Body::

  {
    "index": ["glance"],
    "type": ["image"],
    "query": {
        "query_string": {
            "query": "cirros"
        }
    }
  }

Example Response Body::

  {
    "took": 5,
    "timed_out": false,
    "_shards": {
        "total": 10,
        "successful": 10,
        "failed": 0
    },
    "hits": {
        "total": 3,
        "max_score": 0.40409642,
        "hits": [
            {
                "_index": "search",
                "_type": "image",
                "_id": "75fbdd4c-3e5b-4552-8950-9bb5262babcd",
                "_score": 0.40409642,
                "_source": {
                    "status": "active",
                    "virtual_size": null,
                    "name": "cirros-0.3.2-x86_64-uec-ramdisk",
                    "property": [],
                    "container_format": "ari",
                    "min_ram": 0,
                    "disk_format": "ari",
                    "properties": [],
                    "owner": "f72690e85b2a4ff095f50b7fad99429a",
                    "protected": false,
                    "checksum": "68085af2609d03e51c7662395b5b6e4b",
                    "min_disk": 0,
                    "is_public": true,
                    "size": 3723817,
                    "id": "75fbdd4c-3e5b-4552-8950-9bb5262babcd",
                    "description": ""
                }
            },
            {
                "_index": "search",
                "_type": "image",
                "_id": "95467ea8-dd34-4bdd-8a6a-f52e47ee9bce",
                "_score": 0.23091224,
                "_source": {
                    "status": "active",
                    "virtual_size": null,
                    "name": "cirros-0.3.2-x86_64-uec",
                    "property": [
                        "kernel_id_d00ea383-a1fa-48d3-b56c-880093730b53",
                        "ramdisk_id_75fbdd4c-3e5b-4552-8950-9bb5262babcd",
                        "hypervisor_type_uml",
                        "hw_watchdog_action_poweroff"
                    ],
                    "container_format": "ami",
                    "min_ram": 0,
                    "disk_format": "ami",
                    "properties": [
                       {
                            "name": "kernel_id",
                            "value": "d00ea383-a1fa-48d3-b56c-880093730b53"
                        },
                        {
                            "name": "ramdisk_id",
                            "value": "75fbdd4c-3e5b-4552-8950-9bb5262babcd"
                        },
                        {
                            "name": "hypervisor_type",
                            "value": "uml"
                        },
                        {
                            "name": "hw_watchdog_action",
                            "value": "poweroff"
                        }
                    ],
                    "owner": "f72690e85b2a4ff095f50b7fad99429a",
                    "protected": false,
                    "checksum": "4eada48c2843d2a262c814ddc92ecf2c",
                    "min_disk": 0,
                    "is_public": true,
                    "size": 25165824,
                    "id": "95467ea8-dd34-4bdd-8a6a-f52e47ee9bce",
                    "description": ""
                }
            },
            {
                "_index": "search",
                "_type": "image",
                "_id": "d00ea383-a1fa-48d3-b56c-880093730b53",
                "_score": 0.067124054,
                "_source": {
                    "status": "active",
                    "virtual_size": null,
                    "name": "cirros-0.3.2-x86_64-uec-kernel",
                    "property": [],
                    "container_format": "aki",
                    "min_ram": 0,
                    "disk_format": "aki",
                    "properties": [],
                    "owner": "f72690e85b2a4ff095f50b7fad99429a",
                    "protected": false,
                    "checksum": "836c69cbcd1dc4f225daedbab6edc7c7",
                    "min_disk": 0,
                    "is_public": true,
                    "size": 4969360,
                    "id": "d00ea383-a1fa-48d3-b56c-880093730b53",
                    "description": ""
                }
            }
        ]
    }
  }

Index images: index, create, update and delete data::

   POST /v2/index

Indexing is allowed only for admin users.
Supported actions are index, create, update and delete

Example Request Body::

  {
    "default_index": "search",
    "default_type": "image",
    "actions": [
        {
            "action": "create",
            "index": "search",
            "type": "image",
            "id": "d00ea383-a1fa-48d3-b56c-880093730b54",
            "data": {
                "status": "active",
                "virtual_size": null,
                "name": "cirros-0.3.3-x86_64-uec-kernel",
                "property": [],
                "container_format": "aki",
                "min_ram": 0,
                "disk_format": "aki",
                "properties": [],
                "owner": "f72690e85b2a4ff095f50b7fad99429a",
                "protected": false,
                "checksum": "836c69cbcd1dc4f225daedbab6edc7c7",
                "min_disk": 0,
                "is_public": false,
                "size": 4969360,
                "id": "d00ea383-a1fa-48d3-b56c-880093730b54",
                "description": ""
            }
        },
        {
            "action": "update",
            "index": "search",
            "type": "image",
            "id": "75fbdd4c-3e5b-4552-8950-9bb5262babcd",
            "data": {
                "name": "cirros x86",
                "status": "inactive"
            }
        },
        {
            "action": "delete",
            "index": "search",
            "type": "image",
            "id": "95467ea8-dd34-4bdd-8a6a-f52e47ee9bce"
        }
    ]
  }


Security impact
---------------

None to existing Glance API.
Search queries will apply filters to return data that the user is authorized
to see. See description.

Notifications impact
--------------------

None to existing notifications. Will only consume notifications
Need to add metadef notifications to Glance service.

Other end user impact
---------------------

Update python-glanceclient as needed

Performance Impact
------------------

No changes to existing API or code
Data from Glance DB will read once during initialization to index it inside
search engine.

This is intended to improve performance of Glance API services while
dramatically improving search capabilities. It will improve performance
by offloading user search queries from existing API servers.

Other deployer impact
---------------------

Glance Catalog Index service will be installed as a separate service
with its own port and endpoint.

This will initially be considered "Experimental API". The API is intended to be
as close to final as possible, but we reserve the right to completely abandon
this or change it making it backwards in-compatible.

glance-manage will have new commands for indexing image, metadef, and artifact
data

The deployment will be targeted as a single region service. In future if required
an "Aggregate search" of all regions which can search across all the regions
could be provided.

Developer impact
----------------

These are new API's and will not impact any existing API's.


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  lakshmi-sampath, kamil-rykowski,

Other contributors:
  wayne-okuma, travis-tripp

Reviewers
---------

Core reviewer(s):
  nikhil-komawar zhiyan

Other reviewer(s):
  icordasc

Work Items
----------

* Installation of Elastic Search in Glance environment (single node)
* Index Dictionary data in ElasticSearch
      * Write a tool to index all metadata objects (namespaces objects,
        properties) from database into elasticsearch
      * Write a tool to index all images from database into elasticsearch
      * Merge used properties from Glance(optional)
      * Listen to notifications/events form Glance on Image CRUD(optional) for
        continuous indexing of new/old data
* Create Glance Search API - Interface to backend ElasticSearch
      * Make Policy checks on requests
      * Filter request based on RBAC with user token
* Search Images
      * List all the results by given search query string
* Create Glance Index API
      * Policy checks
* Discuss with Openstack/Infra
      * Test environment for elasticsearch
* Devstack integration of single node elastic search.
* Metadef notifications
      * Generate and Listen to metadef notifications
* Calls the tools (loaders)
* Documentation update
* Update glance client
* Update glance manage


Dependencies
============

* Depends on elasticsearch for search engine


Testing
=======

Unit tests will be added for all possible code with a goal of being able to
isolate functionality as much as possible.

Tempest tests will be added wherever possible.


Documentation Impact
====================

Docs needed for new service and usage.

All document changes will indicate this as "Experimental API"


References
==========

* Elasticsearch Query DSL
  http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl.html







