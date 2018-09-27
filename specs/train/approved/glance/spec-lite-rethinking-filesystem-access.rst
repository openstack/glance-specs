..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===========================================
Spec Lite: Rethinking our filesystem access
===========================================

:project: glance

:problem: Glance use filesystem in quite a few places with various mechanisms.
          Tasks and staging operation introduced as a part of import image
          workflow are consuming glance_store by overriding the configs and
          initializing the store via internal functions.

:solution: In Rocky multiple backend support is added as experimental feature.
           We should use this to reserve certain stores for these operations.
           As a part of this we will deprecate work_dir and node_staging_uri
           configuration options and reserve two filesystem stores
           'os_glance_tasks_store' and 'os_glance_staging_store', which can
           be used to get rid of initializing store via internal functions.
           These stores will be *hard-coded* in glance for the time being
           and injected to enabled_backends config option to load when
           glance_store will be initialized at the time of glance-api service
           starts. Operator needs to insure that these stores will not be
           included in enabled_backends config option in glance-api.conf.

           These reserved stores will be injected only if *multiple backends
           are enabled* i.e. enabled_backends config option is defined in
           glance-api.conf. If multiple backend is not enabled then
           node_staging_uri and work_dir config options will work as it is.

           Sample code to show how these config options will be injected and
           used::

             reserved_stores = {
                 'os_glance_staging_store': 'file',
                 'os_glance_tasks_store': 'file'
             }

             enabled_backends = CONF.enabled_backends
             if enabled_backends:
                 enabled_backends.update(reserved_stores)

           Then operators need to ensure to have below sections defined in
           glance-api.conf::

             [os_glance_tasks_store]
             filesystem_store_datadir = /var/lib/glance/tasks_work_dir

             [os_glance_staging_store]
             filesystem_store_datadir = /var/lib/glance/staging

           NOTE: The path for filesystem_store_datadir for
           'os_glance_tasks_store' and 'os_glance_staging_store' should be
           different from actual path if file backend is used. The
           ``os_glance_*`` prefix is reserved for glance and cannot be used
           by operators to name their stores.

           'os_glance_tasks_store' and 'os_glance_staging_store' will be
           excluded from 'stores-info' call and will not be accepted as
           a 'backend' option in create image calls.


:alternatives: None, carry on using current mechanism.

impacts: DocImpact

:timeline: Include in Train release.

:link: None

:assignee: abhishekk
