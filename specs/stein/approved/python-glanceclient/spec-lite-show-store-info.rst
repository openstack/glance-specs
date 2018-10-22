..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================
Spec Lite: Show Store Info
==========================

:project: python-glanceclient

:problem: In multi-store environment, user may want to know which backend store
          images are stored in. But currently store info (store id) can only be
          showed in command "glance image-show" which can only show one image.
          It's not convenient when want to know the store info of a list of
          images.

:solution: This spec aims to add --include-stores option to image-list, command
           like "glance image-list --include-stores". As store id is the same
           in most of production environment, so it's not good to list this
           info in -v, otherwise the store id column will be the same value and
           it's a bit redundant.

:impacts: None

:timeline: S-1

:assignee: LiangFang
