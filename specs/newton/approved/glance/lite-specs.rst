================
Glance Spec Lite
================

Please keep this template section in place and add your own copy of it between the markers.
Please fill only one Spec Lite per commit.

<Title of your Spec Lite>
-------------------------

:problem: <What is the driver to make the change.>

:solution: <High level description what needs to get done. For example: "We need to
           add client function X.Y.Z to interact with new server functionality Z".>

:impacts: <All possible \*Impact flags (same as in commit messages) or 'None'.>

Optionals (please remove this line and fill or remove the rest until End of Template):
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

:how: <More technical details than the high level overview of `solution` if needed.>

:alternatives: <Any alternative approaches that might be worth of bringing to discussion.>

:timeline: <Estimation of the time needed to complete the work.>

:link: <Link to the change in gerrit that already would provide the `solution`.
       After commiting the Spec Lite depend the change to the Spec Lite commit.>

:reviewers: <If reviewers has been agreed for the functionality, list them here.>

:assignee: <If known, list who is going to work on the feature implementation here>

End of Template
+++++++++++++++

Return 409 if setting location to saving or deactivated image
-------------------------------------------------------------

:problem: Currently, if 'show_multiple_locations' is activated,
          user can set custom location to an image, even if it
          has 'saving' or 'deactivated' status.
          Example: http://paste.openstack.org/show/506998/

:solution: Add a check, that looks at the image status and if it's
           different from 'queued' or 'active' then returns Conflict
           error (409 response code).

:impacts: users will get Conflict error, when they try to set location
          to image in 'saving' or 'deactivated' state.

:timeline: Expected to be merged within the N-2 time frame.

:link: https://review.openstack.org/#/c/324012/

:assignee: Mike Fedosin

Return 409 if setting location to saving or deactivated image
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Use policy to control deleting deactivated images
-------------------------------------------------

:problem: Currently, a user is permitted to delete a 'deactivated'
          image. Thus, if an image is suspected dangerous and deactivated
          by an administrator, a user could nonetheless remove the data
          before a security team has time to review it, thereby removing
          evidence of any wrongdoing. This presents a problem for an
          administrator who would like an investigation to take place.

:solution: Introduce a policy check named ``delete_deactivated_image``
           to govern whether a user is permitted to delete a 'deactivated'
           image.

:impacts: Adds a new policy. The default configuration will preserve
          current behaviour, that is, all users will be permitted to
          perform the action.

:timeline: Expected to be merged within the N-2 time frame.

:link: https://review.openstack.org/#/c/256381

:assignee: Niall Bunting

End of policy to control deleting deactivated images
++++++++++++++++++++++++++++++++++++++++++++++++++++

Add functionality to soft delete the tasks
------------------------------------------

:problem: Currently there is no mechanism for deleting tasks on regular
          basis. Thus, if a task is expired; it still comes up on calling
          task list or show. This can hamper the performance as the
          number of tasks returned will be more than the number of
          tasks that are active. Consequently, it will be tedious for
          the user to manage them.

:solution: Introduce a method which soft deletes the tasks by marking the
           deleted status as true in the database; so that, on calling
           task show or list, the expires tasks are not returned.

:impacts: Adds a new method. Users will now get only the active tasks.

:timeline: Expected to be merged within the N-2 time frame.

:link: https://review.openstack.org/#/c/209255/

:assignee: Geetika Batra

End of Add functionality to soft delete the tasks
+++++++++++++++++++++++++++++++++++++++++++++++++

Add `vhdx` to list of supported disk formats
--------------------------------------------

:problem: Glance currently support vhd disk formats and is being used in known
          deployments. `vhdx` disks can have much larger storage capacity than
          the older `vhd` format. More info can be found at offcial site
          https://technet.microsoft.com/en-us/library/hh831446(v=ws.11).aspx

:solution: `disk_formats` configuration option needs to be updated to indicate
           that this is a acceptable format. Some documentation updates are
           required showing the same and providing info about the official
           documentation.

:impacts: This will have documentation and upgrade impact. Release note should
          be added to indicate interest parties about this addition.

:timeline: Expected to be merged within the N-3 time frame.

:link: https://review.openstack.org/#/c/347352

:assignee: Stuart McLaren

End of Add `vhdx` to list of supported disk formats
+++++++++++++++++++++++++++++++++++++++++++++++++++

Deprecate ``show_multiple_locations`` configuration option
----------------------------------------------------------

:problem: Glance currently has two ways in which locations can be
          configured to be exposed to users :- 1) using
          ``show_multiple_locations`` configuration option 2) Role Based Access
          Control (RBAC) rules for ``delete_image_location``,
          ``get_image_location``, ``set_image_location``. If a cloud operator
          chooses to disable exposing multiple locations using 1), the approach
          in 2) becomes redundant.  Also, it can be somewhat confusing for
          operators to have multiple ways to tune a particular feature. If
          proper defaults are set and documentation for setting appropriate
          policies exists, configuration option ``show_multiple_locations``
          doesn't hold much value.

:solution: We choose to deprecate the configuration option
           ``show_multiple_locations``. Moving forward the right way to control
           the multiple locations feature will be using the Role Based Access
           Control (RBAC) rules for Create, Read, Update and Delete (CRUD) on
           locations. The ``policy.json`` file (example:
           http://git.openstack.org/cgit/openstack/glance/tree/etc/policy.json)
           should be used to govern the access a particular `role` has to the
           location(s). This also ensures appropriate security measures are
           taken into consideration by operators when using locations feature.
           This encourages being aware of the kind of users this sensitive
           feature will be exposed to rather than simple switching on/off a
           single configuration option. However, for Newton release we will
           only be deprecating the configuration option, no default values or
           setting will be changed. Currently we disallow using multiple
           locations by default, so the value of ``show_multiple_locations``
           option will be kept as ``False``. We would like to give some time to
           the operators to understand how to control multiple locations using
           this new RBAC method. In Ocata, we will be changing the default
           values of ``delete_image_location``, ``get_image_location`` and
           ``set_image_location`` policies and will be removing
           ``show_multiple_locations`` option from the tree.

:impacts: This will have documentation and upgrade impact. Release note should
          be added to notify interested parties about this addition.

:timeline: Expected to be merged within the N-3 time frame.

:link: https://review.openstack.org/#/c/313936/

:assignee: Flavio Percoco

End of Deprecate ``show_multiple_locations`` configuration option
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Add your Spec Lite before this line
===================================
