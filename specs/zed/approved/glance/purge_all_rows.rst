..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.
 http://creativecommons.org/licenses/by/3.0/legalcode

========================================================================
Spec Lite: Add ability to purge all needed rows by glance-manage script.
========================================================================

:project: glance

:problem: When a user wants to purge all deleted rows they use
          "glance-manage db purge" and "glance-manage purge_images_table".
          A user never knows how many deleted rows are still in a table.
          So they need to launch the script many times until the script reports
          that 0 rows were deleted in every table. It's inconvenient.

:solution: use the same notation as with our other limits on "--max-rows" when
           set to -1 it would purge them all rather than the default 100 lines
           or what ever specified on the command line.

:impacts: None

:how: if "--max-rows" equals -1 the script purges deleted rows without number
      limit.

:alternatives: None

:timeline: Zed

:link: https://review.opendev.org/c/openstack/glance/+/813691

:reviewers: Abhishek Kekane, Cyril Roelandt

:assignee: mitya-eremeev-2
