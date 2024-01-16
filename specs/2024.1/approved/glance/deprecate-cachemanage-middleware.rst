..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===========================================
Spec Lite: Deprecate cachemanage middleware
===========================================

..
  Mandatory sections

:project: glance

:problem: Deprecate cachemanage middleware

:solution: Cache operations (CR(u)D) is now part of glance API. Even though
           we need to depend on cache middleware to enable it. There are two
           middlewares related to caching, one is `cache` and other is
           `cachemanage` and we can now get rid of `cachemanage` middleware and
           glance-cache-manage  command line utility.

:impacts: None

:how: In this cycle we are going to deprecate cachemanage middleware and api
      pipeline `keystone+cachemanage` (defined in glance-api-paste.ini) and
      `glance-cache-manage` command line utility. A deprecation warning
      message will be added to each command of `glance-cache-manage` utility
      as well as during initialization of `cachemanage` middleware.

:alternatives: None

:timeline: Milestone 2

:link: None

:reviewers: pdeore, mrjoshi, croelandt

:assignee: abhishekk
