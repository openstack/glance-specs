..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=========================================
Spec Lite: CLI support for new cache APIs
=========================================

:project: python-glanceclient

:problem: In Xena we are deprecating `glance-cache-manage` CLI utility as
          we are moving caching operations under glance-api by introducing
          new API endpoints for cache related operations.

:solution: We need to add new CLI commands; `cache-queue`, `cache-list`,
           `cache-delete`, `cache-delete-all` to support new cache APIs.

:impacts: APIImpact, DocImpact

:how: We will add new CLI interface for `cache-queue`, `cache-list`,
      `cache-delete`, `cache-delete-all` commands. As caching is
      local to each glance node and most of the deployments configures glance
      nodes behind the load-balancers, operator/user need to pass actual
      endpoint of the glance node. Existing optional command line option
      `--os-image-url` will be used to provide the actual endpoint to the
      client. The default value for `--os-image-url` can also be set to
      using `OS_IMAGE_URL` environment variable. If this optional parameter
      is not provided while executing above new commands or is using default
      value set using `OS_IMAGE_URL` environment variable all of the above
      commands should exit with appropriate error message.


:alternatives: None

:timeline: Xena Milestone 2

:link: https://review.opendev.org/c/openstack/glance-specs/+/665258

:reviewers: dansmith, abhishek-kekane, cyril-roelandt

:assignee: jokke
