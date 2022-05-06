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

Currently we have a security vulnerability with ``show_multiple_locations``
config option, OSSN-0065 [1]_. If we enable ``show_multiple_locations`` and
the policies for add/update (set_image_location), get (get_image_location) and
remove (delete_image_location) locations are set for non-admins then non-admin
users can modify location data to corrupt an image that they own. Note that the
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

3. Remove ``show_multiple_locations`` config option when it is no longer
   required by other services (cinder/nova) to perform operations on
   locations.

The config option ``show_multiple_locations`` has been deprecated since Newton
but we will keep the config option until the consumers of glance locations
(nova, cinder etc) start using the new location APIs.

We will introduce 2 new policies for each API performing different operations
like add and get which will default to the ``service`` role for authorization.

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

None

Data model impact
-----------------

None

REST API impact
---------------

We are going to add 2 new location APIs:

* Add Location

  This will add a new location to an existing image.

  POST /v2/images/{image_id}/locations

  * JSON request body

    .. code-block:: json

        {
            "url": "cinder://lvmdriver-1/0f031ed1-5872-43d5-a638-4b0d07c10ab5",
        }

  * JSON response body

    - Success - 200

    .. code-block:: json

        {
            "url": "cinder://lvmdriver-1/0f031ed1-5872-43d5-a638-4b0d07c10ab5",
            "metadata": "{'store': 'lvmdriver-1'}"
        }

    - Error - 409 (Location already exists), 403 (Forbidden for users)

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

    - Error - 404 (Image ID does not exist)


Security impact
---------------

None. All APIs will only allow authorization to a context with ``service``
role which will be only supplied by the consumer services of glance locations
like cinder and nova.

Notifications impact
--------------------

None

Other end user impact
---------------------

Since the new APIs are for service to service interaction, there is not much
value to expose them via CLI. We will add methods to the client
(that will call the new location APIs) that will be used by other services
like cinder and nova but those methods won't be exposed via the shell to end
users. End users can still use the existing commands (that internally calls
the image-update API) to perform operations on locations:

* ``glance location-add:`` Add a location (and related metadata) to an image.
* ``glance location-delete:`` Remove locations (and related metadata) from an image.
* ``glance location-update:`` Update metadata of an image's location.

Performance Impact
------------------

None

Other deployer impact
---------------------

None

Developer impact
----------------

Consumers like Cinder and Nova need to implement code to call the new APIs
for location operations.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  mrjoshi, whoami-rajat

Other contributors:
  None

Work Items
----------

* Add 2 new Location APIs for add and get operations.

* Modify consumers like cinder and nova to use the new location APIs.

* Add a releasenote mentioning that we will remove the config option
  ``show_multiple_locations`` when the consumers (nova/cinder) shift to using
  new location APIs.

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

.. _Delete Image From Store: https://docs.openstack.org/api-ref/image/v2/index.html?expanded=delete-image-from-store-detail#delete-image-from-store

* Deprecate `show_multiple_locations` option | https://review.opendev.org/c/openstack/glance/+/313936

* Update deprecated show_multiple_locations helptext | https://review.opendev.org/c/openstack/glance/+/426283

* Update show_multiple_locations deprecation note | https://review.opendev.org/c/openstack/glance/+/625702

* Original security bug | https://bugs.launchpad.net/ossn/+bug/1549483