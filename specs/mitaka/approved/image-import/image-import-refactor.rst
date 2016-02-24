..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=====================
Image Import Refactor
=====================

https://blueprints.launchpad.net/glance/+spec/image-import-refactor

In this spec we propose a refactoring of the current Glance image import
process to meet the criteria of being discoverable, interoperable, and
flexible.  The goal is to present a uniform interface for image import that
will satisfy the requirements of public and private clouds of various sizes.

.. note:: This spec is based on ideas expressed in mailing list
          discussions (see [OSM1]_, [OSM2]_), a meeting in
          #openstack-glance (see [OSL1]_, [OSE2]_), a video
          meeting of interested people (summarized in [OSW3]_), and
          a session at the Mitaka design summit [OSE3]_.  It
          does not, however, reproduce all the discussion that took
          place, so the interested reader may wish to glance through
          those documents to gain wider context.

As a basis for the discussion to follow, *image import* is described by the
following use case:

  A cloud end-user has a bunch of bits that they want to give to Glance in the
  expectation that (in the absence of error conditions) Glance will produce an
  Image (record, file) tuple that can subsequently be used by other OpenStack
  services that consume Images.

Among the motivations for the above use case are:

* An end user creates a specialized custom image offline and wants to use it in
  various OpenStack clouds.

* A particular cloud may not offer a public image of some Excellent But Obscure
  Operating System (EBOOS).  The EBOOS User Group could make a VM image
  available on its website, and EBOOS enthusiasts could import it into the
  OpenStack cloud of their choice.

* An end user finds an interesting image in the OpenStack App Catalog and wants
  to boot instances from it in an OpenStack cloud.

* An end user creates a snapshot of an instance in one OpenStack cloud and
  wants to boot instances from it in another OpenStack cloud.  (Obviously, this
  would require image export as well.)

.. note:: Image Creation in OpenStack Clouds

          It's worth distinguishing three distinct use cases around image
          creation:

          #. A deployer wishes to create public images that end users may use
             to boot instances.

          #. Another OpenStack service creates an image from some other
             resource it manages (for example, Nova creates an image of a
             server, or Cinder creates an image from a volume) at the behest
             of an end user.

          #. An end user wishes to import an image.

          Glance should support all three scenarios.

Background
==========

Glance contains a "tasks" API that is a result of discussions during and after
the Havana design summit (see [OSD1]_, [OSW2]_, and [OSW1]_).  This API was
designed to present a uniform interface to end-users that allowed a large
degree of customization by individual cloud providers, and currently defines an
'import' task.  Since the Havana design summit, however, the DefCore movement
in OpenStack has developed as a means of ensuring interoperability among
OpenStack branded clouds.  The current Glance tasks API is too customizable to
be suitable for DefCore purposes, and in fact, does not fare well when assessed
on the dimensions of interoperability and discoverability.

The primary problem with tasks as defined in the current API is that they have
an "input" element, defined in the task schema as a JSON blob, whose exact
content is left up to the cloud deployer.  This allows for flexibility on the
part of a cloud deployer, but introduces a discoverability problem, as the only
mechanism currently available for determining acceptable content of the "input"
element is the deployer's documentation.  While some flexibility is good, this
much flexibility makes it impossible for a competent end-user of one OpenStack
cloud to be sure this competence extends to a different OpenStack cloud.

One goal of this spec is to implement image import in such a way that it will
be a suitable candidate for inclusion in DefCore.  (See [OSR1]_ for the list of
12 criteria for being included in DefCore Guidelines.)

.. note :: Currently, Glance is included in two DefCore programs: "OpenStack
   Powered Compute" and "OpenStack Powered Platform". (See [OSO1]_ for a
   definition of these terms.)

Current Upload Workflow
=======================

Here's a quick reminder of the current image upload workflow.

#. ``POST v2/images``

   This creates an image record and returns an Image response containing (among
   other things) an 'id' field.  (The image record can be modified by PATCH
   calls, but we'll ignore that here.)  The key thing is that a record must be
   created so that the user has an image_id to work with for the purposes of
   uploading the actual image bits.

#. ``PUT v2/images/{image_id}/file``

   This call instructs Glance to accept the incoming image data and place it
   into the storage backend.  The associated image record must have the
   ``container_format`` and ``disk_format`` properties set or the call will not
   succeed.  This call returns no content.

This current image upload workflow will still exist for backward compatibility
and for use by Glance administrators and trusted OpenStack services.

Problem description
===================

For reasons set out in [OSW3]_ and [OSE1]_, it is desirable for deployers to
have the ability easily to separate untrusted end-user image import from the
simple upload facility used by trusted sources (typically, Nova or another
OpenStack service, or Glance administrators supplying public images for use in
a cloud).  What we aim to do in this spec is to define a suitable end-user
image import mechanism that will satisfy the requirements of all OpenStack
clouds, whether small or large, public or private.

Summary of the Constraints Around This Project
==============================================

Here are, to the best of my recollection, what was agreed upon between the
Glance community, DefCore (mostly Doug Hellman), infra (mostly Monty), and
various interested parties who showed up at the design session on image import
at the Tokyo summit.

First, background, so you can see what problems needed to be addressed:

#. (At least some) Public cloud operators do not want to expose the current
   glance v1/v2 image upload as it is too fragile.

#. The TC passed a resolution in December 2015 [NEW1]_ saying that end user
   image upload (what we -- following industry parlance -- are calling "image
   import") must be available in OpenStack clouds.

   #. The TC resolution says that an OpenStack cloud should support import of a
      vanilla linux image; no mandate about image format, size, etc.

   #. Part of the goal of this spec is design a discoverable and interoperable
      API for image import so that the TC resolution can be satisfied and image
      import can be included as a DefCore requirement.  (See [NEW2]_ for more
      about this point.)

#. The "Tasks" API is a disaster from the interoperability and discoverability
   standpoint.  (We know this because at least one large public cloud has
   exposed image import via Glance Tasks, and the openstack infra team has a
   lot to say about how bad it is.  Just ask them.)

   #. interoperability failures: The Task object, as defined by
      ``v2/schemas/task`` contains an "input" and "result" element which are
      defined to be JSON blobs; anything could go in there, so possibly
      radically different stuff for each OpenStack cloud

   #. discoverability failures: You don't have to support a particular
      disk/container format, but there must be a way to find out what a
      particular cloud supports (and this "way" should be the same for all
      openstack clouds, and no, documentation doesn't count)

#. There are three cases for "image upload" that Glance should support.

   #. Admin upload of "base" or "public" images

   #. Image upload from OpenStack services (for example, Nova or Cinder)

   #. End user image import

.. note:: My view is that we are working on the image import use case, and what
          we come up with there could, but doesn't have to, be used/usable for
          the other two use cases.  The key point to keep in mind here is that
          the discovery of various vulnerabilities may cause operators to halt
          import (temporarily), and they will want to do that while still
          keeping the other 2 use cases operational.

          As Doug pointed out on a previous patch: "It would be nice to have
          only one API, but the hole we have right now is the public-facing use
          case and so that's where the focus of this work should be. If we can
          make the results work for the other cases, that's a bonus, but not
          required."

OK, without further ado, here's what was agreed upon:

The constraints that an adequate image import solution must meet
----------------------------------------------------------------

#. There must be a well-defined image import structure/framework that should be
   supportable by all OpenStack clouds.

   #. "well-defined"

      #. calls have request/response schemas that are discoverable

      #. the values that will enable a client to have a successful image import
         (e.g., supported formats) must be discoverable

      #. "discoverable" == via API call (in what Flavio calls a
         "follow-your-nose" fashion)

         #. specific API request: this would be the ``GET v2/info/import`` call

         #. available in headers: the headers would be returned with the ``POST
            v2/images`` response.  The idea is that the content of that
            response is the JSON representation of the Image record (so the
            import methods available and other associated import information
            don't really belong in a particular ``image`` resource), and having
            the info come back in the headers could allow a client to determine
            the import method to use without having to make the discovery call.

   #. "supportable by all OpenStack clouds"

      #. it's acceptable for there to be multiple import methods as long as
         each is well defined.  (See the "Proposed Change" section below for
         details.  An "import method" has to do with how the image data is
         delivered to Glance.  The API calls won't change, and their body and
         structure will remain the same for the various methods.)

      #. no cloud has to support all import methods, but it's expected that to
         achieve certification as "OpenStack Powered Compute" (and hence, to
         even have a shot at certification as an "OpenStack Powered Platform"),
         a cloud must expose at least one of these.

   #. Since Swift is not part of the "OpenStack Powered Compute" program,
      Glance must expose at least one import method that does not rely upon the
      presence of an end-user-accessible object store.

#. The "three step dance" import style was deemed acceptable

   #. one: create image record, two: upload data, three: import call

   #. steps one and two can be independent.  For example, in the 'swift-local'
      method sketched out below, an end user could upload the image data to
      swift first (accomplishing step two), then do step one, followed by step
      three.

#. The import workflow should allow for server-side operator customization, but
   no operator is required to perform such customization.

   #. We're talking about customization in processing the uploaded data.  The
      API request/response structure is not customizable.

Proposed change
===============

Import Workflow
---------------

The import workflow will respect the basic structure of the current upload
workflow described above.

#. End user creates an image record.  (We'll refer to this as *image-create*,
   just keep in mind that what's created is only the image *record*.)

#. End user makes the data available to Glance.  (This could be via direct
   upload, or via some other well-defined import method that is discoverable by
   an end user.)

#. End user instructs Glance to process the data and create a bootable image.

A key distinction between image upload and image import is that imported images
are not immediately available for use, that is, they are not 'active' at the
completion of the data PUT call.  This allows deployers optionally to process
the image data (for example, by performing a validation process) before the
image becomes 'active'.  Additionally, deployers may need to put protected
properties on the image record at this point.  Thus the import call needs to be
asynchronous.

Discovery
---------

An end user needs to be able to do the following:

#. value discovery

   The end user needs to determine what container format and disk format are
   accepted by this cloud, the maximum allowed image size (both actual and
   virtual), what import methods are available.

#. method discovery

   The end user wants to know what import methods this site supports.  Although
   this information will be returned in the value discovery call described
   above, we also propose to return it in a response header from the call used
   to create the image record.  This way, a client is not required to make the
   value discovery call as part of the image import workflow.

#. format discovery

   The end user wants to know what an import request body looks like.  This
   information will be provided by a JSON schema.

We assume that the user already knows how to discover the image schema for the
purposes of creating an image and reading an image response.

Import methods
--------------

We define one initial import method, ``glance-direct``, but we envision more
methods such as ``swift-local``.  (We include ``swift-local`` in the discussion
throughout so that it's clear how the import scheme described in this spec can
be extended in an interoperable way to include other ways of getting the image
data into Glance).

.. note:: We might want to use different terms here that would expose less
          internals to the users. For instance, we could just use ``direct``
          and ``indirect`` as recommended by Steve Lewis in PS8.  We can
          discuss the name during development and amend this spec
          appropriately.

``glance-direct``
   The end-user does a PUT of image data directly to Glance using a URL
   included in a response header to the image-create request.  (The URL will
   also be known by convention, namely, ``v2/images/{image_id}/stage``.
   After the data has been uploaded, the end-user follows with a call to Glance
   to process the data and complete the import.

``swift-local``
   The end-user places the image data in the user's object store account.  Data
   placement may occur before or after the image record is created.  After the
   data has been uploaded and an image record is created, the end-user makes a
   call to Glance to process the data and complete the import.

A particular Glance installation does not have to support all methods, but
it's expected that it will expose at least one.

.. note:: I'm trying to get by without giving the end-user any visibility into
          the staging area (formerly, the "bikeshed").  But see the discussion
          initiated by Stuart at line 207 in Patch Set 7 about separation of
          concerns and the example of Amazon's s3 "multipart upload".

API changes
-----------

value discovery
***************

``GET v2/info/import``

The response is an object in JSON notation.  This document should provide an
end-user with sufficient information to perform an image import.

.. literalinclude:: value-discovery-response.json
    :linenos:
    :language: json

.. note :: Should we allow users for sending `target_*` fields?

   Suppose the end-user needs the image to be in a different format to use a
   particular flavor or availability zone. We could handle this by introducing
   a conversion task (out of scope for this spec, however), where end-user
   specifies an existing image and requests that an new image be created in a
   specific supported format (where "supported" format depends on the
   cloud). This would allow decoupling among:

   * what image formats are actually in use in the cloud
   * what image formats are supported for import
   * what image formats are supported for conversion

   It would be good to have such decoupling because:

   * the in-use formats depend on what kind of hypervisors you have and what
     format they prefer
   * the import formats depend on what formats you are confident your screening
     processes are adequate for
   * the conversion formats depend on what you're confident will convert
     correctly

summary
^^^^^^^

* Method type: GET
* Normal http response code(s): 200 (OK)
* Expected error http response code(s): 400, 401, 405
    * 400: request body passed
    * 401: unauthorized
    * 405: only GET supported for this call
* URL for the resource: ``v2/info/import``
    * alternative: ``v2/info`` (I think we want the sub-resource, however, as
      it will keep the response simpler when export, image conversion, and
      possibly other functions are added.)
* Parameters which can be passed via the URL: none
* JSON schema definition for the body data: not allowed
* JSON schema definition for the response data: none

format discovery
****************

``GET v2/schemas/import``

The response is the following JSON schema.

.. literalinclude:: import-schema.json
    :linenos:
    :language: json

Note that the values for ``source_disk_format`` and ``source_container_format``
will be pulled from configuration options used to supply values for the *value
discovery* call. This will allow an end-user to do accurate schema-validation on
the request.

.. note :: I haven't addressed Stuart's question "Do we need to have both
   'global' and disk format specific parameters?"  The question appears on the
   schema in Patch Set 5.  Depending on how it's answered, a usable schema may
   be more complicated than the one proposed here.

.. note :: The schema needs to allow for some provider-specific properties.  An
   example is ``os_type``, which affects how the Xen hypervisor creates the
   guest filesystem.  A cloud may protect this property because otherwise
   changing its value from ``linux`` to ``windows`` will allow end users to run
   unlicensed Windows servers in a cloud, leading to violation of licensing
   terms, lawsuits, and general unhappiness.

   I've included ``os_type`` in the schema, but there may be some other such
   properties, so I've added a work item to contact the operators group and the
   product working group so that we can get a (hopefully) definitive list
   before the Mitaka release and amend this spec and the schema appropriately.

summary
^^^^^^^

* Method type: GET
* Normal http response code(s): 200 (OK)
* Expected error http response code(s): 400, 401, 405
    * 400: request body passed
    * 401: unauthorized
    * 405: only GET supported for this call
* URL for the resource: ``v2/schemas/import``
* Parameters which can be passed via the URL: none
* JSON schema definition for the body data: not allowed
* JSON schema definition for the response data: response is a JSON schema

image-create
************

This call already exists.  We propose adding additional response headers to
facilitate discovery.  (We also discuss it here because the call is integral to
the image import workflow.)

``POST v2/images``

The current request body and response body remain unchanged.  The image is
created in ``queued`` status (just as it is now for the v2 API).

Note that ``disk_format`` and ``container_format`` are currently optional in
this request, which works well for image import since it's possible that the
formats of the imported data will be modified during the import process (for
example, an OVA might be unpacked, or a bare disk might be packaged).  The
``disk_format`` and ``container_format`` will be required in the image-import
call, as will the common image property ``os_type``.  Values specified in the
image-import call will overwrite any existing values in the image object.

New response headers
^^^^^^^^^^^^^^^^^^^^

``OpenStack-image-import-methods``

   The value of this header will be a comma-separated list of import method
   keywords.  For example,
   ``OpenStack-image-import-methods: glance-direct,swift-local``

``OpenStack-image-glance-direct-url``

   The value of the header will be the URL to which the image data could be PUT
   by a subsequent call.  This header will be included only if the site
   supports the ``glance-direct`` import method.  (If the ``glance-direct``
   name is changed, this header will be renamed as well.  The method name is
   included here so that if there are multiple import methods that specify URLs
   to whihch data can be uploaded, the client will have a way to distinguish
   them.)

data-put
********

``PUT v2/images/{image_id}/stage``

This call will follow the specification for the current ``PUT
v2/images/{image_id}/file`` call, with the following changes:

#. The call to ``/file`` is accepted only when the disk and container format
   fields have been set on an image.  That will not be required for the call to
   ``/stage`` because the user will be supplying these in the subsequent
   image-import call.

#. The call will fail when the number of uploaded bytes exceeds the
   max_upload_bytes value published in the value discovery call.

#. The call will fail when the upload time exceeds the
   max_upload_time value published in the value discovery call.

#. The image will be set in status `uploading` rather than
   `saving`. Calls to `/file` shouldn't be accepted if the image
   status is `uploading`. Likewise, calls to `/stage` shouldn't be
   accepted if the image status is `saving`.

The user indicates that the data has been staged by issuing the image-import
call (see below).  Thus multiple data-put calls are allowed.  This could allow
two users in the same tenant to issue competing data-put calls, but for this
implementation we will consider it the responsibility of the tenant to ensure
that users cooperate appropriately.

If the subsequent processing on the image concludes that the image should be
rejected, the image data will be deleted and the image will go to ``killed``
status.

In order to propagate information to the end user, a new ``message`` field will
be added to the Image object.  See [OSE4]_ for examples of the type of content
the ``message`` field will contain.

summary
^^^^^^^

* Method type: PUT
* Normal http response code(s): 204 (No Content)
    * Alternative is 202, but that's not quite right because nothing's going to
      happen with respect to the image data until the user makes a subsequent
      import call.  In other words, I think 202 implies "your image is on the
      way", and that's not the case here.  It made sense on the previous patch
      set, where a successful PUT did trigger the import processing, but that's
      not the case anymore.
* Expected error http response code(s): 401, 405, 409, 415
    * 401: unauthorized
    * 405: only PUT supported for this call
    * 405: the ``glance-direct`` import method is not supported at this site
    * 409: associated image is not in appropriate status
    * 415: unsupported media type (must be ``application/octet-stream``)
* URL for the resource: ``v2/images/{image_id}/stage``
* Parameters which can be passed via the URL: none
* JSON schema definition for the body data: none
* JSON schema definition for the response data: no content in response

implementation issues
^^^^^^^^^^^^^^^^^^^^^

The exact nature of the ``stage`` (formerly, "bikeshed") needs to be
determined.

image-detail
************

This call already exists, but we discuss it anyway because it's integral to the
image import workflow.

``GET v2/images/{image_id}``

This returns an Image object formatted as defined by the JSON schema available
at ``v2/schemas/image``.

Two new image status values will be added to the Image object:

``uploading``
   Why needed: This status conveys to the user that an import data-put call has
   been made.  While in this status, a call to ``PUT /file`` is disallowed.
   (Note that a call to ``PUT /file`` on a queued image puts the image into
   ``saving`` status.  Calls to ``PUT /stage`` are disallowed while an image is
   in ``saving`` status.  Thus it's not possible to use both upload methods on
   the same image.)

``importing`` 
   Why needed: This status conveys to the user that an import call has been
   made but that the image is not yet ready for use.  Data-put calls are not
   accepted when an image is in this state.

A new property will be added to the Image object:

``message``
   Why needed: If an error occurs during the import process, the image will go
   to status ``killed``, but that doesn't tell the user what happened or
   provide any clue about the appropriate action to take.

   Additionally, the ``message`` element can be used for non-error
   communication between Glance and the end user.  See [OSE4]_ for examples of
   such usage.

image-import
************

``POST v2/images/{image_id}/import``

The request body must conform to the JSON schema retrievable from the format
discovery call, otherwise the call will fail.  There is no response body.

The status of ``{image_id}`` must be ``uploading`` or ``queued`` or the call
will fail with a 409 (Conflict).  (We need to allow image-import from
``queued`` for non-upload import methods, for example, swift-local or some type
of copy-from functionality.)  If Image ``{image_id}`` does not exist or is not
owned by the caller, a 404 will be returned.

summary
^^^^^^^

* Method type: POST
* Normal http response code(s): 202 (Accepted)
* Expected error http response code(s): 400, 401, 404, 405, 409, 415
    * 400: malformed request
    * 401: unauthorized
    * 404: image record doesn't exist or is not owned by the caller
    * 405: only POST supported for this call
    * 409: associated image is not in appropriate status
    * 415: unsupported media type (must be ``application/json``)
* URL for the resource: ``v2/images/{image_id}/import``
* Parameters which can be passed via the URL: none
* JSON schema definition for the body data: ``v2/schemas/import``
* JSON schema definition for the response data: no response

example (``glance-direct`` method)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. literalinclude:: import-request-example-gd.json
    :linenos:
    :language: json

example (``swift-local`` method)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. literalinclude:: import-request-example-sl.json
    :linenos:
    :language: json

Alternatives
------------

Do nothing and use the current upload workflow.

Use the Glance "tasks" API.

Out of scope
------------

As discussion on this spec has advanced, we've agreed that it does *not*
encompass the following features.  At the same time, we should keep in mind
that at a later point, we may want to include such features.  Thus, whatever
design we come up with for image import should make it easy to accommodate
them.

* Out of scope: Image conversion during the import process

* Out of scope: Specification of a common disk/container format that all sites
  must support

* Out of scope: Equivalence of disk/container format(s) used in a particular
  cloud and the disk/container format(s) supported for image import.  (In other
  words, no requirement that a site must allow import of all formats in use at
  that site.  See the "note" in value-discovery section, above, for more about
  this.)

* Out of scope: Image export (though obviously we want a solution that lends
  itself easily to export as well as import)

Data model impact
-----------------

Two new image status values will be added: ``importing`` and ``uploading``.

A new image property will be added: ``message``.

REST API impact
---------------

Given that at least one new call is being added to the API, a minor version
bump should occur.

Not exactly in scope for this spec, but the general consensus is that the
current "tasks" API should be deprecated in this cycle and made an admin-only
API.

Security impact
---------------

As its intent is to consume user-provided data, this feature will introduce new
security risks.  Historically, the Images v1 API was not meant to be exposed
directly to end users, as it was expected that end users would use the Compute
API for image related calls.  The Compute API defines an "image-create" action,
but this is an action on the servers resource, that is, it creates a snapshot
of an existing instance, not the upload of an end-user supplied image.
Further, discussion at the Havana summit (see [OSE1]_) indicated that Images v2
upload shouldn't be exposed to end users either, but should be reserved for
trusted users.  So even though it's previously been possible for a particular
deployment to expose image upload directly to end users, it hasn't been a
recommended practice.

Image import must be designed so that a deployer can halt image imports during
an emergency.

We anticipate the following security risks:

* It consumes user-provided data.  Depending upon the container_format and
  disk_format allowed, this may expose Glance (and other projects that consume
  images from Glance) to decompression bombs or various tar-based attacks.
  (Consumers of images may already have mitigation strategies in place, but
  Glance itself currently does not.)

* It enables a resource exhaustion attack.  Vectors include: uploading a
  arbitrary number of bytes (can be mitigated by a max size restriction),
  uploading an allowable number of bytes over an extremely slow connection (can
  be mitigated by a Glance-side timeout), concurrent imports (can be mitigated
  by user quota, user limit, task queuing, or some combination).

(The remainder of the questions in this section will be addressed as the
discussion advances.)

* Does this change touch sensitive data such as tokens, keys, or user data?

* Does this change alter the API in a way that may impact security, such as
  a new way to access sensitive information or a new way to login?

* Does this change involve cryptography or hashing?

* Does this change require the use of sudo or any elevated privileges?

* Does this change involve using or parsing user-provided data? This could
  be directly at the API level or indirectly such as changes to a cache layer.

* Can this change enable a resource exhaustion attack, such as allowing a
  single API interaction to consume significant server resources? Some examples
  of this include launching subprocesses for each connection, or entity
  expansion attacks in XML.


Notifications impact
--------------------

The image import process should emit notifications.  (Will specify further
after the basic design is worked out.)

We should implement notifications for at least the following parts of the
import workflow:

#. The import operation has been accepted
#. Processing has begun
#. Processing status periodically (percentage)
#. Processing has been completed (success/failure)


Policy impact
-------------

Image import, as described herein, is an end user operation, not an admin
operation.  It is, however, necessary that it be governed appropriately by
Glance policies.  While the default policy setting will allow end users to
import images, a small public deployer with limited resources might want to
restrict image import to specific users.

Additionally, as mentioned above, it should be possible for a deployer to "turn
off" image import if a vulnerability is discovered.

Other end user impact
---------------------

We need to articulate clearly how the traditional Glance image immutability
guarantee applies to image import, namely, an image is immutable once it goes
active.

The python-glanceclient will be modified to support image import.  (Will
describe the interface after the basic design is worked out.)

Performance Impact
------------------

Describe any potential performance impact on the system.  (Will fill in after
the basic design is worked out.)

Other deployer impact
---------------------

This change may affect how people deploy and configure OpenStack in the
following ways:

* Nova depends upon Glance to supply images and accept VM snapshots.  Those
  operations are unaffected by this proposal.

* Processing image imports may require dedicated resources, for example:

  * dedicated nodes if the image validation is CPU-intensive

Developer impact
----------------

It is not anticipated that this feature will affect other developers working on
OpenStack.


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  brian-rosmaita

Other contributors:
  mclaren

Reviewers
---------

Core reviewer(s):
  All current glance cores.

Work Items
----------

* API version bump: https://bugs.launchpad.net/glance/+bug/1523934

* Policy rules and new configuration options:
  https://bugs.launchpad.net/glance/+bug/1523937

  These depend on the policy change.

  * Start working on the header changes:
    https://bugs.launchpad.net/glance/+bug/1523941
  * Work on the API schema changes (discoverability):
    https://bugs.launchpad.net/glance/+bug/1523944
  * Import call (task triggering):
    https://bugs.launchpad.net/glance/+bug/1523955

* Make task api admin only:
  https://bugs.launchpad.net/glance/+bug/1527716

* Mark the `/file` endpoint as deprecated for non-admin use
  https://bugs.launchpad.net/glance/+bug/1528637

* Contact the operators and product working groups about properties similar to
  ``os_type`` that should be included in the import request schema.

* (internal) task configuration

* python-glanceclient support

* tempest tests

* documentation


Dependencies
============

It is not anticipated that this feature will require dependencies not already
used by the current Glance tasks.

Testing
=======

It should be possible to add a tempest test that imports a small image.

Documentation Impact
====================

The following will need to be added to the glance developer docs.

#. any new API calls
#. changes to any existing API calls
#. tasks info for glance developers who want to work on tasks
#. tasks info for deployers who want to use tasks (I suggest starting with this
   in the dev docs and then move it to one of the OpenStack operator manuals
   eventually)

References
==========

.. [OSB1] https://blueprints.launchpad.net/glance/+spec/upload-download-workflow
.. [OSD1] http://developer.openstack.org/api-ref-image-v2.html#os-tasks-v2
.. [OSE1] https://etherpad.openstack.org/p/havana-getting-glance-ready-for-public-clouds
.. [OSE2] https://etherpad.openstack.org/p/glance-upload-mechanism-reloaded
.. [OSE3] https://etherpad.openstack.org/p/Mitaka-glance-image-import-reloaded
.. [OSE4] https://etherpad.openstack.org/p/glance-image-import-example
.. [OSG1] https://review.openstack.org/#/c/220166/
.. [OSG2] https://review.openstack.org/#/c/220166/4/doc/source/tasks.rst
.. [OSL1] http://eavesdrop.openstack.org/irclogs/%23openstack-glance/%23openstack-glance.2015-09-22.log.html#t2015-09-22T14:31:00
.. [OSM1] http://lists.openstack.org/pipermail/openstack-dev/2015-September/thread.html#74360
.. [OSM2] http://lists.openstack.org/pipermail/openstack-dev/2015-September/thread.html#74383
.. [OSO1] http://www.openstack.org/brand/interop/
.. [OSR1] http://git.openstack.org/cgit/openstack/defcore/tree/doc/source/process/CoreCriteria.rst
.. [OSW1] https://wiki.openstack.org/wiki/Glance-tasks-api
.. [OSW2] https://wiki.openstack.org/wiki/Glance-tasks-api-product
.. [OSW3] https://wiki.openstack.org/wiki/Glance-tasks-import
.. [OSW4] https://wiki.openstack.org/wiki/Glance-upload-mechanism-reloaded
.. [NEW1] https://governance.openstack.org/resolutions/20151211-bring-your-own-kernel.html
.. [NEW2] https://github.com/openstack/defcore/commit/10562c245a6332f52cb5c5d15739dfab15b2baa6
