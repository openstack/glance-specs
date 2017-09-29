=================================================
Spec Lite: Actually Deprecate the Glance Registry
=================================================

:problem: A spec to `Deprecate the Glance Registry Service`_ was accepted in
          Newton, but it contained the ambiguous statement, "Mark the service
          as deprecated and ready for removal in the Q release."  It's now
          the Q release, so we need to actually deprecate it by announcing
          officially that *the Registry Service is deprecated in Queens and
          subject to removal in the S release.*

          .. _`Deprecate the Glance Registry Service`: http://specs.openstack.org/openstack/glance-specs/specs/newton/approved/glance/deprecate-registry.html

:solution: On startup, the Registry Service should output an appropriate
           message to the log.

:timeline: Q-1 milestone (week of 16 October 2017)

:link: https://blueprints.launchpad.net/glance/+spec/deprecate-registry

:reviewers: all core reviewers

:assignee: rosmaita
