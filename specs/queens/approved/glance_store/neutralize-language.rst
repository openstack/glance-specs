==============================
Spec Lite: Neutralize Language
==============================

:problem: The glance_store library is being consumed by another project (Glare)
          but much of the language in Exception messages, log messages, and
          configuration option help text talks about "images".

          Additionally, some of the names of configuration options are
          image-centric.  (Actually, I could only find one of these):

          * ``vmware_store_image_dir`` (and its default value is
            'openstack_glance')

:solution: * Make the language in Exception messages, log messages, and
             the configuration option help text neutral, for example, replace
             'image' by 'object' and any other appropriate language changes.

           * Introduce new configuration options for any options with
             image-centric names and deprecate the old options using the
             facilities oslo.config supplies for this purpose.

:impacts: The deprecated options will be listed in a release note.
