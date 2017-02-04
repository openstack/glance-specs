================
Glance Spec Lite
================

Replace mox with mock for unit test
-----------------------------------

:problem: ``Mox`` does not support python 3. We have a shim module 'mox3' that was
          built a couple of years ago, is unmaintained, and as it gets tested
          more heavily is showing race conditions under python3.

:solution: Replace ``mox`` with ``mock``.

:impacts: This change will use ``mock`` instead of ``mox``.

:timeline: Expected to be merged within the Ocata time frame.

:link: https://review.openstack.org/#/c/407959/

:assignee: Howard Lee

`End of` Replace mox with mock for unit test
++++++++++++++++++++++++++++++++++++++++++++
