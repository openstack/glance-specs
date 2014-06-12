..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================
Refactoring Glance logging
==========================

Glance is currently logging lots of operator relevant information as DEBUG.
Also the logged messages are translated in various ways. I would like to
refactor the whole Glance codebase reflecting the current logging
guidelines [1].


Problem description
===================

OPS are complaining that OpenStack as whole does not utilize the logging
levels appropriately and production implementations needs to run on DEBUG-
level to get needed information out of the logs.

Glance is logging a lot of operator relevant information as DEBUG. [1]


Proposed change
===============

I would like to see whole Glance codebase revisited and the logging changed to
use appropriate logging level and reflect the translation functions to those
levels as well. This would be also good opportunity to ensure that we have no
logging left that would write sensitive information like URIs and credentials
to logfiles.

Unify the way how exceptions are logged. Exception message should be always
logged if anything to ensure that operators can find the event based on end
user problem description.

Alternatives
------------

We could implement error codes to differentiate the messages sent to user and
logged having still unique linkage between the two. This would cause more
documentation overhead but provide greater flexibility and granularity.

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

This would reinforce the confidence that we do not log sensitive/confidential
information. [2]

Notifications impact
--------------------

Some notification messages might have minor changes.

Other end user impact
---------------------

None

Performance Impact
------------------

This should not have performance hit outside of the corrected amount of
translation function calls made.

Other deployer impact
---------------------

Users who have their own logging filtering in place would need to review
those rules after the logging level has been changed.

Developer impact
----------------

The logging on correct levels should make developer life easier when trying
to debug the code.


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  Erno Kuvaja <jokke>

Other contributors:
  <launchpad-id or None>

Work Items
----------

* Review OpenStack logging guidelines [1][2]

* Review the current logging pattern and make decision where changing the
  message content would be appropriate (sensitive data, etc.)

* Determine the correct logging level message by message and align the
  translation functions used on that log level.


Dependencies
============

* Related proposal in the Security Guideline draft [2] to implement some
  sanitizing and tagging to oslo. This is not dependency nor should affect
  this work other than possible adobtation if the proposed functionality gets
  implemented.


Testing
=======

None


Documentation Impact
====================

New log level use cases should be documented so deployers would know what to
expect finding from their logs.


References
==========

[1] https://wiki.openstack.org/wiki/LoggingStandards
[2] https://wiki.openstack.org/wiki/Security/Guidelines/logging_guidelines
