..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=========
Glare API
=========

https://blueprints.launchpad.net/glance/+spec/glare-api

This specification describes stable API of Glance Artifact Repository
service (aka Glare) and covers all most popular use cases.

Problem description
===================

Glare needs a stable API that satisfy requirements of API-WG and DefCore.

Proposed change
===============

This specification aims to solve the described problem by complete refactoring
of Glance Artifact Repository API and changing calls to Glare service.

The behavior of the servers and API calls for Glare will be changed.
To describe service behavior after refactoring in details we prepared some
glossary and list of Use Cases.

**User list**

* *Developer* - person who is contributing to Glare.
* *Glare* - represents Glare service deployed within OpenStack.
* *User* - Glare user who wants to consume Glare artifacts. User should be
  created in Keystone under some project and domain.
* *Cloud Admin* - person who is responsible for Glare administration and
  support within OpenStack.

**Glossary**

* *Glare* (from GLance Artifact REpository) - a service that provides access
  to a unified catalog of immutable objects with structured meta-information as
  well as related binary data (these structures are also called *'artifacts'*).
  Glare controls artifact consistency and guaranties that binary data and
  properties won't change during artifact lifetime.

  .. note::

    Artifact type developer can declare properties which values may be
    changed, but he has to do it explicitly, because by default all properties
    are considered immutable.

* *Artifact* - in terms of Glare, an Artifact is a structured immutable object
  with some properties, related binary data and metadata.

* *Artifact Version* - property of artifact that defines its version in SemVer
  format.

* *Artifact type* - defines artifact structure of both its binary data and
  properties. Examples of OpenStack artifact types that will be supported
  in Glare are: Heat templates, Murano Packages, Nova Images, Tacker VNFs and
  so on.

* *Artifact status* - specifies the state of the artifact and the possible
  actions that can be done with it. List of possible artifact statuses:

  * *queued* - Artifact created but not activated, so it can be changed by
    Artifact owner.

  * *active* - Artifact activated, immutable properties cannot be changed.
    Artifact available for download to other Users.

  * *deactivated* - Artifact is not available to other users except
    administrators, used when Cloud Admin need to check the artifact.

  * *deleted* - Artifact deleted.

.. list-table::  **Artifact status transition table**
   :header-rows: 1

   * - Artifacts Status
     - queued
     - active
     - deactivated
     - deleted

   * - **queued**
     - X
     - activate Artifact
     - N/A
     - delete Artifact

   * - **active**
     - N/A
     - X
     - de-activate Artifact
     - delete Artifact

   * - **deactivated**
     - N/A
     - reactivate Artifact
     - X
     - delete Artifact

   * - **deleted**
     - N/A
     - N/A
     - N/A
     - X


* *Artifact Property* - property of artifact that defines some information
  about Artifact. Artifact Properties always have name, type, value and
  optional additional parameters, described bellow.

  Types are based on types from oslo.versionedobjects library. All types
  are inherited from `FieldType class <https://github.com/openstack/
  oslo.versionedobjects/blob/master/oslo_versionedobjects/
  fields.py#L111-L128>`_
  and define custom behavior.

  Glare uses several primitive types from oslo.versionedobjects directly:

  * *String*;

  * *Integer*;

  * *Float*;

  * *Boolean*;

  And also Glare expands this list with custom types:

  * *Blob*;

  * *Dependency*;

  * Structured generic types *Dict* or *List*.

  Each property has additional parameters:

  * **required_on_activate** - boolean value indicating if the property value
    should be specified for the artifact before activation. (Default: True)

  * **mutable** - boolean value indicating if the property value may be changed
    after the artifact is activated. (Default: False)

  * **system** - boolean value indicating if the property value cannot be edited
    by User. (Default: False)

  * **sortable** - boolean value indicating if there is a possibility to sort by
    this property's values. (Default: False)

  .. note::

    Only properties of 4 primitive types may be sortable: integer, string, float
    and boolean.

  * **default** - a default value for the property may be specified by the Artifact
    Type. (Default: None)

  * **validators** - a list of functions or lambdas like f(self, v) -> Bool. When
    user sets a value to the property with additional validators Glare checks them
    before setting the value and raises *ValueError* if at least one of the
    requirements is not satisfied.

  * **filter_ops** - a list of available filter operators for the property. There
    are seven available operators: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte', 'in'.
    All of them cam be applied to primitive properties only.
    Dict values can be sorted using the following syntax
    "?<dict_name>.<key_name>=<op_name>:<value>."

* *Artifact Dependency* - property type that defines soft dependency of the
  Artifact from another Artifact. It is an url that allows user to obtain
  some Artifact data. For external dependency the format is the following:
  *http(s)://<netloc>/<path>*
  For internal dependencies dependency contains only <path>.
  Example of <path>:
  /artifacts/<artifact_type>/<artifact identifier>.
  User can use filters and page_limits in path to define dynamic dependencies.
  All that Glare will do is request GET with dependency to receive Artifact
  info.

* *Artifact Blob* - property type that defines binary data for Artifact.
  User can download Artifact blob from Glare. Each blob property has a flag
  *external*, that indicates if the property was created during file upload
  (False) or by direct user request (True). In other words, "external" means
  that blob property url is just a reference to some external file and Glare
  does not manage the blob operations in that case.
  Json schema that defines blob format:

  .. code-block:: javascript

        {
            "type": "object",
            "properties": {
                "size": {
                    "type": ["number", "null"]
                },
                "checksum": {
                    "type": ["string", "null"]
                },
                "external": {
                    "type": "boolean"
                },
                "status": {
                    "type": "string",
                    "enum": ["saving", "active", "pending_delete"]
                }
            },
            "required": ["size", "checksum", "external", "status"]
        }

  Artifact blob properties may have the following statuses:

  * *saving* - Artifact blob record created in table, blob upload started.

  * *active* - blob upload successfully finished.

  * *pending_delete* - indicates that blob will be deleted soon by Scrubber
    (if delayed delete is enabled) or by Glare itself.

.. list-table::  **Blob status transition table**
   :header-rows: 1

   * - Blob Status
     - saving
     - active
     - pending delete

   * - **saving**
     - X
     - finish blob upload
     - request for artifact delete

   * - **active**
     - N/A
     - X
     - request for artifact delete

   * - **pending_delete**
     - N/A
     - N/A
     - X

* *Artifact Dict and List* - compound generic property types that
  implement Dict or List interfaces respectively, and contain values of some
  primitive type, defined by ``element_type`` attribute.

* *Artifact visibility* - defines who may have an access to active artifact.
  Initially there are 2 options: 'private' artifact is accessible by its owner and
  admin only and 'public', when all users have an access to the artifact by default.
  When artifact is 'queued' its visibility is 'private'. It's allowed to change
  visibility only when artifact has 'active' status.

* *Artifact locking* - when artifact is *queued* all its properties
  are editable, but when it becomes *active* it is "locked" and cannot be modified
  (except for those properties explicitly declared as mutable).


**Use Case list**

* **Use Case 1.** Add Artifact type.

  *Pre-condition:* None.

  *Success condition:* New Artifact type has been added to Glare and it can be
  used by other OS users.

  *Steps:*

  1. Operator adds Artifact type class to ‘glare/objects’ folder.

  .. note:: Artifact types are pre-published in Glance repository. All of
     them will be reviewed and committed by Glance developers and reviewers.

  2. Operator implements all abstract methods and defines data API.

  .. note:: We are using image data API for image artifact type and common
     unified data API for other artifacts.

  3. Operator regenerates (with oslo config generator) or updates Glare
     configuration file to enable new Artifact type.

  4. Operator restarts Glare service, Glare validates new Artifact type.

  *Alternative scenarios:*

    4A. Artifact type validation failed - Glare won’t start.

* **Use Case 2.** Update Artifact type.

  *Pre-condition:* Artifact type supported by Glare
  (Artifact type class has been implemented).

  *Success condition:* Artifact type definition has been updated in Glare
   and it can be used by other OpenStack users. Old artifacts (that existed
   before update) are available to OpenStack users.


  *Steps:*

  1. Operator adds new field or update field in Artifact type class.

  2. Operator updates artifact type class (bump version) to cover support
     compatibility between database and new changes.

  3. Operator re-generates or updates Glare configuration file (if needed).

  4. Operator restarts Glare service, Glare validates updated Artifact type.

  *Alternative scenarios:*

    4A. Artifact type validation failed - Glare won’t start.

* **Use Case 3.** Disable artifact type.

  *Pre-condition*: Artifact type supported by Glare (Artifact type class has
   been implemented).

  *Success condition*: Artifact type definition has been updated in Glare and
   it can be used by other .

  *Steps:*

  1. Operator deletes artifact type name from Glare configuration file.

  2. Operator restarts Glare.

  *Alternative scenarios:*

  * None.

  .. note::

    Artifacts of disabled artifact type will be presented in database
    and all data will be in storage, but users won't be able to access
    those artifacts with Glare API.

* **Use Case 4.** List artifact types.

  *Pre-condition:* Running Glare API.

  *Success condition:* List of Artifact type definitions provided in that
   deployment to User.

  *Steps:*

  1. User requests list of supported Artifact types (GET /schemas).

  2. Glare checks Glare configuration, artifact type classes and generates
     JSON representation of artifact type.

  3. Glare returns the representation to the user (200 OK).

  *Alternative scenarios:*

  * None.

* **Use Case 5.** Get artifact type info.

  *Pre-condition:* Running Glare API.

  *Success condition:* Artifact type definition provided to User

  *Steps:*

  1. User requests Artifact type info
     (GET /schemas/{artifact_type}).

  2. Glare checks glare configuration, artifact type class and generates
     JSON schema

  3. Glare returns JSON schema to the user (200 OK).

  *Alternative scenarios:*

    2A. No Artifact type found with requested name (404 Not Found)

* **Use Case 6.** Create artifact.

  .. note:: No blob upload here. Only creating an Artifact entity in DB.

  *Pre-conditions:*
    * Artifact type definition has been added to Glare.

    * Artifact type is active in Glare.

    * User has a permission to create artifact.

  *Success condition:* Artifact entity has been created in Glare DB.

  *Steps:*

  1. User defines Artifact allowed properties and requests for Artifact
     creation (POST /artifacts/{artifact_type}).

  2. Glare checks Artifact the possibility of artifact creation.

  3. Glare creates Artifact entity in DB (only record in DB).

  4. Glare returns metadata of created artifact (201 Created).

  *Alternative scenarios:*

    2A. Property value is incorrect (400 Bad Request)

    2B. Property with name doesn’t exist (400 Bad Request)

    2C. Dependency format is incorrect (400 Bad Request)

    2D. Property is system (403 Forbidden)

    2E. Artifact type is not found (404 Not Found)

    2F. Artifact with required name and version already exists for
    this user (409 Conflict)

* **Use Case 7.** Upload Artifact binary data.

  *Pre-conditions:*

    * Artifact type definition has been added to Glare.

    * Artifact type is active in Glare.

    * Artifact instance has been successfully created.

    * User has enough quota space.

    * Artifact has ‘queued’ status.

  *Success condition:* Data is uploaded in storage, Artifact blob has been
   successfully crated and has status 'active'.

  *Steps:*

  1. User specifies Artifact identifier, blob property name, blob binary data,
     content-type as ``application/octet-stream`` and request upload
     (PUT /artifacts/{artifact_type}/{artifacts_id}/{blob_name}).

  2. Glare checks if Artifact identifier and blob property is valid.

  3. Glare creates a blob record in db, changes its status to 'saving' and
     associates the record with related Artifact blob property.

  4. Glare uploads blob binary to store back end.

  5. Glare sets all required metadata ('size', 'checksum' and so on) to the
     blob and changes its status to ‘active’.

  .. note:: Glare doesn’t use registry service, so do not need trusts here.

  6. Glare responds with 200 OK.

  *Alternative scenarios:*

    2A. No artifact found (404 Not Found).

    2B. No blob property found (400 Bad Request).

    2C. Metadata is not valid (400 Bad Request).

    3C. Blob is already uploaded and has status ‘active’ (409 Conflict)

    3D. Blob is saving (409 Conflict).

    4A. Artifact quota per tenant exceed (413 HTTPRequestEntityTooLarge).

    4B. Blob upload failed. Glare initiates Blob killing and responds with
    appropriate error (depends on backend error).

* **Use Case 8.** Add a custom location for artifact.

  *Pre-conditions:*

    * Artifact type definition has been added to Glare.

    * Artifact type is active in Glare.

    * Artifact instance has been successfully created.

    * Artifact has ‘queued’ status.

  *Success condition:* blob location has been successfully added to Artifact.

  *Steps:*

  1. User specifies Artifact identifier, blob property name, location,
     content-type as ``application/json`` and sends the request
     (PUT /artifacts/{artifact_type}/{artifacts_id}/{blob_name}).

     * Body:

        .. code-block:: javascript

            {"url": "<some_url>"}

  2. Glare checks if Artifact identifier and blob property name is valid.

  3. Glare checks given location, creates blob record in db, associate it
     with Artifact and adds location to blob.

  4. Glare changes blob property status to active.

  5. Glare responds with 200 OK.

  *Alternative scenarios:*

    2A. No artifact found (404 Not Found).

    2B. No property found (400 Bad Request).

    3A. Location url is not valid (400 Bad Request).

    3B. Location url is not downloadable (400 Bad Request).

    3C. Blob record is already exists (409 Conflict).

* **Use Case 9.** Activate Artifact.

  *Pre-conditions:*

    * Artifact type definition has been added to Glare.

    * Artifact type is active in Glare.

    * Artifact instance has been successfully created.

  * Success condition:* Artifact is activated in Glare (status is 'active').

  *Steps:*

  1. User defines Artifact id and requests Artifact activation
     (PATCH /artifacts/{artifact_type}/{artifacts_id}).

     * Body:

        .. code-block:: javascript

            [{
                "op": "replace",
                "path": "/status",
                "value": "active"
            }]

  2. Glare checks if all required Artifact properties specified according
     to Artifact definition.

  3. Glare checks if all required blob properties are active according
     to Artifact definition.

  4. Glare checks if all Artifact dependencies are correct.

  5. Glare activates Artifact so it becomes visible to other Users and
     returns response (200 OK).

  *Alternative scenarios:*

    2-4A. some obligatory properties or blobs were not specified, dependencies
    are not correct (no dependency found by url or there are multiple
    artifacts per dependency) (400 Bad Request).

    2B. Artifact doesn’t exist or deleted (404 Not Found).

* **Use Case 10A.** Update Artifact non-blob property, Artifact is queued.

  *Pre-conditions:*

    * Artifact type definition has been added to Glare.

    * Artifact type is active in Glare.

    * Artifact instance has been successfully created.

  *Success condition:* Artifact property has been updated in Glare.

  *Steps:*

  1. User requests for Artifact property, blob property or dependency update
     (PATCH /artifacts/{artifact_type}/{artifacts_id}).

  2. Glare updates required properties and returns updated artifact (200 OK).

  *Alternative scenarios:*

    2A. Dependency url is not correct or downloadable (400 Bad Request).

    2B. Artifact doesn’t exist or deleted (404 Not Found).

    2C. Parameter is incorrect (400 Bad Request).

    2D. Property is system (403 Forbidden).

    2E. Artifact with updated name and version already exists for
    this user (409 Conflict).

* **Use Case 10B.** Update Artifact non-blob property, Artifact is active.

  *Pre-conditions:*

    * Artifact type definition has been added to Glare.

    * Artifact type is active in Glare.

    * Artifact instance has been successfully created.

  *Success condition:* Artifact has been updated in Glare.

  *Steps:*

  1. User requests for Artifact property or dependency update
     (PATCH /artifacts/{artifact_type}/{artifacts_id}).

  2. Glare checks if dependency is mutable and can be updated.

  3. Glare checks if property is mutable and can be updated.

  4. Glare updates required properties (200 OK).

  *Alternative scenarios:*

    2A. Dependency property is immutable (403 Forbidden).

    2B. Dependency url is not correct or downloadable (400 Bad Request).

    3A. Property is immutable (403 Forbidden).

    3B. Parameter is incorrect (400 Bad Request).

* **Use Case 11.** Download blob.

  *Pre-conditions:*

    * Artifact type definition has been added to Glare.

    * Artifact type is active in Glare.

    * Artifact instance has been successfully created.

  *Success condition:* Blob is downloaded.

  *Steps:*

  1. User provides blob property name and Artifact identifier
     (GET /artifacts/{artifact_type}/{artifacts_id}/{blob_name}).

  2. Glare provides Artifact binary stream to the User (200 OK).

  *Alternative scenarios:*

    2A. Artifact blob contains no data (204 No Content).

    2B. Artifact blob has status 'saving' (204 No content).

    2C. Download is not successful (depends on backend error).

    2D. Artifact is deactivated and user doesn't have a permission
        to download (403 Forbidden)

* **Use Case 12.** Get Artifact info

  *Pre-conditions:*

    * Artifact type definition has been added to Glare.

    * Artifact type is active in Glare.

    * Artifact instance has been successfully created.

  *Success condition:* Artifact definition returned to User.

  *Steps:*

  1. User requests for Artifact info with artifact identifier and artifact type
     (GET /artifacts/{artifact_type}/{artifacts_id}).

  2. Glare returns Artifact properties, blobs information and dependency
     information (200 OK).

  *Alternative scenarios:*

    2A. No grants to view artifacts (403 Forbidden).

    2B. No artifact or artifact type found (404 Not Found).

* **Use Case 13.** Deactivate Artifact.

  *Pre-conditions:*

    * Artifact type definition has been added to Glare.

    * Artifact type is active in Glare.

    * Artifact instance has been successfully created.

  *Success condition:* Artifact status is deactivated.

  *Steps:*

  1. User sends a request to deactivate artifact
     (PATCH /artifacts/{artifact_type}/{artifacts_id}).

     * Body:

        .. code-block:: javascript

            [{
                "op": "replace",
                "path": "/status",
                "value": "deactivated"
            }]

  .. note:: access to the deactivation is managed by oslo policy.

  2. Glare changes status of artifact from active to deactivated (200 OK).

  .. note:: current dependencies are soft dependencies. So no integrity check
     between artifacts here.

  *Alternative scenarios:*

    2A. Artifact status is not active (400 Bad Request).

    2B. User doesn’t have permission to deactivate artifact (403 Forbidden).

* **Use Case 14.** Reactivate Artifact.

  *Pre-conditions:*

    * Artifact type definition has been added to Glare.

    * Artifact type is active in Glare.

    * Artifact instance has been successfully created.

  *Success condition:* Artifact is active.

  *Steps:*

  1. User sends a request to re-activate Artifact
     (PATCH /artifacts/{artifact_type}/{artifacts_id}).

     * Body:

        .. code-block:: javascript

            [{
                "op": "replace",
                "path": "/status",
                "value": "active"
            }]

  .. note:: access to the deactivation is managed by oslo policy.

  2. Glare changes status of Artifact from deactivated to active
     (200 OK).

  *Alternative scenarios:*

    2A. Artifact status is not deactivated (400 Bad Request).

    2B. User doesn’t have permission to reactivate artifact (403 Forbidden).

* **Use Case 15.** Publish Artifact.

  *Pre-conditions:*

    * Artifact type definition has been added to Glare.

    * Artifact type is active in Glare.

    * Artifact instance has been successfully created.

    * Artifact status is 'active'.

  *Success condition:* Artifact is published (i.e. artifact visibility is
  *public*).

  *Steps:*

  1. User sends a request to publish Artifact
     (PATCH /artifacts/{artifact_type}/{artifacts_id})

     * Body:

        .. code-block:: javascript

            [{
                "op": "replace",
                "path": "/visibility",
                "value": "public"
            }]

  2. Glare changes visibility of Artifact from 'private' to 'public'
     (200 OK).

  *Alternative scenarios:*

    2A. Artifact status is not 'active' (400 Bad Request).

    2B. User doesn’t have permission to publish artifact (403 Forbidden).

    2C. Public artifact with required name and version already exists
    (409 Conflict).

* **Use Case 16.** List Artifacts.

  *Pre-conditions:*

    * Artifact type definition has been added to Glare.

    * Artifact type is active in Glare.

  *Success condition:* List of artifacts returned to User.

  *Steps:*

  1. User request for Artifact list with specified artifact type, limit,
     marker, filters (GET /artifacts/{artifact_type}).

  2. Glare returns all Artifacts to the User (200 OK).

  *Alternative scenarios:*

    2A. Number of Artifacts is too large (400 Bad Request)
    (use limit to restrict number of Artifacts in response).

    2B. Query params is invalid (sorting or filtering by non-existing key)
    (400 Bad Request).

* **Use Case 17.** Delete artifact.

  *Pre-conditions:*

    * Artifact type definition has been added to Glare.

    * Artifact type is active in Glare.

    * Artifact instance has been successfully created.

  *Success condition:* Artifact has been successfully deleted from Glare.

  *Steps:*

  1. User requests Artifact delete with Artifact type and Artifact identifier
     (DELETE /artifacts/{artifact_type}/{artifacts_id}).

  2. Glare updates artifact status to 'deleted' and set all artifact's blobs
  statuses to 'pending_delete'.

  .. note:: no dependency consistency check here.

  3. Glare deletes all artifact's custom properties and tags.

  4. Glare sequentially deletes blob data from store and removes blob instances
  from db.

  5. Glare responds 204 No Content.

  *Alternative scenarios:*

    2A. Some blob is uploading. Glare finishes uploading of the blob and
    deletes it immediately.

    2B. Some blob is downloading. It depends on the store backend, in common
    case downloading will be canceled.

    4A. There was a storage error during blob deleting. Glare stops blob deleting,
    user have to remove them from Store with Scrubber.

    4B. 'delayed_delete' config option is enabled. Glare does nothing and returns
    204 No Content. Blob data should be removed later with Scrubber.

* **Use Case 18.** Add Artifact tag.

  *Pre-conditions:*

    * Artifact type definition has been added to Glare.

    * Artifact type is active in Glare.

    * Artifact has been successfully created.

  *Success condition:* Artifact tag has been successfully added to Artifact.

  *Steps:*

  1. User specifies tag name and Artifact identifier and sends request.
     (PUT /artifacts/{artifact_type}/{artifacts_id}/tags/{tag_value})

  2. Glare adds tag to the Artifact (200 OK).

  *Alternative scenarios:*

    2A. Tag is already exist (200 OK).

    2B. Artifact does not exist (404 Not Found).

* **Use Case 19.** Delete Artifact tag.

  *Pre-conditions:*

    * Artifact type definition has been added to Glare.

    * Artifact type is active in Glare.

    * Artifact has been successfully created.

  *Success condition:* Artifact tag has been successfully removed
  from Artifact.

  *Steps:*

  1. User specifies tag name and Artifact identifier and sends request.
     (DELETE /artifacts/{artifact_type}/{artifacts_id}/tags/{tag_value}).

  2. Glare removes tag from Artifact (204 No Content).

  *Alternative scenario:*

    2A. Tag or Artifact does not exist (404 Not Found).

Alternatives
------------

We need to address API-WG and DefCore comments anyway, so there are no
alternatives here.

Data model impact
-----------------

No data model impact.

REST API impact
---------------

All API calls are placed under the */artifacts/{artifact_type}* branch,
where artifact_type is a constant defined by the Artifact Type, which
usually should be plural of the artifact type name. For example, for
artifacts of type "template" this constant should be called 'templates',
so the API endpoints will start with */artifacts/templates*.

Glare API complies with OpenStack API-WG guidelines:

  * `Filtering, sorting and pagination
    <https://github.com/openstack/api-wg/blob/master/guidelines/
    pagination_filter_sort.rst>`_

  * `Tags
    <https://specs.openstack.org/openstack/api-wg/guidelines/tags.html>`_

  * `Errors
    <http://specs.openstack.org/openstack/api-wg/guidelines/errors.html>`_

For updating artifact properties Glare API uses `json-patch
<http://jsonpatch.com/>`_

Glare supports microversions to define what API version it should use:
`API-WG microversion guidelines <http://specs.openstack.org/openstack/
api-wg/guidelines/microversion_specification.html>`_

**Info**

  * **list of available API versions**

    GET /

    Returns json representation of the minimum and maximum API versions.
    Code 200 OK

  * **list of available artifact types schemas**

    GET /schemas

    Returns json representation of all active artifact types. Code 200 OK

  * **description of artifact type**

    GET /schemas/{artifact_type}

    Returns json schema of given artifact type. Code 200 OK

**Artifacts**

  * **list of artifacts with given type name**

    GET /artifacts/{artifact_type}

    Returns json representation of list of artifacts. Code 200 OK.

    .. note::
       These requests support query parameters that comply with
       `API-WG filtering, sorting and pagination guidelines
       <https://github.com/openstack/api-wg/blob/master/
       guidelines/pagination_filter_sort.rst>`_

  * **create an artifact of the given type name**

    POST /artifacts/{artifact_type}

    Returns info about created instance in json format. Code 201 Created.

  * **show artifact**

    GET /artifacts/{artifact_type}/{artifacts_id}

    Returns info about artifact with given ID in json format. Code 200 OK.

  * **update artifact**

    PATCH /artifacts/{artifact_type}/{artifacts_id}

    Returns updated artifact info in json format. Code 200 OK.

  * **delete artifact**

    DELETE /artifacts/{artifact_type}/{artifacts_id}

    Code 204 No Content.

**Blobs**

  * **upload file to artifact**

    PUT /artifacts/{artifact_type}/{artifacts_id}/{blob_name}

    Code 200 OK.

  * **download file from artifact**

    GET /artifacts/{artifact_type}/{artifacts_id}/{blob_name}

    Returns binary stream of requested blob. Code 200 OK

**Tags**

  .. note::
   These requests comply with `API-WG tags guidelines
   <https://specs.openstack.org/openstack/api-wg/guidelines/tags.html>`_

  * **add a tag to artifact**

    PUT /artifacts/{artifact_type}/{artifacts_id}/tags/{tag_name}

    Code 200 OK.

  * **remove a tag from artifact**

    DELETE /artifacts/{artifact_type}/{artifacts_id}/tags/{tag_name}

    Code 200 OK.

  * **delete all tags from artifact**

    DELETE /artifacts/{artifact_type}/{artifacts_id}/tags

    Code 204 No Content.

  * **replace list of tags for artifact**

    PUT /artifacts/{artifact_type}/{artifacts_id}/tags

    Code 200 OK.

  * **get list of tags for artifact**

    GET /artifacts/{artifact_type}/{artifacts_id}/tags

    Code 200 OK.


**Examples of API requests**

   For example, we have an artifact type 'example_type' with properties:

    * id: StringField

    * name: StringField

    * visibility: StringField

    * status: StringField

    * blob_file: BlobField

    * metadata: DictOfStringsField

    * version:  VersionField

    1. Create artifact

      Request:

        * Method: POST

        * URL: http://host:port/artifacts/example_type

        * Body:

            .. code-block:: javascript

              {
                 "name": "new_art"
              }

      Response:

          201 Created

          .. code-block:: javascript

               {
                    "status": "queued",
                    "name": "new_art",
                    "id": "art_id1",
                    "version": null,
                    "blob_file": null,
                    "metadata": {},
                    "visibility": "private"
                }

    2. Get artifact

      Request:

        * Method: GET

        * URL: http://host:port/artifacts/example_type/art_id1

      Response:

          200 OK

          .. code-block:: javascript

            {
                "status": "queued",
                "name": "new_art",
                "id": "art_id1",
                "version": null,
                "blob_file": null,
                "metadata": {},
                "visibility": "private"
            }

    3. List artifacts

      Request:

        * Method: GET

        * URL: http://host:port/artifacts/example_type

      Response:

          200 OK

          .. code-block:: javascript

            {
                "example_type": [{
                    "status": "queued",
                    "name": "new_art",
                    "id": "art_id1",
                    "version": null,
                    "blob_file": null,
                    "metadata": {},
                    "visibility": "private"
                }, {
                    "status": "queued",
                    "name": "old_art",
                    "id": "art_id2",
                    "version": null,
                    "blob_file": null,
                    "metadata": {},
                    "visibility": "private"
                }, {
                    "status": "queued",
                    "name": "old_art",
                    "id": "art_id3",
                    "version": null,
                    "blob_file": null,
                    "metadata": {},
                    "visibility": "private"
                }],
                "first": "/artifacts/example_type",
                "schema": "/schemas/example_type"
            }

      Request:

        * Method: GET

        * URL: http://host:port/artifacts/example_type?name=eq:old_art

      Response:

          200 OK

          .. code-block:: javascript

            {
                "example_type": [{
                    "status": "queued",
                    "name": "old_art",
                    "id": "art_id2",
                    "version": null,
                    "blob_file": null,
                    "metadata": {},
                    "visibility": "private"
                }, {
                    "status": "queued",
                    "name": "old_art",
                    "id": "art_id3",
                    "version": null,
                    "blob_file": null,
                    "metadata": {},
                    "visibility": "private"
                }],
                "first": "/artifacts/example_type?name=ne%3Anew_name",
                "schema": "/schemas/example_type"
            }

    4. Update artifact

      Request:

        * Method: PATCH

        * URL: http://host:port/artifacts/example_type/art_id1

        * Body:

            .. code-block:: javascript

                [{
                    "op": "replace",
                    "path": "/name",
                    "value": "stark"
                }, {
                    "op": "add",
                    "path": "/metadata/slogan",
                    "value": "winter is coming"
                }]

      Response:

          200 OK

          .. code-block:: javascript

            {
                "status": "queued",
                "name": "stark",
                "id": "art_id1",
                "version": null,
                "blob_file": null,
                "metadata": {
                    "slogan": "winter is coming"
                },
                "visibility": "private"
            }

    5. Upload blob

      Request:

        * Method: PUT

        * URL: http://host:port/artifacts/example_type/art_id1/blob_file

        * Body:

          What Is Dead May Never Die

      Response:

          200 OK

          .. code-block:: javascript

            {
                "status": "queued",
                "name": "stark",
                "id": "art_id1",
                "version": null,
                "metadata": {
                    "slogan": "winter is coming"
                },
                "blob_file": {
                    "status": "active",
                    "checksum": "8452e47f27b9618152a2b172357a547d",
                    "external": false,
                    "size": 16
                },
                "visibility": "private"
            }

    6. Download blob

      Request:

        * Method: GET

        * URL: http://host:port/artifacts/example_type/art_id1/blob_file

      Response:

          200 OK

          What Is Dead May Never Die

    7. Activate artifact

      Request:

        * Method: PATCH

        * URL: http://host:port/artifacts/example_type/art_id1

        * Body:

           .. code-block:: javascript

                [{
                    "op": "replace",
                    "path": "/status",
                    "value": "active"
                }]

      Response:

          200 OK

          .. code-block:: javascript

            {
                "status": "active",
                "name": "stark",
                "id": "art_id1",
                "version": null,
                "metadata": {
                    "slogan": "winter is coming"
                },
                "blob_file": {
                    "status": "active",
                    "checksum": "8452e47f27b9618152a2b172357a547d",
                    "external": false,
                    "size": 16
                },
                "visibility": "private"
            }

    8. Deactivate artifact

      Request:

        * Method: PATCH

        * URL: http://host:port/artifacts/example_type/art_id1

        * Body:

           .. code-block:: javascript

                [{
                    "op": "replace",
                    "path": "/status",
                    "value": "deactivated"
                }]

      Response:

          200 OK

          .. code-block:: javascript

            {
                "status": "deactivated",
                "name": "stark",
                "id": "art_id1",
                "version": null,
                "metadata": {
                    "slogan": "winter is coming"
                },
                "blob_file": {
                    "status": "active",
                    "checksum": "8452e47f27b9618152a2b172357a547d",
                    "external": false,
                    "size": 16
                },
                "visibility": "private"
            }

    9. Reactivate artifact

      Request:

        * Method: PATCH

        * URL: http://host:port/artifacts/example_type/art_id1

        * Body:

           .. code-block:: javascript

                [{
                    "op": "replace",
                    "path": "/status",
                    "value": "active"
                }]

      Response:

          200 OK

          .. code-block:: javascript

            {
                "status": "active",
                "name": "stark",
                "id": "art_id1",
                "version": null,
                "metadata": {
                    "slogan": "winter is coming"
                },
                "blob_file": {
                    "status": "active",
                    "checksum": "8452e47f27b9618152a2b172357a547d",
                    "external": false,
                    "size": 16
                },
                "visibility": "private"
            }

    10. Publish artifact

      Request:

        * Method: PATCH

        * URL: http://host:port/artifacts/example_type/art_id1

        * Body:

           .. code-block:: javascript

                [{
                    "op": "replace",
                    "path": "/visibility",
                    "value": "public"
                }]

      Response:

          200 OK

          .. code-block:: javascript

            {
                "status": "active",
                "name": "stark",
                "id": "art_id1",
                "version": null,
                "metadata": {
                    "slogan": "winter is coming"
                },
                "blob_file": {
                    "status": "active",
                    "checksum": "8452e47f27b9618152a2b172357a547d",
                    "external": false,
                    "size": 16
                },
                "visibility": "public"
            }

    11. Delete artifact

      Request:

        * Method: DELETE

        * URL: http://host:port/artifacts/example_type/art_id1

      Response:

          204 No Content

Security impact
---------------

No security impact

Notifications impact
--------------------

No notification impact

Other end user impact
---------------------

The new API will need the client support. The support of the
Glare API v0.1 may be removed at the same moment when v1 support is added or
at any moment afterwards.

Performance Impact
------------------

No performance impact


Other deployer impact
---------------------

The Glare service will follow the Glance release cycle. It's expected that
artifact type updating, however, will proceed more quickly than a 6 month
cycle. Thus we want to make it possible to update artifact types more
frequently, but in a controlled manner that will be easy for deployers.

We propose to address this situation by creating a single new repository
where all new glare-objects (Artifact types) will go. It will either be a
oslo-inc style library, but preferably a non-client OpenStack library which
can be released to pip and the Glare objects can be then pulled into Glance
repository using the right upper constraints per branch and at the same time
adhere to the OpenStack packaging fundamentals.

The motivation, intent and purpose behind creating this new separate repo for
library is to form a organized way for OpenStack wide cross-project developers
to contribute to custom artifact object types and provide a consistent feedback.
At the same time, common code can be shared by the glare-objects and best
practices can be documented in the same place.

Release of all the glare objects will be precise with that of glance
requirements and testing can be done comprehensively for all custom objects
in the same release of the library (irrespective if subset of objects have had
changes or not). This should ease the packaging pain and avoid operator/upgrade
mess.

Developer impact
----------------

As the library would be a OpenStack non-client library, it would require
privileged access to the source code from non-regular glance developers
who are primarily working on projects like Murano or Heat, and so on.

We would need to establish some common code and best practices for developers
in this repository.

Since the Glare v 0.1 API is EXPERIMENTAL, developers should be prepared for
its deprecation.


Implementation
==============

Assignee(s)
-----------

Primary assignee: mfedosin

Other contributors:
  kkushaev
  dshakhray
  nikhil-komawar

Reviewers
---------
Glance core team because we need to spread the knowledge about Glare
to whole team.

Work Items
----------

* Add new API router and controllers. Mark v1 as **EXPERIMENTAL**

* Write helper methods to implement query parameter parsing (e.g. for
  filtering, sorting, tags etc, according to API-WG guidelines)

* Cover stable API with unit and functional tests.

* Set v0.1 API as **DEPRECATED** and v1 as **STABLE**.

* Implement Glare v1 client


Dependencies
============

The work on separating Glare API from Glance API (i.e. the transition from
Glance v3 to Glare v0.1), defined in spec [6] should be completed first.


Testing
=======

Glare api should be covered by functional and unit tests. Integration tests
with Tempest should be implemented as well.


Documentation Impact
====================

Glare API, configuration options and policies should be documented.

A new document - "Artifact type developers guide" has to be added.


References
==========

#. `OpenStack Image API v2 reference <http://developer.openstack.org/api-ref-image-v2.html>`_

#. `Initial spec <https://specs.openstack.org/openstack/glance-specs/specs/kilo/artifact-repository.html>`_

#. `Summary of API issues identified by API-WG <https://etherpad.openstack.org/p/glance-artifacts-api-issues>`_

#. `Filtering and sorting API-WG guideline <http://specs.openstack.org/openstack/api-wg/guidelines/pagination_filter_sort.html>`_

#. `Tags API-WG guideline <https://github.com/openstack/api-wg/blob/master/guidelines/tags.rst>`_

#. `Errors API-WG guideline <http://specs.openstack.org/openstack/api-wg/guidelines/errors.html>`_

#. `Description of type-version issue <https://etherpad.openstack.org/p/glance-v3-open-issues>`_

#. `Glare v0.1 transition spec <https://review.openstack.org/#/c/254163/>`_

#. `json-patch description <http://jsonpatch.com/>`_

#. `how to install Glare on devstack <https://docs.google.com/document/d/1KyY8VB00XvehtpBcLDo_Andx0BDgG-C7E_TdhfvcGv4/edit?usp=sharing>`_
