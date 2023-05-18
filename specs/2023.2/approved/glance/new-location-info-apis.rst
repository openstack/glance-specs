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
   locations. This will mostly be done 1 or 2 cycles after the consumers
   have adapted the new location APIs to handle the upgrade cases.

The config option ``show_multiple_locations`` has been deprecated since Newton
but we will keep the config option until the consumers of glance locations
(nova, cinder, http store etc) start using the new location APIs. Since this
is a major effort spanning across multiple services (nova, cinder, glance),
we will implement the work items in different cycles to provide enough
time for developers (to implement this) and operators (to move away from the
config option).

We will introduce 2 new policies, for each API performing different operations
like add and get, as follows:

1. The ``add policy`` can default to the ``project member`` or ``service``
   role (when it is implemented).
2. The ``get policy`` will default to the ``service`` role for authorization.

Along with the new ``add policy``, we will add a check in the location add API
code to check the status of image and only add location if it is in ``QUEUED``
state and adding location when the image is in other states will be
disallowed. This is done in order to prevent malicious users from modifying
the image location again and again since the location added for the first time
is the correct one as far as Glance is concerned.

We will also introduce a new configuration parameter ``do_secure_hash`` on
the glance side which will tell the API if we want to do the hash calculation
or not. This will be useful in cases when nova, cinder etc, adds a location
in glance since glance does not calculate the hash and checksum automatically
in these cases. The value of ``do_secure_hash`` will be ``True`` by default.

After nova or cinder send a request for adding a location for the VM snapshot
or upload volume case respectively and ``do_secure_hash`` is ``True``, glance
will start a background process that will calculate the hash of the image.
Unless we have ``validation_data`` (in the request body) to be verified,
image will be set to ``active`` state after registering the location even if
the hash calculation is ongoing in the background. This is done so that the
image can be used to create instances and bootable volumes instantly after
we've registered the location and not wait for the hash calculation since
it is a long running task. After the hash calculation completes, image
properties will be updated with the ``checksum``, ``os_hash_algo`` and
``os_hash_value`` values.

Following are the cases of image transition with different values of
``do_secure_hash`` and ``validation_data``:

* ``do_secure_hash`` is ``True`` and ``validation_data`` is not None:

  Image transition: (queued, importing, active)

  In this case the consumer provides the hash values for validation and
  hash is calculated by glance.
  An example of this case will be providing validation_data for HTTP store.
  Here image hash will be calculated and verified before setting image to
  active state.

* ``do_secure_hash`` is ``True`` and ``validation_data`` is None:

  Image transition: (queued, active)

  In this case validation data will not be provided by the consumer but
  hash is calculated by glance.
  Examples of this case will be when nova snapshots an instance or cinder
  uploads a volume to image.
  Here image hash calculation will be done and updated after setting
  image to active state.
  This is a tricky case because the consumer will have no idea if the
  ``active`` image will ever have a hash value or not and if it should
  wait for the hash to be populated in the image or not.
  To handle this, we will set the ``os_hash_algo`` value in the image
  properties so the consumer will know that hash calculation is ongoing
  for this image and the hash will be populated here.
  Here are the following cases:

  * ``active`` image and no ``os_hash_algo``: This image will not have hash
    value populated.
  * ``active`` image and has ``os_hash_algo``:  Poll for ``active`` image
    status and ``os_hash_algo`` until you get ``os_hash_value``.
    Polling for ``active`` image status is optional since the image gets
    active when ``validation_data`` is not provided and hash calculation
    is ongoing in the background i.e. this case. The ``os_hash_algo`` value
    will be popped if hash calculation fails.

* ``do_secure_hash`` is ``False`` and ``validation_data`` is not None:

  Image transition: (queued, active)

  In this case validation data will be provided by the consumer and hash
  is not calculated by glance.
  An example of this case will be providing validation_data for HTTP store.
  Here image hash will not be calculated and verified but directly set to
  image with values provided by the user.

* ``do_secure_hash`` is ``False`` and ``validation_data`` is None:

  Image transition: (queued, active)

  In this case validation data will not be provided by the consumer and
  hash is not calculated by glance.
  This can happen for all cases.
  Here hash value won't be set in the image.

If the hash calculation fails, we will add a retry mechanism that will
reinitiate the task. We will add a new configuration option ``http_retries``
with a default value of ``3`` i.e. the hash calculation will be executed
maximum 3 times by default if the first and second tries fail.
If after all the retries, the hash calculation still fails, we will not update
the hash and checksum values and image will stay in ``active`` state.

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
   its default policy be project member (image owner) or service.

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
  This was the original proposal but due to the disagreement here [3]_, we
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
  The request body will contain the location URL and ``validation_data`` [4]_
  (optional). The purpose of including validation_data in the request body
  is when the consumer wants to validate the image hash or just directly wants
  to add the hash values to the image. The cases of ``validation_data`` with
  ``do_secure_hash`` are described in the `Proposed change`_ section.
  An example where ``validation_data`` will be provided is the HTTP store case,
  where the user will provide hash value for the HTTP image.

  Unlike old location API, we will not provide support of adding a location
  on a particular index. If we want to get the benefit of indexes, we can
  use the old location APIs or set location strategy as store_type [5]_.
  A new location strategy ``store_identifier`` is proposed [6]_ and should be
  useful to download image from a specific store in case multiple stores are
  configured.

  POST /v2/images/{image_id}/locations

  * JSON request body

    .. code-block:: json

        {
            "url": "cinder://lvmdriver-1/1a304872-b0ca-4992-b2c2-6874c6d5d5f9",
            "validation_data": {
                "os_hash_algo": "sha512",
                "os_hash_value": "6b813aa46bb90b4da216a4d19376593fa3f4fc7e617f03a92b7fe11e9a3981cbe8f0959dbebe36225e5f53dc4492341a4863cac4ed1ee0909f3fc78ef9c3e869",
            }
        }

  * JSON response body

    - Success - 200

    .. code-block:: json

        {
            "url": "cinder://lvmdriver-1/1a304872-b0ca-4992-b2c2-6874c6d5d5f9",
            "metadata": "{'store': 'lvmdriver-1'}"
            "validation_data": {
                "os_hash_algo": "sha512",
                "os_hash_value": "6b813aa46bb90b4da216a4d19376593fa3f4fc7e617f03a92b7fe11e9a3981cbe8f0959dbebe36225e5f53dc4492341a4863cac4ed1ee0909f3fc78ef9c3e869",
            }
        }

    - Error - 409 (Location already exists or if image is not in QUEUED
      state), 403 (Forbidden for users that are not owner), 400 (BadRequest
      if hash validation fails)

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
Image upload (PUT), image stage (PUT) and location add (POST), will transition
the image from queued to the next state that could be either of the following:

1. ``saving``
2. ``uploading``
3. ``importing``
4. ``active``

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

Since the new APIs are mainly for service to service interaction (except the
HTTP store case), we will only expose the location add API via CLI. However,
we will need to add methods for all APIs in openstacksdk (that will call
the new location APIs) that will be used by other consumer services like
cinder and nova.
End users can still use the existing commands (that internally calls the
image-update API) to perform operations on locations:

* ``glance location-add:`` Add a location (and related metadata) to an image.
* ``glance location-delete:`` Remove locations (and related metadata) from an
  image.
* ``glance location-update:`` Update metadata of an image's location.

We will also add a new command to glanceclient and OSC that will allow end
users to add the location ``url`` and ``validation-data`` for HTTP store case.

* ``glance add-location-properties --url <location> --validation-data
  <os_hash_algo=value1, os_hash_value=value2>``
* ``openstack image add location properties --url <location> --validation-data
  <os_hash_algo=value1, os_hash_value=value2>``

Performance Impact
------------------

In the old location API, the consumers (nova, cinder) registered
the location in glance and the checksum, hash etc values weren't
calculated. After the consumers adapt to the new location API,
and the ``do_secure_hash`` config parameter is ``True`` (default),
glance will read the image and calculate the hash in the background.
The hash calculation will be a long running task so it will consume
resources, however, this won't affect the operation requested by
nova or cinder as the image will transition to ``active`` state even
when the hash calculation is ongoing.

The performance downside will result in creation of more secure
images and the impact needs to be conveyed to the operators/end users
with documentation and releasenotes. Since ``do_secure_hash`` will be a
configurable parameter on glance side, we will add suitable help text
to convey the performance and security impact of enabling/disabling this
option.

Other deployer impact
---------------------

None

Developer impact
----------------

Consumers like Cinder, Nova and HTTP store need to modify code to call the
new client functions to access the API.
Some of the key things to consider while implementing consumer side changes
are:

* We will use SDK to make the API calls. The changes to call new
  location APIs will be in SDK and also in OSC/glanceclient for location
  ADD in case of HTTP store.
* Keep backward compatibility with old behavior. Glance should support
  the legacy behavior as well as the new way to add/get locations. This is
  useful in upgrade cases where one compute node is running 2023.1 (Antelope)
  code and the other compute node has been upgraded to 2024.1 (CC) release.
* Testing should be done to see if the existing functionalities supported
  with the legacy location APIs works as expected with the new APIs.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  pdeore

Other contributors:
  whoami-rajat

Work Items
----------

* Add 2 new Location APIs for add and get operations.

* Modify consumers like cinder and nova and http store to use the new location
  APIs.

* Add a new configuration parameter ``do_secure_hash`` in glance and document
  it's impact.

* Add a new configuration parameter ``http_retries`` in glance and document
  it's usage.

* Add SDK support to call the new APIs.

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

.. [3] https://review.opendev.org/c/openstack/glance-specs/+/840882/2..15/specs/zed/approved/glance/new-location-info-apis.rst#b199

.. [4] https://specs.openstack.org/openstack/glance-specs/specs/stein/implemented/glance/spec-lite-locations-with-validation-data.html

.. [5] https://docs.openstack.org/glance/latest/contributor/api/glance.common.location_strategy.store_type.html

.. [6] https://review.opendev.org/c/openstack/glance-specs/+/881951

.. _Delete Image From Store: https://docs.openstack.org/api-ref/image/v2/index.html?expanded=delete-image-from-store-detail#delete-image-from-store

* Deprecate `show_multiple_locations` option | https://review.opendev.org/c/openstack/glance/+/313936

* Update deprecated show_multiple_locations helptext | https://review.opendev.org/c/openstack/glance/+/426283

* Update show_multiple_locations deprecation note | https://review.opendev.org/c/openstack/glance/+/625702

* Original security bug | https://bugs.launchpad.net/ossn/+bug/1549483

* New security bug | https://bugs.launchpad.net/ossn/+bug/1990157
