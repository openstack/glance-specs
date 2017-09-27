=====================================
Spec Lite: Remove the Registry API v1
=====================================

:problem: During the Queens cycle, the two Glance services that depend upon the
          Glance Registry API v1 will be removed (API v1) or refactored (the
          scrubber).  Hence, the Registry API will be redundant and should be
          removed.

:dependencies: * The Images API v1 must be removed
               * The scrubber must be refactored so it doesn't use the Registry
                 API v1

:solution: Remove the Registry API v1 from the codebase.

:impacts: DocImpact

:timeline: target for the Q-3 milestone (week of 22 January 2017)

:link: https://blueprints.launchpad.net/glance/+spec/remove-registry-v1

:reviewers: all core reviewers
