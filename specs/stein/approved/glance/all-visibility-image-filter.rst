
..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

========================================
Spec Lite: 'all' visibility image filter
========================================

:project: glance

:problem: When deployments use community images these community images are
          not returned when doing an image list.
          Currently murano and other projects use a property to determine
          if the image should be used. It is not possible to filter on
          all images with the specific property. Sahara also shares this
          issue. Horizon currently also needs to show all images that a
          user can boot from in the boot intance view and this cannot be
          done without 2 requests to glance.

:solution: We need to add a new visibility called 'all' which will return
           all images that are available to the user.

:impacts: None

:how: We will add the ability to list images with visibility='all' to
      return all images. This will require a bump in the api version.

:alternatives: The other option is to make 2 requests to glance each time
               you want to list all images or filter by all images which
               is inefficiant

:assignee: sorrison
