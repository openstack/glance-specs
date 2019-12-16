..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

======================================================
Spec Lite: Deprecate allow_additional_image_properties
======================================================

:project: glance

:problem: The ``allow_additional_image_properties`` configuration option
          was originally introduced to prevent users from flooding the
          image_properties table with junk.  Given that we now have the
          ``image_property_quota`` option,
          ``allow_additional_image_properties`` is unnecessary.  Further,
          if an operator were to set it False, all sorts of stuff would
          break as multiple OpenStack services (for example, Cinder, Nova)
          currently write/rely on custom image properties.  Of course, in
          such a case, an operator would have to change the option to
          True to get everything working again; but the point is that
          if this setting is always True, then it is unnecessary and
          polluting the code with unnecessary branch points.

:solution: Deprecate the ``allow_additional_image_properties`` in Ussuri
           scheduled for removal in the V development cycle, consistent with
           the standard OpenStack deprecation policy.

:impacts: None.  Operators who really want to use this option can instead
          set ``image_property_quota`` to 0.  ('0' means zero; a negative
          value means 'unlimited' for this option.)

:assignee: rosmaita (or anyone who would like to address this low-hanging
           fruit)
