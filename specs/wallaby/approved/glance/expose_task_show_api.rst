..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.
 http://creativecommons.org/licenses/by/3.0/legalcode

========================================================
New Image API /v2/images/{id}/tasks for task information
========================================================

https://blueprints.launchpad.net/glance/+spec/messages-api

The image service now supports importing images or copying existing images
in multiple glance stores using glance tasks, but there is restriction that
only one import operation or copy operation is permitted simultaneously on
an image to avoid race condition.

Problem description
===================

Task APIs are not available to normal users. In Victoria we have fixed
race condition while copying existing images in  multiple stores which uses
"task-id" to obtain lock on the image to prevent other import operations on
the same image. The additional image property "os_glance_import_task" will
be used to store "task id". We are updating 'message' property of the task
which helps calculate time based on last updated time of task to burst the
lock as well as show how much data has been copied of that image. Copying
operation may take a long time and normal user can be clueless about when lock
will be busted or why his (other) requests are rejected without contacting to
the administrator.

Proposed chage
==============

Add new fields `image_id`, `request_id` and `user` fields to tasks database
and new API `/v2/images/{id}/tasks` which will fetch the tasks associated
with `image_id` of that image and returns it to the user. This new API will
return all tasks associated with image which are not expired. This expiration
time is calculated when task reaches a final state of `success` or `failure`
using `task_time_to_live` configuration parameter defined in glance-api.conf
file. If active task is not present for given image then it will return empty
list to user.

The `request-id` will effectively help user to find out what happened with
his request, why his request has been denied and which task is currently
being performed on the image.

The `user` field is an alternate to `request_id` field. In general client tools
can access/generate request-ids but possibility normal users don't have access
to the request-ids, in this case the `user` field will help them to identify
their particular task and its status. So from now on the tasks will
have either `request-id` or `user` or both associated with it.

More details on this API can be found in the REST API section of this spec.

Alternatives
------------

Add new API endpoint /v2/messages/{task_id} which will return related task
information to the user. In this case user have to know task_id in advance.
To know the task_id in advance he needs to call GET API of image to figure out
whether `os_glance_import_task` property is set on the image or not.

Another alternative is to expose task show API to all the users. At the moment
task API's are managed with two different policies; "tasks_api_access" and
then crud level policies such as "add_task", "get_tasks" etc. So in this case
we first need to expose `tasks_api_access` to all users (than admin) and then
need to expose individual level policies to end user. This might be confusing
and need to document carefully otherwise default access might be provided to
all task API's by mistake.

Data model impact
-----------------

This spec proposes to add `image_id`, `request-id` and `user` fields to tasks
database table. Those will be null and does not require any migration script
to add this information to existing records.

REST API impact
---------------

**New API**

* Show tasks associated with the given image, for example, information
  about all active (not expired) tasks associated with the image.

**Common Response Codes**

* Not Found: `404 Not Found` with details.

**API Version**

All URLS will be under the v2 Glance API.  If it is not explicitly specified
assume /v2/<url>

**[New API] Get tasks associated with image**

Show tasks associated with given image::

    GET /v2/images/{image_id}/tasks

This API takes no query parameters and when authorized returns
tasks associated with given image. If it does not found any
active task associated with the image then it will return empty list to
the user.
Example of the valid response::

    {
        "tasks": [
            {
                "task": {
                    "id": "ee22890e-8948-4ea6-9668-831f973c84f5",
                    "image_id": "dddddddd-dddd-dddd-dddd-dddddddddddd",
                    "request-id": "rrrrrrr-rrrr-rrrr-rrrr-rrrrrrrrrrrr",
                    "user": "uuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuu",
                    "type": "api_image_import",
                    "status": "processing",
                    "owner": "64f0efc9955145aeb06f297a8a6fe402",
                    "expires_at": null,
                    "created_at": "2020-12-18T05:20:38.000000",
                    "updated_at": "2020-12-18T05:25:39.000000",
                    "deleted_at": null,
                    "deleted": false,
                    "input": {
                        "image_id": "829c729b-ebc4-4cc7-a164-6f43f1149b17",
                        "import_req": {
                            "method": {"name": "copy-image"},
                            "all_stores": true,
                            "all_stores_must_succeed": false
                        }
                        "backend": [
                            "fast",
                            "cheap",
                            "slow",
                            "reliable",
                            "common"
                        ]
                    },
                    "result": null,
                    "message": "Copied 15 MiB"
                },
            }
        ]
    }

Response codes:

* 200 -- Upon authorization and successful request. The response body
  contains the JSON payload with the known stores.

Example curl usage::

        curl -g -i -X GET -H "X-Auth-Token: $token"
            -H "Content-Type: application/octet-stream"
            $image_url/v2/images/{image_id}/tasks

Security impact
---------------

None

Notifications impact
--------------------

None

Other end user impact
---------------------

This proposal introduces a few other user impacts worth noting.

**Glance client**
Ideally the glance client (CLI + REST client) should be updated in accordance
with this spec. Notably:

* CLI / API support for get task information from image.

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
  abhishek-kekane

Other contributors:
  None

Work Items
----------

Implementation tasks may consist of:

* Add expand script for adding new fields to `tasks` database
* Modify `tasks` data layer to use newly added fields
* Modify `tasks` CRUD operations to use newly added fields
* Add support for new API.
* Add python-glanceclient support
* Add API documentation for new API


Dependencies
============

None


Testing
=======

* Need to add new unit tests for coverage


Documentation Impact
====================

As mentioned in the 'work items' section, we'll need to ensure the glance docs
are updated for:

* The new get tasks from image REST API.
* Overall glance multi-store documentation to educate deployers on the
  feature and how/when it's used.


References
==========

* PoC - https://review.opendev.org/c/openstack/glance/+/763739
