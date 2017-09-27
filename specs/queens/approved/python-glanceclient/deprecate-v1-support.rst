==========================================
Spec Lite: Deprecate Images API v1 Support
==========================================

:problem: The Images API v1 is targeted to be removed in Queens, hence there
          is no reason to continue carrying v1 support in the glanceclient.

:solution: Announce that the Queens release of the python-glanceclient will
           be the last release that will support the Images v1 API and that
           support will be removed in the first major release of the Rocky
           cycle.

:impacts: DocImpact

:alternatives: Continue to support the Images API version 1.  This is not
               necessary for interoperability, however, as the Images API
               v1 was never included in "DefCore" tests.  Continued support
               would not be a good use of the team's time.

:timeline: Q-1 milestone (week of 16 October 2017), but definitely before
           the Queens release of the glanceclient at Q-3

:link: https://blueprints.launchpad.net/python-glanceclient/+spec/deprecate-v1-support

:reviewers: all core reviewers

:assignee: jokke
