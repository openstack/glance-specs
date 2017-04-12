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

:assignee: Alex Bashmakov

End of `Community Goal: Support Python 3.5`
+++++++++++++++++++++++++++++++++++++++++++

Community Goal: Control Plane API endpoints deployment via WSGI
---------------------------------------------------------------

:problem: Implement the Pike community goal `Control Plane API endpoints deployment
          via WSGI <https://governance.openstack.org/tc/goals/pike/deploy-api-in-wsgi.html>`_.

:solution: Implement a devstack plugin to run the Images API v2 supplied by Glance
           in mod_wsgi.

:impacts: None.

:assignee: Alex Bashmakov

End of `Community Goal: Control Plane API endpoints deployment via WSGI`
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Remove Glare code from the Glance repository
--------------------------------------------

:problem: Glare became a separate project with its own code repository during
          Newton. The code was copied out of the Glance tree, but remained in
          the Glance repository. It is no longer being maintained within
          Glance, and that has begun to cause some problems, for example,
          blocking a recent stevedore upper constraints change; see Change-Id:
          `I141b17f9dd2acebe2b23f8fc93206e23bc70b568
          <https://review.openstack.org/#q,I141b17f9dd2acebe2b23f8fc93206e23bc70b568,n,z>`_.

:solution: Remove all Glare code from the Glance repository and drop all
           artifacts tables from the Glance database.

:impacts: No API Impact as the Glare API was EXPERIMENTAL in both versions
          that ran on the code being removed ('/v3' on the Glance endpoint in
          Liberty, '/v0.1' on its own endpoint in Mitaka).

          As a courtesy to projects/packagers/deployers that may have consumed
          Glare from the Glance code repository, an `openstack-dev announcement
          <http://lists.openstack.org/pipermail/openstack-dev/2017-February/112427.html>`_
          and an `openstack-operators announcement
          <http://lists.openstack.org/pipermail/openstack-operators/2017-February/012689.html>`_
          were sent out on 16 February 2017.  There has been no response so
          far.

          A detailed release note will be included in the patch.

:timeline: Pike-1

:link: Change-Id: `I3026ca6287a65ab5287bf3843f2a9d756ce15139
       <https://review.openstack.org/#q,I3026ca6287a65ab5287bf3843f2a9d756ce15139,n,z>`_

:assignee: rosmaita

End of `Remove Glare code from the Glance repository`
+++++++++++++++++++++++++++++++++++++++++++++++++++++

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

:assignee: Alexander Bashmakov

End of `Introduce db sync --check feature`
++++++++++++++++++++++++++++++++++++++++++

Add your Spec Lite before this line
===================================
