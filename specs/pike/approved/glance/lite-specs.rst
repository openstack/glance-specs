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

Community Goal: Support Python 3.5
----------------------------------

:problem: Satisfy the Pike community goal `Support Python 3.5
          <https://governance.openstack.org/tc/goals/pike/python35.html>`_

:solution: Ensure that Glance meets the criteria of the Goal.

:impacts: None.

:assignee: Open

End of `Community Goal: Support Python 3.5`
+++++++++++++++++++++++++++++++++++++++++++

Community Goal: Control Plane API endpoints deployment via WSGI
---------------------------------------------------------------

:problem: Implement the Pike community goal `Control Plane API endpoints deployment
          via WSGI <https://governance.openstack.org/tc/goals/pike/deploy-api-in-wsgi.html>`_.

:solution: Implement a devstack plugin to run the Images API v2 supplied by Glance
           in mod_wsgi.

:impacts: None.

:assignee: Matt Treinish

End of `Community Goal: Control Plane API endpoints deployment via WSGI`
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Introduce db sync --check feature
---------------------------------

:problem: It is very hard for automation of deploy and upgrade operations to
          know if there are db migrations pending. It requires the automation
          to know what the latest version is, and compare that to the output
          of a command to check the current version, then interpret the
          potential difference somehow.

:solution: Similar to the linked feature added to Keystone's manage command,
           Glance should support an operation which enumerates any outstanding
           db upgrade operations and provide a distinct return code based on
           that status. Each expand, migrate, and contract operation required
           to upgrade the db should be listed in the proper order of execution
           in the response. For consistency with Keystone, this may be
           implemented by using a ``--check`` option. When this option is
           present no db upgrades would be performed but potential operations
           would be reported, acting similar to the pattern of a dry-run.

:impacts: Introduces new option to the db sync operation in glance-manage.

:timeline: Expected to be merged within the Pike time frame.

:link: https://bugs.launchpad.net/keystone/+bug/1642212

:assignee: Open

End of `Introduce db sync --check feature`
++++++++++++++++++++++++++++++++++++++++++

Introduce Glance Taskflow stopfile feature
------------------------------------------

:problem: When preparing to take a Glance node down for maintenance or upgrade
          it is necessary to allow long-running operations to complete without
          allowing new operations to begin. The Taskflow engine does not have
          the capability to prevent individual executors from starting new
          jobs, and so attempting to take a Glance node out of the Taskflow
          processing pool risks a race condition with that executor starting a
          job just before the service is terminated which could cause the Task
          processing to fail.

:solution: Introduce a disable_by_file_path feature to Glance Taskflow which
           will prevent the node from picking up new jobs. This allows an
           operator or automation engine to ``touch`` the appropriate file
           before terminating the service. This feature should depend on the
           oslo healthcheck middleware configuration to disable the taskflow
           engine. As an additional impact, this work will require Glance to
           instantiate a single taskflow engine as a singleton and reuse that
           engine instance on all subsequent taskflow operations.

:impacts: None

:timeline: Expected to have a fix merged in the Pike cycle before milestone 2.

:link: https://docs.openstack.org/developer/oslo.middleware/healthcheck_plugins.html

:assignee: Open

End of `Introduce Glance Taskflow stopfile feature`
+++++++++++++++++++++++++++++++++++++++++++++++++++

Add your Spec Lite before this line
===================================
