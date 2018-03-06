==========================================
Spec Lite: Introduce db sync check feature
==========================================

:problem: It is very hard for automation of deploy and upgrade operations to
          know if there are db migrations pending. It requires the automation
          to know what the latest version is, and compare that to the output
          of a command to check the current version, then interpret the
          potential difference somehow.

:solution: Similar to the linked feature added to Keystone's manage command,
           Glance should support an operation which enumerates any outstanding
           db upgrade operations and provide user friendly message based on
           that status. Each expand, migrate, and contract operation required
           to upgrade the db should be listed in the proper order of execution
           in the response.
           This may be implemented by using a ``glance-manage db check`` option.
           When this option is present no db upgrades would be performed
           but potential operations would be reported, acting similar to the
           pattern of a dry-run.

:impacts: Introduces new option to the db sync operation in glance-manage.

:timeline: Queens RC-1

:link: https://bugs.launchpad.net/keystone/+bug/1642212

:reviewers: rosmaita, abhishekk, jokke

:assignee: bhagyashris