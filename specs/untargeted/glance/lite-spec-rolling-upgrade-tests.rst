==================================
Spec Lite: Rolling Upgrade Testing
==================================

:problem: `Zero-downtime database upgrades`_ were introduced on an EXPERIMENTAL
          basis in the Ocata release to facilitate rolling upgrades.  In order
          for rolling upgrades to be considered officially supported, and to
          allow Glance to assert the associated TC tags, we need to have
          in-gate testing of upgrades.

          .. _`Zero-downtime database upgrades`: https://blueprints.launchpad.net/glance/+spec/database-strategy-for-rolling-upgrades

:solution: Add in-gate testing of upgrades using Grenade or some other
           appropriate framework.

:impacts: DocImpact: update the docs to reflect the non-experimental status
          of zero-downtime database upgrades.

:link: https://blueprints.launchpad.net/glance/+spec/rolling-upgrade-tests
