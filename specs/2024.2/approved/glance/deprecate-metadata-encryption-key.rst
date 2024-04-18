..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

============================================
Spec Lite: Deprecate metadata_encryption_key
============================================

..
  Mandatory sections

:project: glance

:problem: `metadata_encryption_key` config option and it's related
          functionality was added quite a long back ago. Even though as per
          the description it encrypts the location metadata, it actually
          encrypts location url. It encrypts the location url only for image
          upload/import/download/show APIs, doesn't encrypt url on location
          APIs. If it's enabled during upgrade then it will break the
          existing deployment since existing image url is not been encrypted.
          It doesn't even work for location url encryption as expected since
          it does not encrypts the legacy images url on start up, download
          of that image fails with InvalidLocation error.

:solution: We decided to deprecate `metadata_encryption_key` config option in
           this cycle and remove it in `F` (2025.2) cycle.

:impacts: None

:how: In this cycle deprecate `metadata_encryption_key` configuration
      options. Remove it along with it's related functionality in `F` cycle.

:alternatives: None

:timeline: Milestone 2

:link: None

:reviewers: abhishekk, croelandt, mrjoshi

:assignee: pdeore


