..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===============================
Spec Lite: Deprecate admin_role
===============================

..
  Mandatory sections

:project: glance

:problem: Glance has a configuration option that grants complete admin access
          to anyone with a particular role.  This is confusing because it
          overrides any settings in the policy configuration file.  Further,
          the default value is 'admin', which is likely to be an actual role
          defined in any OpenStack cloud.

:solution: Deprecate the 'admin_role' configuration option in Ussuri and
           remove it during the Victoria development cycle.  Additionally,
           change the default setting to something that would never match
           any actual role, for example,
           '__NOT_A_ROLE_07697c71e6174332989d3d5f2a7d2e7c_NOT_A_ROLE__'.
           That way, the 'admin_role' would only be effective if an
           operator configured it on purpose, and this "backdoor" will
           be effectively closed immediately.

:impacts: Possibly documentation (though our policy docs are woefully out
          of date).

