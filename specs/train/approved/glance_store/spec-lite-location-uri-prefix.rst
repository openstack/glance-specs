..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================================================
Spec Lite: Add location url prefix attribute to each store
==========================================================

:project: glance_store

:problem: In multiple store implementation, glance has added new metadata
          'store' to location object, so that it will be easy to identify
          the store that particular image is uploaded. When operator
          upgrades glance node to use multiple stores, then
          existing images does not have store information associated with
          it. So if user wants to download any such particular image, then
          as it does not have 'store' associated with it, the said image will
          be searched in all the configured stores. This may cause the
          performance overhead.

:solution: To overcome this, we propose to add new attribute '_url_prefix'
           to each of the store object. When glance-api service starts it
           stores a global map in the memory which includes store object,
           scheme and location_class for each of the store.

           Sample of location map stored in the memory::

             {
                 'file_2': {
                     'store': <glance_store._drivers.filesystem.Store object>,
                     'store_entry': 'file',
                     'location_class': <class 'glance_store._drivers.filesystem.StoreLocation'>
                 },
                 'file_1': {
                     'store': <glance_store._drivers.filesystem.Store>,
                     'store_entry': 'file',
                     'location_class': <class 'glance_store._drivers.filesystem.StoreLocation'>
                 }
             }

           At the time of initialization of each store, a location url will
           be retrieved using each stores configuration and assigned to
           '_url_prefix' attribute of each store object. Whenever any GET call
           to image (before upgrading to multiple stores) is made, the location
           url of that image will be matched with '_url_prefix' and equivalent
           store information will be updated to that image's location metadata.


:alternatives: None, carry on using current mechanism.

impacts: DocImpact

:timeline: Include in Train release.

:link: None

:assignee: abhishekk
