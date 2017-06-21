Lite Spec: Introduce Glance Taskflow stopfile feature
-----------------------------------------------------

:problem: When preparing to take a Glance node down for maintenance or upgrade
          it is necessary to allow long-running operations to complete without
          allowing new operations to begin. The Taskflow engine does not have
          the capability to prevent individual executors from starting new
          jobs, and so attempting to take a Glance node out of the Taskflow
          processing pool risks a race condition with that executor starting a
          job just before the service is terminated which could cause the Task
          processing to fail.

:solution: Introduce a disable_by_file_path feature to Glance Taskflow which
           will prevent the node from picking up new jobs. This allows an
           operator or automation engine to ``touch`` the appropriate file
           before terminating the service. This feature should depend on the
           oslo healthcheck middleware configuration to disable the taskflow
           engine. As an additional impact, this work will require Glance to
           instantiate a single taskflow engine as a singleton and reuse that
           engine instance on all subsequent taskflow operations.

:impacts: None

:timeline: Expected to have a fix merged in the Pike cycle before milestone 2.

:link: https://docs.openstack.org/developer/oslo.middleware/healthcheck_plugins.html

:assignee: Open
