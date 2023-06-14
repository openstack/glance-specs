..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==============================================
Add support to configure weight for each store
==============================================

https://blueprints.launchpad.net/glance-store/+spec/store-weight

Add support to configure weight to each store. The store with highest
weight will be given preference to download the image.


Problem description
===================

Since introduction of importing single image into multiple stores or copying
existing image into multiple stores, single image can be stored at multiple
locations or different stores configured by glance.  Current download image
is based on the default ``location_strategy`` which is ``location_order``,
traverse through the image locations one by one if there are multiple
locations (in this case it will return the image stored at the first
location). If user prefers to download the image from a specific store then
they can use ``store_type`` as location strategy to give preference to
download the image from that store only. For example if ``location_strategy``
is set as ``store_type`` and ``store_type`` has `rbd` as preference then
the image will be downloaded from the `rbd` store only. Now the problem with
``store_type`` location strategy is that there can be multiple stores of same
type (multiple rbd or file stores). So again user will not able to download
the image from the specific store even if ``location_strategy`` is set to
``store_type``.

Consider the following use cases for providing download from specific
store support:

* I have a large image and want to download it from the SSD store
  since it's fast.
* I do multiple concurrent downloads on a particular image so
  want to download it from the RELIABLE store since the i/o
  handling is better.

Proposed change
===============

This proposal requires changes in glance_store as well as in glance.

Glance store side change:

Add new configuration option ``weight`` default to zero for each store.
Operator can change it for each store if they wish. The store with highest
weight will be given preference to download the image from.

.. code-block:: none

[default]
enabled_backends = robust:rbd,cheap:file

[robust]
rbd_store_pool=images
weight=10

[cheap]
filesystem_store_datadir=/opt/stack/data/glance/images/
weight=5

In above example, `robust` store will always be a preferred store to download
the image from. If image is not available in `robust` store then it will be
searched in `cheap` store which is next inline.

If no weight is provided for stores (i.e. all stores have default weight `0`)
then the image will be searched based on image creation order (similar as
``location_order``).

Glance side change:

Once glance_store side changes are implemented then we need to modify
``GET`` API of image to sort the image locations based on the `wegith`
assigned to each store. If `weight` is default then the location
order will not be changed.

Alternatives
------------

Add new location strategy 'store_identifier' to existing default two
strategies. This will add comma separated list of store identifiers which
will be given preference to download the image from. New configuration
option ``store_identifier_preference`` under group
``store_identifier_location_strategy`` will be added where user/deployer
can reference their preferences based on store identifiers.

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

None

Notifications impact
--------------------

None

Other end user impact
---------------------

None

Performance Impact
------------------

None

Other deployer impact
---------------------

Deployer/Operator need to configure `weight` for each glance-store.

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  dansmith

Other contributors:
  abhishek-kekane

Work Items
----------

* Add new configuration option `weight` for each store
* GET API change to sort locations based on store `weight`
* Unit and functional tests
* Tempest coverage


Dependencies
============

None


Testing
=======

Sufficient unit/functional and tempest tests will be added.


Documentation Impact
====================

Need to document how location order will be changed based on weight
assigned to each store.


References
==========

None