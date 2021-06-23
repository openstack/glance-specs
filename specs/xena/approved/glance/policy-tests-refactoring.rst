..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===================================
Spec Lite: Policy tests refactroing
===================================

:project: Glance

:problem: At the moment our unit and functional tests are referring to
          policy.yaml located in `glance/tests/etc` of the project
          repository. As now we are putting efforts into refactoring the
          policy layer in glance we should be testing our defaults
          except where we want to test something specifically different.

:solution: Instead of using policies from policy.yaml file we should be
           testing our defaults except where we want to test something
           specifically different.

:impacts: None

:alternatives: None

:timeline: Xena Milestone-2

:reviewers: Steap, rosmaita, pdeore

:assignee: abhishek-kekane, dansmith
