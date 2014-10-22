..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

====================
Taskflow Integration
====================

https://blueprints.launchpad.net/glance/+spec/taskflow-integration

Add a new task executor using the taskflow library.

"TaskFlow is a Python library for OpenStack (and other projects) that helps make
task execution easy, consistent, scalable and reliable. It allows the creation
of lightweight task objects and/or functions that are combined together into
flows (aka: workflows) in a declarative manner.": `Taskflow Wiki <https://wiki.openstack.org/wiki/TaskFlow>`_

Problem description
===================

Glance currently comes with an eventlet executor which is not easily extensible
by nature and doesn't support many features that taskflow support out of the
box such as execution on remote workers.

Proposed change
===============

We propose here a new executor (self-contained) implementing the interfaces of the
executor API. This executor will route the tasks to the eventlet executor of taskflow.
We will be using the `Taskflow Green Thread Pool Executor <http://docs.openstack.org/developer/taskflow/types.html#taskflow.types.futures.GreenThreadPoolExecutor>`_ which ensures that eventlet green threads are used when
using the taskflow engine.
The initial implementation should provide the same result as the eventlet executor
already contained in Glance. However, subsequent blueprints will come to leverage
more advanced functionalities.

Alternatives
------------

Use the existing eventlet executor. This approach is likely to become rewriting
taskflow.

Data model impact
-----------------

None.

REST API impact
---------------

None.

Security impact
---------------

None.

Notifications impact
--------------------

None with this spec. However, in the future, it will be possible to plug-in to
the taskflow notification engine and potentially drop its messages onto a
notification bus.

Other end user impact
---------------------

The end user should be able to transparently execute tasks with all the
executors.

Performance Impact
------------------

For serial execution of tasks, the performance of the evenlet executor and
the taskflow executor should be close to similar.
However, for more complex workflows, we should be able to achieve performance
improvements by parallelizing the work, and also distributing it with taskflow.

Other deployer impact
---------------------

The deployer will have to update glance-api.conf and specify 'taskflow' as the
executor.
Also, it will be possible to choose the engine mode 'serial' or 'parallel' and
the maximum number of workers.
Remote workers (not supported with this spec) will require more infrastructure.

Developer impact
----------------

None.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
 arnaud

Other contributors:
 harlowja

Reviewers
---------

Core reviewer(s):
 nikhil, zhiyan

Other reviewer(s):
 harlowja

Work Items
----------

Implementation of the taskflow executor with unit tests.

Dependencies
============

None.

Testing
=======

It will be possible to add a specifc configuration in DevStack leverage this
new executor. Ultimately, this is the executor that should be used at the gate.

Documentation Impact
====================

Initially, the documentation should explain how to configure glance-api.conf and
what is taskflow. Later on, it should be explained how to achieve more complex
scenario.

References
==========

* https://wiki.openstack.org/wiki/TaskFlow

* https://github.com/openstack/taskflow

* https://pypi.python.org/pypi/taskflow/

* https://review.openstack.org/#/c/85211/14 (needs to be rebased once the spec
  is approved)

* Discussions at the OpenStack Summit in Paris
