..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

======================================
Spec Lite: Deprecate location strategy
======================================

..
  Mandatory sections

:project: glance

:problem: Deprecate location strategy

:solution: In Bobcat we added support for weighing mechanism to glance store.
           To use this new feature we decided to deprecate location strategy
           in this cycle and remove it in 'D' (2024.2) development cycle.

:impacts: None

:how: In this cycle we are going to deprecate following configuration
      options related to location strategy:
      * location_strategy
      * store_type_preference
      Also a warning message regarding deprecation will be added to
      `location_order` and `store_type` strategy module during initiation
      phase.

:alternatives: None

:timeline: Milestone 2

:link: None

:reviewers: pdeore, mrjoshi, croelandt

:assignee: abhishekk
