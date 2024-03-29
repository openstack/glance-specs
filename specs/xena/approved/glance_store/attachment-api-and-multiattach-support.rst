..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=======================================================
Add new cinder's attachment API and multiattach support
=======================================================

https://blueprints.launchpad.net/glance-store/+spec/attachment-api-and-multiattach-support

Make glance cinder store use cinder's new attachment APIs for image operations.

Problem description
===================

Currently when we make simultaneous requests to glance for using the image to
create multiple volumes or launch multiple instances, the same image volume needs
to be attached multiple times to serve the requests and since the support doesn't
exist in glance cinder store, some of the requests fails.

Proposed change
===============

Cinder's new attachment API was introduced in microversion 3.27 which should be
supported by cinder and is required to pass while making calls through cinderclient.
There were 2 new methods introduced, attachment_complete in MV 3.44 and passing
attach mode during attachment_create in MV 3.54 which are also required and hence
we will be using MV 3.54 for attachment related operations.
All these changes are required prior to adding the multiattach handling.

This should be a 2 stage change:

1) Replace existing API calls to cinder for attachment with new attachment API
calls

2) Add multiattach handling for glance cinder usecase

Alternatives
------------

Use cinder's image volume cache that will clone the first bootable volume created
from image and subsequent requests will result in cinder's clone operation instead
of downloading the image from glance.

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

None

Notifications impact
--------------------

None

Other end user impact
---------------------

None

Performance Impact
------------------

The current number of calls to cinder will be reduced resulting in performance
improvement. Example: initialize_connection and attach calls will be replaced
by attachment_update and similarly terminate_connection and detach calls will
be replaced by attachment_delete.

Other deployer impact
---------------------

None

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
* whoami-rajat

Other contributors:
  None

Reviewers
---------

Core reviewer(s):

* abhishek-kekane
* jokke
* rosmaita
* smcginnis

Work Items
----------

* Replace existing calls to old attachment methods with the new attachment API
  calls
* Modify cinderclient calls to include microversion
* Add code for multiattach handling
* Add appropriate unit tests

Dependencies
============

None


Testing
=======

Unit tests to have the code coverage and the new attachment code path will
be tested with the glance cinder tempest job running on glance gate.

Documentation Impact
====================

None

References
==========

None