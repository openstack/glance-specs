===================================
Spec Lite: Remove the Images API v1
===================================

:problem: The Images API verison 1 was DEPRECATED in the Newton release:
          https://docs.openstack.org/releasenotes/glance/newton.html
          It needs to be removed from the codebase.

:dependencies: The ``copy_from`` import-method must be implemented and the
               Images API version 2.6 must be CURRENT.  (That's because the
               key requested feature missing from Images v2 is a copy-from
               functionality.)

:solution: This will require some preliminary work before the code is removed,
           for example, removing any Tempest tests that use the v1 API.  These
           will be noted as "Work Items" on the Blueprint.

:impacts: DocImpact (All v1 docs will have to be removed)

:timeline: target for the Q-3 milestone (week of 22 January 2017)

:link: https://blueprints.launchpad.net/glance/+spec/remove-v1

:reviewers: all core reviewers

:assignee: rosmaita
