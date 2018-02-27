===================================
Spec Lite: Refactor Glance Scrubber
===================================

:problem: The scrubber code uses the registry v1 client.  This is bad because
          it doesn't support Keystone v3 auth, which is widely used by default.
          Additionally, when the Images API v1 is removed, nothing else will be
          using the registry v1 client.

:solution: Refactor the scrubber so that it doesn't use the registry at all.
           Planning for registry deprecation began in Newton and the
           deprecation is being officially announced in Queens.  This
           refactoring will allow us to remove the registry on schedule
           in the S release.

:impacts: None

:timeline: Q-2 milestone or thereabouts (early December)

:link: https://blueprints.launchpad.net/glance/+spec/scrubber-refactor

:reviewers: rosmaita, abhishekk, jokke

:assignee: wangxiyuan
