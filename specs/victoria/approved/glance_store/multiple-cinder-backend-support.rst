..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==================================================
Make cinder driver compatible with multiple stores
==================================================

https://blueprints.launchpad.net/glance_store/+spec/multiple-cinder-backend-support

From Train onwards Glance is fully supporting configuring multiple glance
stores. Glance can configure to use cinder as a store using available cinder
driver of glance_store. Cinder makes available volume-types, which describe
the characteristics of volumes. Currently, the cinder glance_store can only
use one volume-type. The point of glance multi-store implemented in Train
is to give operators the ability to expose glance stores of differing
characteristics to end users. Even though all images will wind up in a single
cinder installation, it is possible for operators to expose different
categories of storage in cinder by creating different volume-types.
So when a cinder installation exposes multiple volume-types of differing
characteristics, what we want to do here is to be able to map different glance
'stores' to cinder volume-types.

Problem description
===================

1. As of now cinder can configure different volume-types but glance will be able
to use only one of those available volume-types. If glance store is
set to use cinder then every time new image is created it will always be
uploaded to default volume-type unless operator has configured
``cinder_volume_type`` in glance-api.conf file.

2. If cinder store is configured to use in glance then while creating the
image cinder store of glance creates location URL with ``cinder://`` prefix
only. When cinder has configured multiple backends and glance has also
configured multiple cinder stores then it is difficult to analyse
the image is stored in which of the cinder store as the location url
for the image as ``cinder://<image_id>``.


Proposed change
===============

We propose that Glance be able to expose multiple cinder stores that differ
by what volume-type each store uses. These would be defined in the normal way
in the glance configuration file using the ``enabled_backends`` option
(see example below). Further, when using multiple glance stores, each cinder
store *must* have the ``cinder_volume_type`` option set.

While initializing the store object, glance will validate that volume type
set using ``cinder_volume_type`` is exist in cinder. If it's not then that
store will be excluded by disabling 'add' and 'delete' operations. To
connect to cinder from glance operator needs to specify
``cinder_store_auth_address``, ``cinder_store_user_name``,
``cinder_store_password`` and ``cinder_catalog_info`` for each of the store
in glance-api.conf file.

Below are some multiple cinder store configuration examples.

Example 1: Fresh deployment

For example, if cinder has configured 2 volume types ``glance-fast`` and
``glance-slow`` then glance configuration should look like;::

    [DEFAULT]
    # list of enabled stores identified by their property group name
    enabled_backends = fast:cinder,slow:cinder

    # the default store, if not set glance-api service will not start
    [glance_store]
    default_backend = fast

    # conf props for fast store instance
    [fast]
    rootwrap_config = /etc/glance/rootwrap.conf
    cinder_volume_type = glance-fast
    description = Really fast and expensive storage
    cinder_catalog_info = volumev2::publicURL
    cinder_store_auth_address = http://localhost/identity/v3
    cinder_store_user_name = glance
    cinder_store_password = admin
    cinder_store_project_name = service
    # etc..

    # conf props for slow store instance
    [slow]
    rootwrap_config = /etc/glance/rootwrap.conf
    cinder_volume_type = glance-slow
    description = Slower but less expensive storage
    cinder_catalog_info = volumev2::publicURL
    cinder_store_auth_address = http://localhost/identity/v3
    cinder_store_user_name = glance
    cinder_store_password = admin
    cinder_store_project_name = service
    # etc..

Example 2: Upgrade from single cinder store to multiple cinder stores, if
default_volume_type is set in cinder.conf and cinder_volume_type is also set in
glance-api.conf then administrator needs to create one store in glance where
cinder_volume_type same as old glance configuration::

    # cinder.conf
    The glance administrator has to find out what the default volume-type is
    in the cinder installation, so he/she needs to discuss with either cinder
    admin or cloud admin to identify default volume-type from cinder and then
    explicitly configure that as the value of ``cinder_volume_type``.

Example config before upgrade::

    [glance_store]
    stores = cinder, file, http
    default_store = cinder
    cinder_state_transition_timeout = 300
    rootwrap_config = /etc/glance/rootwrap.conf
    cinder_catalog_info = volumev2::publicURL
    cinder_volume_type = glance-old

Example config after upgrade::

    [DEFAULT]
    enabled_backends = old:cinder, new:cinder

    [glance_store]
    default_backend = new

    [new]
    rootwrap_config = /etc/glance/rootwrap.conf
    cinder_volume_type = glance-new
    description = Newly defined second (cinder) store
    cinder_catalog_info = volumev2::publicURL
    cinder_store_auth_address = http://localhost/identity/v3
    cinder_store_user_name = glance
    cinder_store_password = admin
    cinder_store_project_name = service
    # etc..

    [old]
    rootwrap_config = /etc/glance/rootwrap.conf
    cinder_volume_type = glance-old # as per old cinder.conf
    description = Previously existing (cinder) store
    cinder_catalog_info = volumev2::publicURL
    cinder_store_auth_address = http://localhost/identity/v3
    cinder_store_user_name = glance
    cinder_store_password = admin
    cinder_store_project_name = service
    # etc..

Operator can decide on the basis of deployment strategy which volume type
they wants to use by coordinating with cinder admin or cloud operator.

We also propose to modify location url for cinder and use
``store identifier`` in location url so that user or operator will
identify in which cinder store of glance image is stored. The new
location URL should looked like ``cinder://store-name/image-id``.

For legacy images stored in cinder backend we will modify the lazy loading
mechanism of glance which will update the location URL of existing images
as per new format. The lazy loading operation is a check before
GET API call which traverse through image location and based on location URI
it identifies in which glance store image data is stored and updates
that information in location metadata. This mechanism is also useful
in a way that if in future operator decides to change the name of the
glance store or retire one of the configured store by migrating the
images to new stores.

Alternatives
------------

None

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

The security impact is same as it was with single store but we're just
pointing it out here; The image-volume is stored in the configured
project ``cinder_store_project_name`` and can be accessed with configured
user ``cinder_store_user_name``.

There could be a potential risk if someone was able to get a hold of
these credentials and access the image-volumes. Worst case is someone
could alter the image-volumes if they had permission to perform any cinder
operation on it such as retype, attach etc.

Care will have to be taken to ensure it isn't accessible by normal
users.

Notifications impact
--------------------

None

Other end user impact
---------------------

None

Performance Impact
------------------

After upgrade from single cinder store to use multiple cinder stores first
image-list or first get call for image will take additional time as we are
performing the lazy loading operation to update legacy image location url
to use new image location urls. Subsequent get or list calls will perform
as they were performing earlier.

Other deployer impact
---------------------

Operators should be aware of different volume types available in cinder. They
can either use ``type-list`` command of cinder client or coordinate with cinder
admin and decide which volume-type of cinder should be configured in
glance-api.conf.

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
* whoami-rajat
* abhishek-kekane

Other contributors:
  None

Reviewers
---------

Core reviewer(s):

* jokke
* rosmaita
* smcginnis

Work Items
----------

* Modify cinder driver initialization to set new cinder location url
* Modify usage of cinder location url
* Modify lazy loading mechanism to update legacy image location URLs
* Unit tests

Dependencies
============

None


Testing
=======

Appropriate unit and functional tests to ensure the changes to glance function
correctly. Aslo we could add a job which will run tests using cinder stores in
glance.

Documentation Impact
====================

We'll need to ensure that glance/glance_store docs are updated for:

* Usage of cinder volume types as cinder stores of glance.
* We should also document that, if cinder store is used as glance
  backend, Only the Image Service API should be used to manipulate images.
  Manipulating image data directly via the Block Storage Service API is not
  supported and may lead to adverse consequences, including data loss.
* How to upgrade from single cinder store to multiple cinder stores.

References
==========

None
