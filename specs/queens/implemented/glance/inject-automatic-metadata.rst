============================================================
Inject metadata properties automatically to non-admin images
============================================================

https://blueprints.launchpad.net/glance/+spec/inject-automatic-metadata

Cloud operator wants to launch a VM based on certain image metadata properties
on different compute nodes.

Problem description
===================

The operator provides public images to the users and users can also add their
own images in glance and use these images to launch VMs. As an operator, all
images provided by an operator should be launched on a specific set of compute
nodes whereas images that are created by non-admin users should be launched
on other set of compute nodes. The decision to launch VMs on certain compute
nodes will be decided based on image metadata. When an operator will create
images, they can specify certain image metadata which will be used by
placement api or scheduler service to decide where the vm should be launched
but if user creates image, there is no way user will know what image metadata
properties to set  and hence in the present placement api and scheduler logic,
it is possible to launch a VM on any compute nodes. This is a big problem.

Use Case:
---------

The operator wants user based images to be launched on certain set of compute
nodes (host aggregate groups) based on image metadata properties.

Proposed change
===============

Make a provision to inject image metadata to non-admin images while adding
image to glance backend with the help of property protection. We are planning
to introduce two new config options to achieve the same.
1) 'ignore_user_roles' is a comma-separated list of roles. Defaults to admin.
2) 'inject' defaults to None.

'inject' config option will consist of json format (key: value pair) of image
metadata which an operator wants to add to the newly created images if
user role is not as per mentioned in 'ignore_user_roles' config option. If
user role is not same as mentioned in 'ignore_user_roles' and 'inject' doesn't
contain any metadata properties, then no metadata will be injected to the
non-admin images.

We propose to create new config file 'glance-image-import.conf' which will
have all config options related to image import tasks stuff. Each pluggable
task can have own section which define its configuration options in this file.

For example, for injecting metadata properties 'glance-image-import.conf'
will have 'property_injections' section described below;

[inject_metadata_properties]
ignore_user_roles = admin,...
inject = { "property1": "value", "property2": "value,another value" }

Note:
When user creates a volume from image, all image metadata will be copied to
volume and made available as volume_image_metadata. Now, when user will copy
back a volume to image, it will attempt to add 'property1' metadata and it
will fail as it is only allowed to be created by admin. To address this issue
need to make provision like ignore all properties specified in 'inject'
config option if the request comes from a user whose roles is not specified
in 'ignore_user_roles config option. For example when user performs
copy back volume to image then if properties mentioned in inject option
will be silently ignored i.e. newly created image from volume does not contains
special metadata properties mentioned in 'inject' config option.

[some_other_yet_undefined_task]
will_have = "it's own configs"

We will use property protection so that non-admin user won't be able to
add, update or delete the injected metadata properties automatically. Non-admin
users however will be able to view these metadata properties. For example
if 'inject' is set to 'property1=value' then in property_protections.conf
file, an operator needs to restrict write and delete access for 'property1'
to non-admin users as described below:

[property1]
create = admin
read = admin,member,_member_
update = admin
delete = admin

In glance, users can create images using two ways.
1) create image API
2) Import image API

In case of import image API, as it uses taskflow, an additional task
'InjectMetadataProperties' will be created to inject the metadata. If
'inject' property is not None, then only 'InjectMetadataProperties' will be
part of the tasks, otherwise it will be simply ignored.

No changes will be made to create image API. The intent is that the old upload
workflow will only be used by services, it won't be exposed to end users in
most deployments.

Note: There is a restriction on how many image metadata properties an user
can set to a image which is configurable using 'image_property_quota'
config option. If it's value is 128 and say, if 'inject' config option count
is 3, then user would be able to add only 125 metadata items by themselves and
remaining 3 will be injected automatically. If user tries to add more than
125 metadata items in case of import image api call then the task will
marked as failed with appropriate failure message.

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

There is a limit on having additional image metadata properties which defaults
to 128. This is configurable using 'image_property_quota' option. If an
operator sets this limit to higher value and more metadata properties are
injected, then it will impact performance during image-list or image-show
calls.

This impact is not specifically a result of the proposal in this spec, it's
also the case under the current situation.

Other deployer impact
---------------------

Administrator need to set 'ignore_user_roles' and 'inject' config options in
'inject_metadata_properties' section of 'glance-image-import.conf' config file
if metadata properties to be injected for new images for non-admin users.

Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  <bhagyashri-shewale>

Other contributors:
  None

Reviewers
---------

Core reviewer(s):
    Erno Kuvaja, Brian Rosmaita

Other reviewer(s):
    None

Work Items
----------

- Make provision to read config options from new glance-image-import.conf
- Add two new config options
- Add 'InjectMetadataProperties' task for import call
- Add unit tests for coverage
- Add functional tests

Dependencies
============

None

Testing
=======

Functional tests will be added to verify that metadata will be injected for
non-admin images only.

Documentation Impact
====================

Please refer to 'Other deployer impact'

References
==========

None

