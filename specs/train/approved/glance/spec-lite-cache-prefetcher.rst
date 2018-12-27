..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=========================================================
Spec Lite: Add periodic job to prefetch images into cache
=========================================================

:project: glance

:problem: During Queens release glance registry is marked as deprecated and
          will be removed during Train cycle. Glance cache-prefetcher utility
          uses glance registry to cache the images.

:solution: In Train, as per Edge computing architecture, glance cache will be
           enabled on far-edge nodes. As of now glance-cache-prefetcher is
           dependent on registry which is deprecated and due for removal.
           In order to remove the dependency on registry, we are proposing
           to add a new periodic job to glance-api service which will run
           as per interval set using 'cache_prefetcher_interval'
           configuration option and fetch images which are queued for
           caching in cache directory. This new periodic job will only run
           if cache is enabled by the operator.

:alternatives: None

:impacts: DocImpact

:timeline: Include in Train release.

:link: None

:assignee: abhishekk
