..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=====================
Image Import Refactor
=====================

https://blueprints.launchpad.net/glance/+spec/image-import-refactor

.. note:: This is a very long spec, so we've added a :ref:`FAQ` to cover some
          common questions so that people can make better informed comments on
          the implementation patches.

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

.. _constraints:

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

.. _proposed-change:

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

.. _value-discovery:

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

.. _format-discovery:

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

.. _alternatives:

Alternatives
============

Here we consider some alternatives for 'native' (non-Swift) upload.

Use existing native v2 upload
-----------------------------

We could use the existing synchronous v2 upload call, namely:

``PUT v2/images/{image_id}/file``

Advantages:

* No impact on existing API users.

Disadvantages:

* Rules out long lived validation/processing.

Change existing native v2 upload to be asynchronous
---------------------------------------------------

(This would include adding some simple discoverability call.)

Advantages:

* Small change from existing behaviour. May not impact all use cases.

Disadvantages:

* Changes existing API behaviour. Not considered backwards compatible.
* Users/libraries must change to expect non-synchronous behaviour.

Asynchronous upload call
------------------------

This would be a tweak to the existing v2 upload call, to make it asynchronous --
but in a backwards compatible way. Backwards compatibility could be achieved by
either using a different resource path, adding a header, or using a query parameter.
(This would include adding some simple discoverability call.)

Advantages:

* Very similar to existing upload mechanism.
* Still just two API calls (``POST``, ``PUT``)
* No new image states are required.

Disadvantages:

* Initially uploaded data is not cached for retry. (Same as existing upload.)
* Users/libraries are expected to switch to the new method.
* Slightly different work-flow than 'non-native' imports (ie imports from external sources)

Independent fileIds
-------------------

Here, the uploaded bytes are not initially part of a particular
image. This would work the same way as the import-from-Swift case,
in that fileId operations are kept separate from image operations
in a similar way that Swift object operations are kept seperate
from image operations.

First you upload the bytes with a ``POST``. This stores the bytes and
generates a unique fileId. At this point the bytes are not 'part' of
any image. You then make a call for an image to consume that fileId
(analogous to consuming a Swift object). You then (optionally) delete
the original fileId.

This could be implemented in slightly different ways.

* A fileId could be completely unassociated with any image, in which
  case it could be reused as source data for more than one image.
* Alternatively the fileId could be restricted to a particular image by
  requiring the image uuid to be specified when creating the fileId. In
  both cases, the only time a fileId would impact image state is when the
  image is consuming the fileId and goes through the usual ``queued``,
  ``saving``, ``active`` stages.

Advantages:

* Swift and Glance work in the same way. (Initial data is not considerd
  'part' of the image.)
* Can be extended to uploading several fileIds sequentially or in
  parallel.
* fileIds are cached for retry if the import fails
* fileIds can each have their own size and checksum (for quota/integrity)
* seperation of concerns (less impact on existing code areas, eg image
  delete would never have to handle deleting more than one data blob.)
* No new image states are required.

Disadvantages:

* More code, eg to list fileIds
* More API calls than the simple async upload case
* Users/libraries are expected to switch to the new method.

Asynchronous upload call and Independent fileIds
------------------------------------------------

These two options could be combined. 'Asynchronous upload' would provide a
'simple' call for the common simple upload case, 'independent fileIds'
would provide a more involved set of calls for parallel/segmented
upload. (There are examples elsewhere of of having a simple call for
the basic case and more advanced calls for more advanced functionality,
eg regular Swift upload versus Swift Large Object upload.)

Advantages:

* Simple API available for standard uploads
* More advanced APIs available to those who need them
* Could implement the simple case first

Disadvantages:

* More code
* Users/libraries are expected to switch to the new method.


URL nomination
--------------

Glance could nominate an opaque URL for the data to be PUT to.
For example, the POST request could return:

put-data-to: https://example.com/xxx

If Swift is available the URL would be a Swift TempURL, if Swift is not
available the URL would point to an appropriate Glance URL.  As far as
I know Swift's TempURL allows range offset so parallel uploads/partial
retries should work.

Advantages:

* Nice and RESTFul
* Almost equivalent behaviour whether Swift is in use or not

Disadvantages:

* Swift TempURLs limit upload sizes (5GB by default). (Changes to Swift would be required.)

* A user may have pre-existing image data in Swift. That case would need
  to be handled anyway.
* In the Swift TempURL case no token header is required to be sent with
  the data. In the Glance case a token header would be required (unless we
  added TempURL type functionality to Glance). So the two things would not
  be completely equivalent. You'd have to know whether you're sending to
  Glance or Swift -- or at least whether to send a token or not. You could
  potentially just send the token in both cases, but that's a little untidy
  (eg principle of least privilege).
* Would require a special account for Swift imports (this would be the
  upload target), even in multi-tenant store mode because it may not be
  safe to nominate a URL in the user's own account.
* While (I think) parallel uploads/partial retries are possible with
  Swift's TempURL they could only be attempted if it was known that the
  target was Swift, ie if the URL isn't opaque. So we'd be back to having
  to know which service we're sending the data to. (Unless we forfeited
  some of Swift's advantages.)


Use existing tasks API
----------------------

This works when Swift is present, but doesn't provide a way
to do an asynchronous 'native' upload.

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

* Document that `/file` is not recommended for public nodes.

* Introduce policies so that the ``/file`` endpoint can be easily disabled for
  operators following the recommendation above. The default setting for these
  policies will **not** change the current behavior.

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

.. _FAQ:

FAQ
===

Everything you always wanted to know about Glance Image Import but were afraid to ask.

#.  What is the use case addressed?

    A cloud end-user has a bunch of bits that they want to give to Glance in
    the expectation that (in the absence of error conditions) Glance will
    produce an Image (record, file) tuple that can subsequently be used by
    other OpenStack services that consume Images.

#.  Why is the "regular" upload insufficient?

    Unlike taking a "snapshot" of a instance using the Compute API, where Nova
    handles the image creation, packaging, basic cataloging, and uploading into
    Glance, exposing image upload opens a cloud to human error (for example,
    not a VM image, incorrect type of image for the hypervisors in that cloud,
    maliciously packaged/structured image to attack the hypervisor) that
    exposes a cloud to extra support load, denial of service, or security
    concerns.

    Plus, it's not just security issues.  Another common use case would be an
    end user uploading an OVA that could be automatically unpacked and the
    manifest introspected to set appropriate metadata on the image.  Or if
    OpenStack were to agree to a common image interchange format, conversion of
    the imported image might be required.

#.  How are the above problems addressed by the proposed import process?

    In contrast to "regular" upload, which puts the image data directly into
    the storage backend, the image import process allows an operator to examine
    the putative image and perform validation/conversion/packaging (or nothing)
    before it's stored in the backend.

#.  Doesn't this introduce unwanted variability into the import process?

    No, it does not.  The API is fixed so that the API request and response
    formats are identical in all OpenStack clouds.  The variability is behind
    the scenes, after the user has made the data available to Glance but before
    the image status goes to 'active'.

    Note that while there are multiple import methods, each method is precisely
    defined and schematized so that the API calls/responses are standard.

#.  Why multiple methods?

    This is a situation in which a one-size-fits-all approach doesn't really
    work.  There are several issues that come into play that affect the user
    experience of both end users and operators, for example, the size of the
    images to be imported, the speed of available connections, the ability to
    deploy extra upload nodes, the presence/absence of an object store, then
    volume of end users doing image imports, the size of a cloud's operations
    team, etc.  Some usage patterns can be accommodated by the method we're
    calling 'glance-direct' whereby an end-user directly streams the object
    into Glance; others might be better accommodated by import from an object
    store whereby end users can make use of appropriate tooling to ensure a
    good user experience when uploading large binary objects.  Since OpenStack
    provides free software for an object store solution, and since Swift is
    deployed in roughly half of all OpenStack clouds, we propose implementing a
    'swift-local' import method in which the image data would be uploaded to
    Swift out of band.

    Additionally, in anticipation of the deprecation of the Images v1 API, some
    operators have pointed out that the "copy-from" capability in the older API
    is missing from the Images v2 API.  While it's not a driver for this work,
    a well-defined copy-from import method can be accommodated by this design.

    In short, the multiple import methods allow us to have a consistent and
    discoverable API across clouds that will empower operators and end users to
    offer/use the import methods that work best for them.

#.  What if I don't like there being multiple import methods?

    Believe me, we have thought about this carefully.  The alternative would be
    to have different API calls for each of the different import methods.
    That, however, would mitigate against the goal of having stable API calls
    supported in all OpenStack-branded clouds, since not every cloud operator
    will want to expose all import methods.  That would make it difficult for
    image import to be in DefCore.

    Let's be really careful in describing what we're talking about here.  The
    approved design for image import allows operator choice, but in a very
    constrained way.  As far as the end user is concerned, each import method
    will operate identically in each OpenStack cloud, and we envision there
    being a small number of these methods as each must make it through the
    specs process and be implemented in-tree.  Thus it will be possible to code
    a client to handle image import seamlessly from the end user point of view.

#.  If there are multiple methods, must a cloud support them all in order to
    achieve the "OpenStack" brand via DefCore?

    This is ultimately up to the DefCore project.  Our idea is that since all
    OpenStack clouds would support at least one of the import methods, all
    OpenStack clouds would thereby have a working Images v2 API image import
    facility, and could pass an image import requirement.

#.  If there are multiple methods, how can I determine what's available in a
    particular cloud?

    This can be done programmatically. (a) The GET v2/info/import returns a
    well-defined document that contains the list of import methods supported at
    a particular site.  (b) A header that comes back from the POST v2/images
    call also contains the list of import methods supported at the site.  See
    the :ref:`value-discovery` section of this spec.

#.  If there are multiple methods, how do I know what the request for the
    method I want to use is supposed to look like?

    There's a JSON schema with this information.  See :ref:`format-discovery`.

#.  If there are multiple import methods, what's to stop someone from adding
    more?

    Additional methods would have to be proposed in a Glance spec and would
    have to meet the discoverability and interoperability constraints we're
    implementing for image import.  So it's not the kind of thing that can be
    done lightly.

#.  What about the old image upload call?

    The PUT to v2/images/{image_id}/file makes sense as a call used by
    operators and trusted services, so we are not proposing that it be removed.
    We do, however, recommend that operators not expose it directly to end
    users.

#.  I have a question you haven't covered here.

    Well, you could read through this entire spec.  But here are some pointers:

    For details about the import workflow and API calls, start at the
    :ref:`proposed-change` section.

    If you want more background about why that workflow was chosen, you
    need to read the beginning of this document.

    If you want a quick summary of the design constraints, start at the
    :ref:`constraints` section.

#.  Wait, wasn't this spec approved for Mitaka?

    Yes, it was.  It didn't get implemented because we wanted to make sure
    there was a thorough exploration of :ref:`alternatives` before
    implementation began.  The ultimate the consensus was that we should stick
    with the original proposal.  The key point here is that the implementation
    of this spec has not been rushed through by any means.

#.  The image import spec is really, really long, but I can't get enough of it.
    Where can I read even more?

    The spec has a list of :ref:`references` you may find interesting.

    There are also some recent etherpads:

    - `Newton contributors' meeting: image import <https://etherpad.openstack.org/p/newton-glance-import-refactor>`_
    - `Image Import MVP <https://etherpad.openstack.org/p/glance-image-import-implementation-tactics>`_

    Additionally, you may find the discussion on the following patches
    entertaining:

    - https://review.openstack.org/232371
    - https://review.openstack.org/271021
    - https://review.openstack.org/270980
    - https://review.openstack.org/311871


.. _references:

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
