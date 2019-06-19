..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=========================================
Spec Lite: Lazy update stores information
=========================================

:project: glance

:problem: In Rocky multiple backend support is added as experimental feature.
          The location object will have the 'store_id' (Store name) stored as
          a metadata attribute which helps to identify in which store the
          image is located. Glance API service has information about all
          configured stores in a global map.

          After enabling/upgrading glance-api to use multiple stores feature,
          existing images will not have a stores information associated with
          them. As a result if existing image is requested for download then
          it will search that image in all configured stores which will cause
          a performance overhead.

          All configured stores are stored in memory, if operator change the
          store name in configuration file and restart the glance-api service
          there is no way to update the new name to existing images which has
          store information associated with them.

:solution: Add a decorator to get image call which will retrieve the location
           object from image and then from location URL it will fetch the store
           information which is stored in the location map. Once location url
           is matched with the url from the global map, it will check if
           location metadata has existing store associated with it and then
           store name will be added/updated to the location metadata.

           If user/operator uses GET call to show a single image or list
           all the images the particular decorator will update the store
           information to single or all images available depending upon
           the request. There will be slight impact on performance on list
           call as it will revisit the location call for each of the image
           in the list.


:alternatives: None, carry on using current mechanism.

impacts: DocImpact

:timeline: Include in Train release.

:link: None

:assignee: abhishekk
