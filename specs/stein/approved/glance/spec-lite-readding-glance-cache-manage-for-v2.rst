..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=======================================================
Spec Lite: Add glance-cache-manage utility using v2 API
=======================================================

:project: glance

:problem: In Rocky, the v1 dependant glance-cache-manage command was removed
          while removing Images API v1 entry points. As a part of Edge
          computing glance cache needs to be enabled on far-edge nodes
          via Split Control plane where glance-cache-manage utility will be
          essential to queue image for prefetching, to list & delete images
          from Image Cache.

:solution: In Stein, as per Edge computing architecture, glance cache will be
           enabled on far-edge nodes. Hence it will be good to add
           glance-cache-manage utility using v2 API in glance. This utility
           will have the following commands and the same interface as Queens
           glance-cache-manage utility [0] insofar as possible,
           [0] https://docs.openstack.org/glance/queens/cli/glancecachemanage.html ::

             1. Queue the image with identifier <IMAGE_ID> for caching,

                $ glance-cache-manage --host=<HOST> queue-image <IMAGE_ID>

             2. List all images currently cached

                $ glance-cache-manage --host=<HOST> list-cached

             3. List all images currently queued for caching.

                $ glance-cache-manage --host=<HOST> list-queued

             4. Delete an image from the cache

                $ glance-cache-manage --host=<HOST> delete-cached-image <IMAGE_ID>

             5. Remove all images from the cache

                $ glance-cache-manage --host=<HOST> delete-all-cached-images

             6. Deletes an queued image from the cache

                $ glance-cache-manage --host=<HOST> delete-queued-image <IMAGE_ID>

             7. Remove all images from the cache queue

                $ glance-cache-manage --host=<HOST> delete-all-queued-images



:alternatives: None

:impacts: DocImpact

:timeline: Include in Stein release.

:link: None

:assignee: pdeore
