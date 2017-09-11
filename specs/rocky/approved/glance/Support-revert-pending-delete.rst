..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===================================
Support revert pending delete image
===================================

https://blueprints.launchpad.net/glance/+spec/pending-delete-rollback

Glance support soft delete images. If this feature is enabled, when users
delete an image, the image and its locations will first be in a special
`pending_delete` status that is not displayed in the API response. Then the
image will be deleted by ``glance-scrubber`` process in period. But now, there
is no way to revert/rollback the `pending_delete` images to `active`.


Problem description
===================

Delayed_delete feature is usually used when the image is too large to delete at
once. With this feature, then the image data will not be deleted at once and
will be cleaned by ``glance-scrubber`` process. The problem is that there is no
way to revert the delete action if the image is deleted by mistake. The only
way admin operator can do is to wait until the image data is deleted and then
reupload image data again.


Proposed change
===============

This proposal aims to recover an image which is in `pending_delete` state so
as to provide the revert capability for the purposes of allowing emergency
operational action to recover an accidental delete. It is important to keep in
mind, however, that whether the recovery of a particular image will be possible
or not depends upon Glance configuration option settings and quick operator
action.

Since the `pending_delete` image will be only deleted by ``glance-scrubber``
and it's an admin action, there is no need to expose a new API. A better way is
to enhance ``glance-scrubber`` to support restoring the image from
`pending_delete` status to `active`.

A new parameter called `--restore` will be added to ``glance-scrubber``
command. The usage is like: `glance-scrubber --restore <image_id>`.
``glance-scrubber`` first checks to see if the scrubber process is running, if
so, an error message that there is a scrubber currently running and you must
kill it first & scrubber terminates will be raised to admin. If not, scrubber
will switch image status from `pending_delete` to `active`.

Please be sure that the ``glance-scrubber`` daemon is killed before restore
the `pending_delete` image to avoid image data inconsistency. After restoring
the image, ``glance-scrubber`` daemon can be restarted.

Limitations
-----------

This is intended as an emergency operation for the use case where an operator
inadvertently deletes an important image and immediately realizes the mistake
and takes action within the ``scrub_time`` seconds set in the glance-api.conf
file.  The `pending-delete` status is a purely internal Glance status and the
image still shows as being in `deleted` status in API responses.  Thus there is
no way to tell via the API whether an image may be restorable or not.

Further, when the image is restored, some of its metadata is irrecoverable. Any
additional properties, tags, or members will not be restored.  In other words,
this is purely a possible data recovery operation, not a full image restore.

Alternatives
------------

The alternative way which is not recommend is to create a new API to revert the
`pending_delete` images:::

  POST /v2/images/{images_id}/actions/revert

The response body could be like:::

    Response: 200 OK
    {
        "status":"active",
        "name":"cirros-0.3.1-x86_64-uec",
        "tags":[
        ],
        "kernel_id":"be50418b-a03c-4947-9122-b80a57f47ac4",
        "container_format":"ami",
        "created_at":"2017-09-11T08:42:14Z",
        "ramdisk_id":"e1256074-9f7b-4067-8356-4a5759c1db11",
        "disk_format":"ami",
        "updated_at":"2017-09-11T08:42:16Z",
        "visibility":"public",
        "self":"/v2/images/26c16e07-24ca-4abc-a523-bec068012363",
        "protected":false,
        "id":"26c16e07-24ca-4abc-a523-bec068012363",
        "file":"/v2/images/26c16e07-24ca-4abc-a523-bec068012363/file",
        "checksum":"f8a2eeee2dc65b3d9b6e63678955bd83",
        "min_disk":0,
        "size":25165824,
        "min_ram":0,
        "schema":"/v2/schemas/image"
    }


Data model impact
-----------------

Allow image status changing from `pending_delete` to `active`.

REST API impact
---------------

None.

Security impact
---------------

This is an administrator action. No security impact at all.

Notifications impact
--------------------

None.

Other end user impact
---------------------

There is no impact for non-admin users. For administrators, they'll have the
ability to rollback the image's status from `pending_delete` to `active` by
``glance-scrubber`` tool.

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

wangxiyuan(wangxiyuan@huawei.com)

Work Items
----------

* change ``glance-scrubber`` to include the `--restore <image_id>` option.
* change the image status transition to allow:  `pending_delete` ->  `active`
* Update the related documentation and test.
* Release note should be added.

Dependencies
============

None


Testing
=======

Related unit test should be added.


Documentation Impact
====================

Related doc should be updated.


References
==========

None.
