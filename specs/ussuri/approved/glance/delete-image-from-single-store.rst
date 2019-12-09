..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

================================
Deleting image from single store
================================

Include the URL of your launchpad blueprint:

https://blueprints.launchpad.net/glance/+spec/delete-from-store

New API feature to remove image from single store instead of whacking the
whole image.


Problem description
===================

Currently only way to remove image from single store is by exposing known
problematic locations API and utilize that to remove the location. With
multiple-stores support there is definitely more user oriented use-cases
for removing image from specific store.


Proposed change
===============

Introduce new "/v2/stores" endpoint to Images API v2 to provide safe way to
delete images from the specific store.

New API call:
'DELETE /v2/stores/<StoreID>/<ImageID>'

Alternatives
------------

We could consider utilizing the current "v2/images/<ImageID>" endpoint and
append the store ID at the end of that. The risk with this approach is that
it's way too easy for the API user to make a mistake dropping the StoreID and
accidentally delete the whole image instead of just removing it from single
store.

Data model impact
-----------------

None

REST API impact
---------------

New API endpoint "v2/stores/<StoreID>/<ImageID>" that accepts only DELETE
http method.

The request will fail if this is the only location indicating that the
user should delete the image instead.

Security impact
---------------

This change does not have any know security impacts.

Notifications impact
--------------------

Notification of image being removed from the store can be considered.

Other end user impact
---------------------

python-glanceclient will have feature to support this API call.

Performance Impact
------------------

This feature has no know performance impacts.

Other deployer impact
---------------------

None

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  jokke

Work Items
----------

* API change for glance-api service

* Testing for the new feature

* python-glanceclient support

* Documentation needs to be updated including the new workflow

Dependencies
============

None


Testing
=======

The change will need unit and functional tests.


Documentation Impact
====================

None

References
==========

None
