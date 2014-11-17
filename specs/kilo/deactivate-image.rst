======================================================
Provide the ability to temporarily deactivate an image
======================================================

https://blueprints.launchpad.net/glance/+spec/deactivate-image

This blueprint provides for a method to deactivate an image temporarily
to prevent download of image data (including booting a new instance from
the image). A method for reactivation is also described.


Problem description
===================

As the ability for users to import images from outside the cloud becomes
commonly available, a concern is the possibility for a user to import
a malicious or otherwise problematic image (e.g. an image containing a
trojan horse). If an image is deemed suspicious, an admin should be able to
put the image "on hold" preventing instances from being built with it until
it has be properly examined and determined to be safe or found dangerous and
deleted. All image properties will remain accessible and editable, but the
image will not be downloadable by non-admin users.


Proposed change
===============

To expose this ability, a new image state 'deactivated' will be introduced.
In order to transition into and out of this state, two new functional API
calls will be added to the REST interface (detailed below).

When an image is placed in the deactivated state, image data may not be
downloaded by a non-admin user. This will include all other operations (such
as export and cloning) which may need access to image data. Admins may continue
to download the data to facilitate testing and examination of the image.
Operations which do not access image data (e.g. update, delete, or image-list)
continue to operate as usual for deactivated images.

Only 'active' images may be deactivated. Images in the 'deactivated' state
may only transition to 'active' or 'deleted'. Deactivating a 'deactivated'
image or reactivating an 'active' image will succeed as no-ops.

Restrictions to the deactivate and reactivate functions can be handled through
the current policy mechanisms and thus the responsibility falls to the deployer
to implement / update the applicable policies per their specific requirements.
By default, only administrators will have permissions sufficient to deactivate
and reactivate an image.


Alternatives
------------

No alternatives seem to be readily available. Policy changes were considered
but this is an action which needs to function on an image-by-image basis
regardless of role (other than admin) and across accounts (in the case of
shared images).


Data model impact
-----------------

None


REST API impact
---------------

The design for the deactivate and reactivate calls specified below follows the
controller pattern from Subbu Allamaraju, RESTful Web Services Cookbook
(O'Reilly, 2010), section 2.6. It was discussed by the OpenStack API Working
Group on the mailing list and at a series of meetings in February 2015. The
consensus was that this design is an appropriate pragmatic RESTful interface.

Using Glance tasks for deactivate/reactivate was discussed by the API WG, but
the consensus was that since Glance tasks are specifically designed for
asynchronous operations, their use was not appropriate here. The recommendation
is that any new asynchronous operations should be implemented in the tasks API,
but the controller pattern is appropriate for synchronous actions like
deactivate and reactivate.

The API WG concluded that this API design proposal was acceptable at its
meeting on 19 February 2015.

http://eavesdrop.openstack.org/meetings/api_wg/2015/api_wg.2015-02-19-00.00.log.html#l-146

* POST:/v2/images/{image_id}/actions/deactivate
  * Description: Deactivate an image
  * Method: POST
  * Normal response code(s): 204
  * Expected error http response code(s): 400

    * When calling deactivate on an image which is not currently in the 
      'active' or 'deactivated' state.

  * URL for the resource: /v2/images/{image_id}/actions/deactivate
  * Parameters which can be passed via the url
    {image_id}, String, The ID for the image.

* POST:/v2/images/{image_id}/actions/reactivate
  * Description: Reactivate an image
  * Method: POST
  * Normal response code(s): 204
  * Expected error http response code(s): 400

    * When calling reactivate on an image which is not currently
      in the 'deactivated' or 'active' state.

  * URL for the resource: /v2/images/{image_id}/actions/reactivate
  * Parameters which can be passed via the url
    {image_id}, String, The ID for the image.

* GET:/v2/images/{image_id}/file
  * Description: Downloads binary image data.
  * Method: GET
  * Normal response code(s): 200, 204
  * Expected error http response code(s): 403
 
   * When attempting to download a deactivated image

  * URL for the resource: /v2/images/{image_id}/file
  * Parameters which can be passed via the url
    {image_id}, String, The ID for the image.

* GET:/v2/images/{image_id}
  * Description: Retrieve the image metadata
  * Method: GET
  * Normal response code(s): 200

    * Retrieving image metadata for a deactivated image will continue
      to function normally

  * Expected error http response code(s): None
  * URL for the resource: /v2/images/{image_id}
  * Parameters which can be passed via the url
    {image_id}, String, The ID for the image.

* GET:/v1/images/{image_id}
  * Description: Returns the image details as headers and the image binary in the body of the response.
  * Method: GET
  * Normal response code(s): 200
  * Expected error http response code(s): 403

    * When attempting to download a deactivated image

  * URL for the resource: /v1/images/{image_id}
  * Parameters which can be passed via the url
    {image_id}, String, The ID for the image.

* HEAD:/v1/images/{image_id}
  * Description: Retrieve the image metadata
  * Method: HEAD
  * Normal response code(s): 204

    * Retrieving image metadata for a deactivated image will continue
      to function normally

  * Expected error http response code(s): None
  * URL for the resource: /v1/images/{image_id}
  * Parameters which can be passed via the url
    {image_id}, String, The ID for the image.


Security impact
---------------

This change enhances security of the overall system by giving administrators
the ability to suspend usage of potentially malicious images while they are
being audited.

There are no negative security impacts.


Notifications impact
--------------------

None


Other end user impact
---------------------

Support for the new API operations should be added to python-glanceclient.

End users will be unable to perform any operations on a deactivated image which
requires access to the image data. This would include downloading, booting, and
exporting the image.

Performance Impact
------------------

None


Other deployer impact
---------------------

In order to restrict access to these operations, deployers will need to
configure the 'deactivate' and 'reactivate' policies accordingly.


Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  eddie-sheffield

Other contributors:
  None

Reviewers
---------

Core reviewer(s):
  nikhil-komawar

Other reviewer(s):
  hemanth-makkapati

Work Items
----------

* Add allowed state transistions
* Add image actions controller to v2 api
* Add 'deactivate' action to controller and router
* Add 'activate' action to controller and router
* Add policy checks for 'deactivate' and 'reactivate'
* Add check for deactivated image on download to v2 api
* Add check for deactivated image on download to v1 api


Dependencies
============

None


Testing
=======

Tempest tests for the new operations and verifying download restrictions on
deactivated images need to be added.


Documentation Impact
====================

Documentation is required for:

* The new API functions
* The new policies (as described in Other Deployer Impact)


References
==========

Earlier version of this spec from the wiki:
* https://wiki.openstack.org/wiki/Glance-deactivate-image

Discussions concerning the "Function API" approach used here:
* https://etherpad.openstack.org/p/glance-adding-functional-operations-to-api
* http://lists.openstack.org/pipermail/openstack-dev/2014-May/036416.html
* http://osdir.com/ml/openstack-dev/2015-02/msg01563.html
* "RESTful Web Services Cookbook, Section 2.6" - http://it-ebooks.info/book/392/
