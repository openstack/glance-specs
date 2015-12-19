..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================================
CIM Namespace Metadata
==========================================

https://blueprints.launchpad.net/glance/+spec/cim-namespace-metadata-definitions

The OpenStack Kilo release introduced support for defining metadata
definitions and associating the same with different resource types.
To make workloads interoperable across OpenStack clouds, it is
necessary to adopt a common set of metadata, particularly for
hardware architecture, instruction sets, and their extensions.
The Common Information Model(CIM)[A] and the Distributed Management
Task Force (DMTF)[2] have defined a pretty exhaustive list. We
propose including the same into OpenStack.

Problem description
===================

A standard well known set of metadata tags are useful in describing
cloud resources such as images, flavors, compute nodes and more in
the interest of making orchestration across clouds interoperable.
This is yet another step in our cloud federation story.

* I have a workload running on OpenStack cloud-A and would like it
  to run no differently on OpenStack cloud-B. Flavors that specify the
  properties using a common standard set of descriptors will enable this.

* A Network Virtual Function vendor would like to provide an appliance
  with metadata that different clouds can be expected to provide the same
  level of performance, to meet its typically stringent latency needs.
  Several vendors use the Open Virtualization Format (OVF) to package
  their appliances, which uses the CIM format, a DMTF standard.

We would like to introduce the CIM namespace for metadata in OpenStack to foster
cloud interoperability.

Proposed change
===============

The CIM schema files for processor, resources, virtualization,
and storage [C - F] shall be parsed and json files added to
the Glance etc/metadefs directory.
The tool to parse shall also be added in the glance code base to facilitate
gathering updates to the schema files in future OpenStack releases should
there be any, though this is expected to be few and far between.

The Instruction set extensions shall ignore the enabled/disabled item.
The reasoning here is that other than virtualization related instructions,
namely VT-d, VT-x, few instruction extensions are disabled after the
cloud provider expended money on buying the latest platforms.

In this incarnation of the solution, we shall not introduce semantics
such as relationships between the various metadata tags. For instance,
while describing hardware, a compute host that belongs to a certain
processor architecture can only manifest instructions available in the same.

In this release we shall ignore the version of the CIM schema files.
The expectation is that they will add elements, not remove elements, nor
change the type of element values. We already have support in Glance to
upload, overwrite, and merge metadata definitions [K]. This shall come
in handy when a new CIM version of tags is introduced. We could add an
API call that indicates the CIM version number supported for each of
the CIM metadata definition files.


Alternatives
------------

Manually create in each cloud the CIM namespace metadata
using the metadata add API, a tedious error prone task that must be
replicated in each and every OpenStack cloud instance.

Data model impact
-----------------

The introduction of additional json files in the Glance etc/metadefs
directories generated from parsing the CIM schema files for [C],
[D], [E], and [F].

Security impact
---------------

None

Notifications impact
--------------------

None

Other end user impact
---------------------

Ease of use.
The Horizon metadata for CIM namespace would look like the images captured
in [G], [H], [I], and [J] for processor related CIM namespace elements.
Goodness of elastic search is available via Searchlight APIs.

Performance Impact
------------------

None

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
   Lin Yang (lin-a-yang)

Other contributors:
   None

Reviewers
---------

Core reviewer(s):
*  Flavio Percoco
*  Ian Cordasco
*  Nikhil Komawar

Other reviewer(s):

*   Zhi Yan Liu
*   Travis Tripp

Work Items
----------
#. CIM schema to json file

Dependencies
============

None


Testing
=======

1. Tests to confirm our parsing is valid
2. Tests to confirm the metadata has been uploaded correctly in Openstack

Documentation Impact
====================

Need to add documentation stating that the CIM namespace is being introduced.


References
==========

A. https://www.dmtf.org/
B. https://www.dmtf.org/standards/cim
C. http://schemas.dmtf.org/wbem/cim-html/2/CIM_VirtualSystemSettingData.html
D. http://schemas.dmtf.org/wbem/cim-html/2/CIM_ResourceAllocationSettingData.html
E. http://schemas.dmtf.org/wbem/cim-html/2/CIM_StorageAllocationSettingData.html
F. http://schemas.dmtf.org/wbem/cim-html/2/CIM_ProcessorAllocationSettingData.html
G. https://wiki.openstack.org/wiki/File:CIM_namespace.JPG
H. https://wiki.openstack.org/wiki/File:CIM_namespace1.JPG
I. https://wiki.openstack.org/wiki/File:CIM_namespace2.JPG
J. https://wiki.openstack.org/wiki/File:CIM_namespace3.JPG
K. https://review.openstack.org/#/c/159532/
