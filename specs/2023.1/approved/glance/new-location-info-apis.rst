..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=================
New Location APIs
=================

https://blueprints.launchpad.net/glance/+spec/new-location-apis

Problem description
===================

Currently we have two security vulnerabilities with
``show_multiple_locations`` config option, OSSN-0065 [1]_ and OSSN-0090 [2]_.
If we enable ``show_multiple_locations`` and the policies for add/update
(set_image_location), get (get_image_location) and remove
(delete_image_location) locations are set for non-admins then non-admin users
can modify location data to corrupt an image that they own. Note that the
policies for add, get and remove locations are set for non-admins by default
else a non-admin user cannot associate data with an image record, or retrieve
image data, or delete image data.

When show_multiple_locations is False, users cannot modify image
locations via the image-update API call, even if they have the
``{get,set,delete}_image_location`` permissions.  However, there are some
popular use cases where other services can bypass Glance and store or access
image data directly in the backend by writing or reading image locations,
using the image owner's credentials, and this is why operators want to set
show_multiple_locations to True.  What operators want to do, however, is to
enable optimized image data access; exposing image locations to non-admin
users is a side-effect, not the goal.  We currently recommend that operators
who want to use optimized data access use a specialized Glance instance for
services, and only expose glance-api to end users with show_multiple_locations
set False.  This is inconvinient for certain users.

Proposed change
===============

There will be 3 phases in which the work will be done as follows:

1. Introduce 2 new API calls that allow operations on image locations which
   are described in detail in the `REST API impact`_ section.
   These calls will replace the image-update mechanism for consumers
   like cinder and nova.

2. Modify the consumer (cinder/nova) code to use the new location APIs.
   Also modify HTTP store to use new location APIs.

3. Remove ``show_multiple_locations`` config option when it is no longer
   required by other services (cinder/nova) to perform operations on
   locations. This will mostly be done in B or C cycle.

The config option ``show_multiple_locations`` has been deprecated since Newton
but we will keep the config option until the consumers of glance locations
(nova, cinder, http store etc) start using the new location APIs. Since this
is a major effort spanning across multiple services (nova, cinder, glance),
we will implement the work items in different cycles to provide enough
time for developers (to implement this) and operators (to move away from the
config option).

We will introduce 2 new policies, for each API performing different operations
like add and get, as follows:

1. The ``add policy`` can default to the project member or ``service`` role
   (when it is implemented).
2. The ``get policy`` will default to the ``service`` role for authorization.

Along with the new ``add policy``, we will add a check in the location add API
code to check the status of image and only add location if it is in ``QUEUED``
state and adding location when the image is in other states will be
disallowed. This is done in order to prevent malicious users from modifying
the image location again and again since the location added for the first time
is the correct one as far as Glance is concerned.

End-user access to image locations via the Image API is no longer necessary.
Since Train, Glance has multiple stores support, and we have added API calls
that allow users to manipulate data locality with respect to store.
Further, a store is an opaque identifier, whereas an image location
exposes backend details that users don't need to know.

Here are the current use cases for the direct manipulation of image
locations along with an explanation of how they can be handled by the
new Location API.

1. When using a copy-on-write (COW) backend shared by Nova and Glance,
   Nova can create an image record in Glance, snapshot a server image
   directly in the backend, and set the location on the image record.
   This use case is covered by the new add-location call, and having
   its default policy be image owner or service.

2. A user wants to have a single image record, but have image data
   stored in multiple locations for locality (i.e., to have image
   data as close as possible to where it's consumed).
   This use case is handled by the glance multiple stores feature
   plus image import, which since API v2.8, allows a 'stores' parameter
   specifying where the image data should be stored.  This applies to both
   newly created images and existing images (via the copy-image import
   method).
   In this workflow, Glance itself manipulates the image locations; there
   is no need for the user to interact with locations directly.

3. An operator wants to introduce a new storage backend and decommission
   the current backend while keeping the same image catalog.
   Similar to #2, this can be handled by using the copy-image import
   method and the delete-image-from-store API call introduced in v2.10.
   Note that there are some exceptions to this like:

   a. HTTP store is read-only, so we can't use copy-image in this case.

   b. For RBD store, we will create a dependency chain if we launch a VM
      or create a bootable volume from it hence we can't delete the source
      image until all of it's children are flattened.

   c. For cinder store, if the cinder backend uses COW cloning, it is similar
      to the RBD case mentioned in b) else the image delete will succeed.

Following APIs are not being implemented:

``Update``: For service to service interaction, there is no value in updating
the metadata of a location. This would be beneficial if we plan to remove the
existing location code from image-update call and support the usecase of
operators/end-users doing location operations.

``Delete``: We already have `Delete Image From Store`_ API for this purpose.
We don't require the `Delete Image From Store`_ API call for the current
usecase but if we plan to extend the location APIs in future, we can do this
by updating the policies enforced by `Delete Image From Store`_ operation from
the default ``role:admin`` to ``role:admin or role:service``.

Alternatives
------------

* We can remove the ``show_multiple_locations`` config option and filter the
  images with the ``admin_or_service`` role. This will require the consumers
  to provide admin credentials during add or get of an image to get the
  location.
  This was the original proposal but due to the disagreement here [4]_, we
  changed the design to the current proposal.

* Another alternative is to add this functionality in the import workflow.
  We can add a new import method ``direct-location`` which will allow end
  users to specify the ``location`` and ``metadata`` parameters and create a
  new image based on the given parameters. We can also update an existing
  image with ``location`` and ``metadata`` values but will require the image
  to be in ``queued`` state.

  For this, we will need to add a new import method ``direct-location`` and also
  add ``--metadata`` and ``--location`` parameters to the following commands:

  * ``glance image-create-via-import --import-method direct-location --location
    <location> --metadata <key1=value1, key2=value2 ...>``

  * ``glance image-import --import-method direct-location --location
    <location> --metadata <key1=value1, key2=value2 ...>``

Data model impact
-----------------

None

REST API impact
---------------

We are going to add 2 new location APIs:

* Add Location

  This will add a new location to an existing image.
  The request body will contain the location URL and an optional parameter,
  ``do_secure_hash``, which will tell the API if we want to do the checksum or
  not. The ``do_secure_hash`` flag is required by the HTTP Store to make it
  compatible with new location add API.
  We will allow ``validation data`` [3]_ to be passed in case of HTTP store
  else glance will calculate the image hash. If both ``do_secure_hash`` and
  ``validation data`` are passed, then we will compare them and fail the
  location add operation if they don't match.

  POST /v2/images/{image_id}/locations

  * JSON request body

    .. code-block:: json

        {
            "url": "cinder://lvmdriver-1/0f031ed1-5872-43d5-a638-4b0d07c10ab5",
            "do_secure_hash": false,
        }

  * JSON response body

    - Success - 200

    .. code-block:: json

        {
            "url": "cinder://lvmdriver-1/0f031ed1-5872-43d5-a638-4b0d07c10ab5",
            "metadata": "{'store': 'lvmdriver-1',
                          'do_secure_hash': false}"
        }

    - Error - 409 (Location already exists), 403 (Forbidden for users that are
      not owner), 400 (BadRequest if image is not in QUEUED state)

* Get Location(s)

  This will show all the locations associated to an existing image. Returns an
  empty list if an image contains no locations.

  GET /v2/images/{image_id}/locations

  * JSON response body

    .. code-block:: json

        [
            {
                "url": "cinder://lvmdriver-1/0f031ed1-5872-43d5-a638-4b0d07c10ab5",
                "metadata": "{'store': 'lvmdriver-1'}"
            },
            {
                "url": "cinder://cephdriver-1/11b4fa9f-a44b-46c9-950c-0026c467252c",
                "metadata": "{'store': 'cephdriver-1'}"
            }
        ]

    - Error - 404 (Image ID does not exist), 403 (Forbidden for normal users)

The transition of image state during the image create operation will be as
follows.
Image upload (PUT), image stage (PUT) and location add (PATCH), will transition
the image from queued to the next state that could be either of the following:

1. ``saving``
2. ``uploading``
3. ``active``

Below are the valid transitions for image from queued state.

'queued': ('saving', 'uploading', 'importing', 'active', 'deleted')

Security impact
---------------

No worse than it is now, and possibly better.

1. The get-locations policy is restricted to the 'service' role,
   so users will not be able to see image locations.  Thus with
   'show_multiple_locations' and 'show_direct_url' set to False,
   the new get-locations API will not expose location information
   to users.
2. The add-location policy is restricted by default to image-owner.
   This will allow end users to add a location to an image to address
   current uses of this functionality that we aren't aware of.
   Even allowing this, the data-substitution attack is blocked because
   the API call will only be allowed for an image in 'queued' status.
   The add-location API cannot be used to add a location to an image in
   other states and then delete the original location, so the OSSN-0065
   attack is not possible under this scenario.
   Further, the add-locations call (unlike the current method of
   updating locations via PATCH), does not require the locations to
   be visible to succeed.  Thus operators will be able to configure
   Glance with 'show_multiple_locations' and 'show_direct_url' set
   to False, even when other services are sharing a COW backend with
   Glance and the operator wants an optimized workflow.

Notifications impact
--------------------

None

Other end user impact
---------------------

Since the new APIs are for service to service interaction, there is not much
value to expose them via glanceclient CLI. However, we will add methods to
the glanceclient (that will call the new location APIs) that will be used by
other consumer services like cinder and nova but those methods won't be
exposed via the shell to end users.
End users can still use the existing commands (that internally calls the
image-update API) to perform operations on locations:

* ``glance location-add:`` Add a location (and related metadata) to an image.
* ``glance location-delete:`` Remove locations (and related metadata) from an
  image.
* ``glance location-update:`` Update metadata of an image's location.

We will also add a new command that will allow end users to update the
``location`` and ``metadata`` for HTTP store case.

* ``glance direct-location --location <location> --metadata
  <key1=value1, key2=value2 ...>``

Performance Impact
------------------

None

Other deployer impact
---------------------

None

Developer impact
----------------

Consumers like Cinder, Nova and HTTP store need to modify code to call the
new client functions to access the API.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  abhishekk

Other contributors:
  whoami-rajat

Work Items
----------

* Add 2 new Location APIs for add and get operations.

* Modify consumers like cinder and nova and http store to use the new location
  APIs.

* Add a releasenote mentioning that we will remove the config option
  ``show_multiple_locations`` when the consumers (nova/cinder/http store)
  shift to using new location APIs.

* Tempest tests for the new add-location and get-location APIs.

Dependencies
============

None

Testing
=======

* Unit Tests
* Functional Tests
* Integration Tests
* Tempest Tests

Documentation Impact
====================

Need to document new location APIs.

References
==========

.. [1] https://wiki.openstack.org/wiki/OSSN/OSSN-0065

.. [2] https://wiki.openstack.org/wiki/OSSN/OSSN-0090

.. [3] https://specs.openstack.org/openstack/glance-specs/specs/stein/implemented/glance/spec-lite-locations-with-validation-data.html

.. [4] https://review.opendev.org/c/openstack/glance-specs/+/840882/2..15/specs/zed/approved/glance/new-location-info-apis.rst#b199

.. _Delete Image From Store: https://docs.openstack.org/api-ref/image/v2/index.html?expanded=delete-image-from-store-detail#delete-image-from-store

* Deprecate `show_multiple_locations` option | https://review.opendev.org/c/openstack/glance/+/313936

* Update deprecated show_multiple_locations helptext | https://review.opendev.org/c/openstack/glance/+/426283

* Update show_multiple_locations deprecation note | https://review.opendev.org/c/openstack/glance/+/625702

* Original security bug | https://bugs.launchpad.net/ossn/+bug/1549483

* New security bug | https://bugs.launchpad.net/ossn/+bug/1990157
