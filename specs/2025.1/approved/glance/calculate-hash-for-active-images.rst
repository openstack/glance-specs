..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

============================
Implement Calculate Hash API
============================

https://blueprints.launchpad.net/glance/+spec/calculate-hash-api

Problem description
===================
There will be 2 cases when image will be in `active` state without
os_hash_value and checksum,

1. During the implementation of New Add Location API [1]_ it's been
   noticed that some images will remain in 'active' state without
   checksum and os_hash_value if the hash calculation is failed after
   adding the location to the image.
2. Some legacy images which are created by consumers like
   instance snapshot or volume snapshot(image created by upload volume
   operation when glance backend is cinder) may also not have checksum,
   os_hash_value and os_hash_algo set.

Currently there is no other way to calculate hash for such images.

Proposed change
===============

We are planning to add a separate new admin-only api to calculate the
os_hash_value and checksum for the image which are in `active` state.

This API will be handled as follows:

1. Since hash calculation will be a long running operation, it will be
   executed in the background in the async task by setting the value of
   `os_hash_algo` before caclulation process starts.
   If hash calculation fails, retry mechanism for hash calculation will
   be added by using existing configuration option ``http_retries`` for
   maximum retries. If after all the retries, the hash calculation still
   fails we will not update the hash and checksum values and image will
   stay in ``active`` state and `os_hash_algo` will be reverted back to
   `None`.
2. Incase delete image has been attempted during hash calculation of that
   image, there are different responses from stores while reading the data,

   * RBD throws `ImageNotFound` during data read but deletes the data from
     backend and image remains in active state even though delete call fails
     with `InUseByStore` error. There is a bug reported for this issue [1]_.
     In this case as a workaround hash calculation will be marked as failed
     with proper log message and the image will be marked as `deleted` if
     it's not marked as `deleted` by delete api.
   * Filesystem backend throws `NotFound` since delete operation is
     successful.
   * Swift allows image deletion during data reading or image-download.
   * Cinder backend does not allow to delete the image since while reading
     data or downloading the image from volume, volume will be in-use state.
   * Since this is async API call, admin can use API /v2/images/{id}/tasks
     to check the progress of the task.

We will introduce a new admin-only policy ``calculate_hash``.


Alternatives
------------

We can have a separate new command under glance-manage to run from cron.

Data model impact
-----------------

None

REST API impact
---------------

**New API**

* Calculate Hash

  This spec proposes the following new endpoint:

  POST /v2/images/{image_id}/hash

  * JSON request body

    .. code-block:: json

        {
            "os_hash_algo": "sha512"
        }

  * Response
    - Accepted - 202

    - Error - 409 (if image is not in ACTIVE state),
              403 (Forbidden for normal user)
              400 (BadRequest if invalid os_hash_algo passed)
              404 (Image ID does not exist)

Security impact
---------------

None

Notifications impact
--------------------

None

Other end user impact
---------------------

Changes in glanceclient and openstackclient will be required to expose
for admin users only.

Performance Impact
------------------

None

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
  pranali-deore

Other contributors:
  None

Work Items
----------

* Implement the API with unit/functional tests
* Document the API in api-ref
* Write a tempest test to check these API
* Implement support in OSC/SDK
* Implement support in glanceclient
* Add documentation for behaviour of new API

Dependencies
============

None

Testing
=======

* Unit and functional tests in Glance. Tempest tests against the same.

Documentation Impact
====================

The documentation needs to be updated with the new API extension and usage.

References
==========

.. [1] https://bugs.launchpad.net/glance/+bug/2045769

