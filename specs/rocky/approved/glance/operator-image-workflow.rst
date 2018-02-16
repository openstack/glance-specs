..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

====================================
Operator maintained images lifecycle
====================================

https://blueprints.launchpad.net/glance/+spec/hidden-images

This spec addresses the problem that cloud operators have into keep a
public image list with only the latest images versions available.

Problem description
===================

Cloud operators supply *public images* that can be used by end users to boot
servers.  An example is an image containing the CentOS 7 operating system.
Such images must be updated as security concerns, etc., are addressed.  In
Glance, however, image data is immutable, so each update results in a new
public image.  Further, operators do not want to delete the "old" public
images, as end users may require them for different use cases like server
rebuilds.  As a result, the default image-list for end users becomes very
large.  Further, the default image-list may contain multiple CentOS 7 images,
for example, making it difficult for end users to determine which image to
use.

.. note:: Example

    An operator provides an image for CentOS 7 with a standard set of packages
    as image 1. Some minor security problem is discovered in OpenSSL, so the
    operator provides image 2 of CentOS 7 with updated OpenSSL. Then a kernel
    vulnerability is discovered and the operator issues image 3 of CentOS 7
    with updated OpenSSL and a patched kernel. Each of these is a "version" of
    the image, but the same version of CentOS 7. The operator wants a new end
    user to start with image 3, but a user who's been around a while longer may
    want to continue to use image 1 and patch/upgrade himself (for example, the
    OpenSSL update brings in a dependency that conflicts with some key software
    the user is running).  If all three images have public visibility, then all
    three of them will appear in an end user's default image-list.

A current practice is to address this by adding a custom property on an
image, for example, ``"is_current": "yes"``, but this is operator-specific and
not interoperable.  This only solves part of the problem, however, because end
users must be educated to look for the ``"is_current"`` image property.  It
would be better if *only* those images with ``"is_current": "yes"`` were
included in the end user's default image-list in the first place.


Proposed change
===============

This spec proposes adding a new boolean column ``"hidden"`` in images table.
Images where ``"hidden" = True`` will be omitted from the image list presented
to the user. This will apply to all image visibilities.
However, the images will continue to be discoverable.

.. note:: Example

    An user wants a CentOS 7 provider image, so he uses:
    ``"?visibility=public"`` on the  ``GET v2/images`` call.
    He sees a CentOS 7 image, but notices that it was created_at today,
    so he realizes that it's not the same image that he's searching for.
    So now he uses ``"?visibility=public&hidden=true"`` to get the list of all
    available images.

If the image has ``"hidden" = False`` the image is not omitted from the image
list. It preserves the current behaviour.

At image creation, if not specified, it's used ``"hidden" = False``.

Changing the property "hidden" will be considered an image update. Because,
the policy is already defined for this operation no other changes are required.

All operations in the image will continue to be available considering the
policy defined.


Alternatives
------------

Instead using a new image property we can have a new visibility = "hidden".
Images with this new visibility state will not be in the default image list.
To list images with visibility "hidden" it will be required to explicitly
request it. Ex:
``"property --visibility=hide"``
Images with the visibility "hidden" will always be discoverable by the user.

This solution is less flexible because visibility "hidden" has potentially
the same scope as "public". The user roles that can use this visibility
need to be controlled by policy.

Another approach is to use the proposed new image property "hidden" but not
make these images discoverable with the API. However, there is the use case
where a project may require a particular image version (for example: different
OS releases like CentOS7.4 to CentOS7.5; appliance vendors that support their
software on particular images). If "hidden" images are not discoverable cloud
admins will need implement their own solution to expose these images.


Data model impact
-----------------

Add the "hidden" boolean column in images table.

For the E-M-C migration strategy is proposed:
- Triggers: not required. Queens release will reject an image-update call
setting 'hidden' with a 400 because it doesn't recognize the field.
- Expand: will add a boolean "hidden" column to the images table.
- Contract: not required
- Data Migration: set the "hidden" column to False in all rows.


REST API impact
---------------

A new property "hidden" will be accepted for the GET call.
GET v2/images ... hidden=true/false
By default the API will consider hidden=false.

Security impact
---------------

None

Notification impact
-------------------

None

Other end user impact
---------------------

The end user needs to be aware that the Cloud provider may "hide" old
images. This is specific to each Cloud provider.


Performance impact
------------------

None

Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
- Belmiro Moreira

Work Items
----------

- Add support in GET call for the property "hidden".
  Consider the default "hidden=false".
- Change the image table schema adding a new field.
- Change the glance-client to support the new property.

Dependencies
============

None

Testing
=======

TBD


References
==========

- https://review.openstack.org/#/c/327980
- https://review.openstack.org/#/c/108574
- https://review.openstack.org/#/c/508133