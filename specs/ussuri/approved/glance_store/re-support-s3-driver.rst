..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

============================================
Re-support S3 Driver as Glance Store Backend
============================================

https://blueprints.launchpad.net/glance/+spec/re-support-s3-driver

Glance store had supported S3 backend until version Mitaka, and it has already
been removed (in Newton [1]_) due to lack of maintainers. However, there seems
to exist a certain number of operators who want to use S3 for the glance
backend because S3 is a major storage and there is a lot of S3 compatible
storage. So, I propose revive the S3 driver and support again as a member of
glance store drivers [2]_.

Problem description
===================

There seems to exist a certain number of operators who want to use S3 or S3
compatible storage for the glance backend, but glance doesn't support S3 store
anymore so there is no way to use the S3 backend for them.

Proposed change
===============

Revive the S3 Store Driver that was used until Mitaka, and support multiple
store configuration [3]_.

The following configurations would be added to glance_store section of
glance-api.conf:::

  * s3_store_host
    The host where the S3 server is listening.
    This item accepts a string value.
    (e.g. s3-region.amazonaws.com, http://s3-region.amazonaws.com, https://s3-region.amazonaws.com or
    my-object-storage.com, http://my-object-storage.com, https://my-object-storage.com)

  * s3_store_access_key
    The S3 query token access key.
    This item accepts a string value.

  * s3_store_secret_key
    The S3 query token secret key.
    This item accepts a string value.

  * s3_store_bucket
    The S3 bucket to be used to store the Glance data.
    This item accepts a string value, and if s3_store_create_bucket_on_put is
    set to true, it will be created automatically even if the bucket does not
    exist.
    It is desirable to have a DNS-compliant naming convention.

  * s3_store_create_bucket_on_put
    A boolean to determine if the S3 bucket should be created on upload if it
    does not exist or if an error should be returned to the user.
    This item accepts True or False.

  * s3_store_bucket_url_format
    The S3 calling format used to determine the bucket. Either 'auto' or 'path'
    or 'virtual' can be used.
    In 'path'-style, the endpoint for the object looks like 'https://s3.amazonaws.com/bucket/example.img' or 'https://my-object-storage.com/bucket/example.img'.
    And in 'virtual'-style, the endpoint for the object looks like 'https://bucket.s3.amazonaws.com/example.img' or 'https://bucket.my-object-storage.com/example.img'.
    If you do not follow the DNS naming convention (e.g. that includes '.' in
    the bucket name), you can get objects in the path style, but not in the
    virtual style.

  * s3_store_large_object_size
    What size, in MB, should S3 start chunking image files and do a multipart
    upload in S3.
    This item accepts a positive integer value.

  * s3_store_large_object_chunk_size
    What multipart upload part size, in MB, should S3 use when uploading parts.
    The size must be greater than or equal to 5M.
    Note that the maximum possible number of image divisions is 10,000.

  * s3_store_thread_pools
    The number of thread pools to perform a multipart upload in S3.
    This item accepts a positive integer value.

As a result, operator can configure multiple stores including S3 as shown
below:::

    [DEFAULT]
    # list of enabled stores identified by their property group name
    enabled_backends = fast:s3, cheap:s3, reliable:file

    # the default store, if not set glance-api service will not start
    default_backend = fast

    # conf props for file system store instance
    [reliable]
    filesystem_store_datadir = /var/lib/images/data/
    description = Reliable filesystem store
    # etc..

    # conf props for s3 store instance
    [fast]
    s3_store_host = https://s3.amazonaws.com
    s3_store_access_key = access-key-for-fast
    s3_store_secret_key = secret-key-for-fast
    s3_store_bucket = bucket-for-fast
    # etc..

    # conf props for s3 store instance
    [cheap]
    s3_store_host = https://my-object-storage.com
    s3_store_access_key = access-key-for-cheap
    s3_store_secret_key = secret-key-for-cheap
    s3_store_bucket = bucket-for-cheap
    # etc..

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

This change will have to be explicitly configured in the store options.


Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  nao-shark

Work Items
----------

* Add configurations to glance-api.conf (s3_store_host, s3_store_access_key,
  s3_store_secret_key, s3_store_bucket, etc).

* Revive the S3 driver and unit test that were used until Mitaka,
  and support multiple store configuration.

* Documentation on how to use and configure S3 backend.

Dependencies
============

None


Testing
=======

* Test uploading of an image to the S3 backend.

* Then test downloading of the image again.

* Test delete the image.

* Test configure multiple s3 drivers.

Documentation Impact
====================

The documentation should be expanded to describe how to enable and use the S3
store.

References
==========

.. [1] Newton Series Release Notes
       https://docs.openstack.org/releasenotes/glance/newton.html

.. [2] Glance Store Drivers
       https://docs.openstack.org/glance_store/latest/user/drivers.html

.. [3] multi-store backend support
       https://specs.openstack.org/openstack/glance-specs/specs/rocky/implemented/glance/multi-store.html
