..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=========================
Running Glance on Windows
=========================

https://blueprints.launchpad.net/glance/+spec/windows-support

The goal is to allow Glance services to run on Windows, which enables Hyper-V
OpenStack deployments to take full advantage of Microsoft storage solutions.

Problem description
===================

At the moment, Glance services cannot be run on Windows. To bring some context,
there are OpenStack deployments that rely on Hyper-V compute nodes along with
other Microsoft technologies.

In terms of storage, the most commonly used SDS solution is Storage Spaces
Direct (S2D) along with highly available Scale-Out File Server (SoFS) SMB
shares.

One issue is that the Linux cifs driver currently provides limited HA SMB share
support (most versions can't even connect to HA shares, there's no Witness
service support, automatic failover was recently added).

That being considered, most deployers have to use a separate storage backend
for their Glance images (e.g. Swift, Ceph, etc).

Allowing Glance to run on Windows will allow deployers to benefit more from
their S2D backends, commonly used for storing VM disks (currently handled by
Nova as root images or Cinder as attachable volumes). In particular, this will
be useful for hyper-converged deployments, where having to deploy yet another
storage backend may not be desired.

Proposed change
===============

Getting Glance services to run on Windows is not that difficult. There are just
a few things that we need to change:

* avoid forking, not available on Windows
* avoid unavailable signals
* avoid renaming/deleting in-use files
* avoid using binaries that aren't available on Windows
* avoid having eventlet monkey-patch the os module as this will cause
  subprocess.Popen to fail
* avoid missing features or libraires (e.g. xattr)
* some small differences in path handling ('/' will be handled as a relative
  path)
* avoid connecting to '0.0.0.0', use '127.0.0.1' instead. This mostly applies
  to the functional tests

All the above points are covered in less than 150 LOC (a few hundred more if we
count the tests as well), without affecting the Linux behavior.

The ``os-win`` library will be used for most of the Windows low-level
operations, which is an official OpenStack project.

The main goal is to use the filesystem driver along with SMB shares or
Cluster Shared Volumes (CSV).

IIS will not be supported initially, using eventlet wsgi instead (which happens
to be the recommended way of deploying Glance at the moment).

Alternatives
------------

For Hyper-V deployments, the alternative is to keep running Glance on separate
Linux hosts, having to deploy an additional storage backend or go with the
limited HA SMB share support that's currently available on Linux.

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

Performance wise, there shouldn't be any big differences. Spinning up new
processes may be a bit slower on Windows, for which reason the functional
tests may take longer to complete.

Other deployer impact
---------------------

Glance will now be able to run on Windows. Not much changes config wise.

Keep in mind that we're mainly targeting the file store for the beginning
(which is the main reason we want Glance to run on Windows).

Glance will prefferably run as a Windows service. In general, we provide MSI
packages that simplify installing and configuring OpenStack services (e.g.
Nova, Neutron agent, Cinder, etc), which can also be run unattendedly.

We intend to provide Juju charms as well that will allow deploying Glance
on Windows.

One thing to note is that ``os-win`` currently supports Windows Sever 2012 or
above.

Developer impact
----------------

Developers should keep in mind that Glance is supposed to be portable.

Judging from past experience, this hasn't been a problem with other
OpenStack projects. Glance doesn't use too many platform specific libraries
or binaries, so it should be fine.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  lpetrut

Other contributors:
  None

Work Items
----------

This work has been divided in 3 patches:

* a small patch that allows Glance services to run on Windows
* an additional one that allows multiple processes to be used by API services
* a patch that allows all Glance unit and functional tests to run on Windows

A few small changes were needed on ``os-win`` as well, exposing some low-level
Windows primitives.

Dependencies
============

We rely on ``os-win``, which is an official OpenStack library that exposes
low-level Windows functionality. It's currently used by a few other OpenStack
projects, such as Nova, Cinder, Ceilometer, networking-hyperv, etc.

Testing
=======

The already existing tests provide enough coverage. Still, the unit and
functional tests will need some small changes in order to be able to run on
Windows (currently relying on some Linux specific functionality).

We intend to provide 3rd party CI testing. For the record, we're currently
voting on Nova, Cinder and Neutron patches, running tests against Hyper-V.

Documentation Impact
====================

The documentation should be updated to point out the fact that Glance is now
Windows compatible, along with some installing and configuration guide.

References
==========

* `SOFS Overview`_
* `SMB3 Overview`_
* `os_win repo`_
* `linux cifs module missing features`_

.. _SOFS Overview: https://docs.microsoft.com/en-us/windows-server/failover-clustering/sofs-overview
.. _SMB3 Overview: https://support.microsoft.com/en-nz/help/2709568/new-smb-3-0-features-in-the-windows-server-2012-file-server
.. _linux cifs module missing features: https://github.com/torvalds/linux/blob/v4.20/Documentation/filesystems/cifs/TODO
.. _os_win repo: https://github.com/openstack/os-win
