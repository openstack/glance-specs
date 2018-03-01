==========================================
Spec Lite: Deprecate Images API v1 Support
==========================================

:problem: The Images API v1 is targeted to be removed in Rocky, hence there
          is no reason to continue carrying v1 support in the glanceclient.

:solution: Announce that the Rocky release of the python-glanceclient will
           be the last release that will support the Images v1 API and that
           support will be removed in the first major release of the S
           cycle.

:impacts: DocImpact

:alternatives: Continue to support the Images API version 1.  This is not
               necessary for interoperability, however, as the Images API
               v1 was never included in "DefCore" tests.  Continued support
               would not be a good use of the team's time.

:timeline: Early Rocky cycle

:link: https://blueprints.launchpad.net/python-glanceclient/+spec/deprecate-v1-support

:reviewers: all core reviewers

:assignee: jokke
