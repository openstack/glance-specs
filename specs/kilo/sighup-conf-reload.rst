===========================================
Reload configuration files on SIGHUP signal
===========================================

https://blueprints.launchpad.net/glance/+spec/sighup-conf-reload

We propose to eliminate the need to restart the glance api service when
configuration files are modified. Operator can send SIGHUP signal to glance
service which will reload the configuration file.

Problem description
===================

In a production environment, an administrator will modify the glance-api.conf
configuration parameters like filesystem_store_datadirs when the storage
is almost full to add more capacity by adding more disks, or to increase
the number of workers or log configuration etc. Then they need to restart the
glance services explicitly for these changes to be loaded. Restarting
service would break users connected to it which is not good from users point
of view.

Proposed change
===============

Add the ability to dynamically change configuration settings of a running
glance server with no impact to service.

A running glance server consists of a parent process and one or
more child processes.

On receipt of a SIGHUP signal the parent process will:

- reload the configuration
- send a SIGHUP to the original child processes
- start new child processes with the new configuration
- its listening socket will not be closed

On receipt of a SIGHUP signal each original child process will:

- close the listening socket so as not to accept new requests
- complete any in-flight requests
- exit

This approach is based on nginx's behaviour and avoids some of the
disadvantages of the current oslo's Launcher reload:

- Race conditions: Launcher does not shutdown eventlet cleanly, existing
  requests can fail.
- If all child processes are busy there can be a lengthy delay when new
  requests are not processed.
- Long lived pre-SIGHUP idle client connections can stall request
  processing indefinitely.
- Not all parameters can be changed, eg number of workers.
- The wsgi pipeline cannot be changed, for example to enable caching.

Alternatives
------------

An alternative may be to attempt to save and then restore long running tasks
using taskflow. The process restart would then only need to deal with
short lived requests (e.g. API DB lookups) and then no user visible downtime
is required for regular restarts

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

If the reload takes too long (e.g., >50ms) then the API requests will be
noticeably delayed.

We are proposing current worker processes to stop accepting requests and
continue with what they are doing, while the parent process starts and
spawn new child processes with the new configuration. So there is a
possibility that the glance node will be running twice as many child processes
as it is configured to run for a while. It could impact performance,
especially if it is an underpowered node that is already configured to run
as many child processes as it can handle without degradation.

In the author's opinion, it is the responsibility of the operator to make sure
the node will not be over-provisioned with child processes (workers). If an
operator wants to run a node with no headroom for additional child processes,
the author suggests that such an operator not use dynamic configuration via
SIGHUP. Instead, such an operator should use the old fashioned technique of
restarting the api service.

.. _other_deployer:

Other deployer impact
---------------------

Need to document the impact of config changes for some params like workers,
host, port etc.


Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  stuart-mclaren

Other contributors:
  abhishek-kekane

Reviewers
---------

Core reviewer(s):
  nikhil-komawar
  flaper87

Other reviewer(s):
  icordasc


Work Items
----------

- Add handler for SIGHUP signal
- Reload configuration parameters
- Unit and functional tests for coverage


Dependencies
============

None


Testing
=======

None


Documentation Impact
====================

Please refer to :ref:`other_deployer`


References
==========

https://etherpad.openstack.org/p/sighup-conf-reload
