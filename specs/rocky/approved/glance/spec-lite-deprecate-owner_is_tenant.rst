..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

====================================
Spec Lite: Deprecate owner_is_tenant
====================================

:project: glance

:problem: The ``owner_is_tenant`` option, which is True by default, allows an
          operator to run Glance in a nonstandard configuration where the
          image owner is the *user* who created the image.  In all other
          OpenStack services, resources are owned by the *project* (as
          they are in Glance when the default setting is used).

          A survey of operators conducted in March 2017 indicated that
          no operators who responded (14) are using this option.  As it
          is little used, results in a nonstandard OpenStack experience,
          and complicates the Glance code, the option should be deprecated
          in Rocky.  Following the standard `OpenStack deprecation policy`_,
          it should be removed early in the 'S' cycle.

          .. _`OpenStack deprecation policy`: https://governance.openstack.org/tc/reference/tags/assert_follows-standard-deprecation.html

:solution: Use the oslo.config facilities to mark the option as deprecated.
           As it appears that this option is used only in its default setting
           of True, no migration path is proposed.

:impacts: None

:timeline: R-1

:assignee: rosmaita
