..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=======================================
Supporting OVF Single Disk Image Upload
=======================================

https://blueprints.launchpad.net/glance/+spec/ovf-lite

The Open Virtualization Format (OVF) is an open standard for packaging and
distributing virtual appliances that is hypervisor and processor architecture
agnostic. Both enterprise and Telco Network Virtual Function (NVF) providers
desire OpenStack OVF support, to distribute in a standard format appliance
images and deployment requirements to ensure optimal performance. An OVF
package, also called an OVA (file extension ova), is essentially a tar ball
that contains disk images, a manifest and the ovf xml file. A common use case
is a single disk image package with the ovf file containing deployment metadata.
NFV workloads in particular tend to require enhanced platform features and
fine-grained resource provisioning to meet their performance criteria.
For example, special instructions, hardware accelerators, high speed IO, NUMA
awareness, and more. We propose to extract the single root disk image and its
metadata and  save the same in Glance with the goal of easing provisioning,
in particular eliminating the need for error prone manual editing of image
metadata.  The glance image metadata can be used by a custom filter (in the
Mitaka release no nova image properties filter changes can be upstreamed),
or by defining host aggregates using tags from the CIM namespace[H],
that which is used in the OVF to identify appropriate compute hosts.


Problem description
===================

The OVF image format is a format backed by industry (VMware, Ericsson, IBM, and
Red Hat to name a few) and the European Telecommunications Standards Institute.
A common use case is a single disk image OVF package. To handle the same,
VMware even developed a special purpose Nova driver that launches a virtual
machine using an uploaded OVF package with a single image. However, each time
the OVF image is used, it needs to be parsed and the image and its metadata
extracted because it is not a first class glance image, incurring a
performance overhead.

Proposed change
===============

We propose supporting OVF package by adding a new task capable of extracting
the package data and metadata. Support will be limited to extracting the root
disk image and saving it to the Glance image store, followed by parsing the
.ovf file to extract desired metadata specified via a configuration file. Note
that OVF files, which are in XML format, can be complex, and XML allows users
the freedom of representing particularly leaf values as either an element or as
an attribute, making parsing non-trivial. We shall restrict ourselves in this
release to the items in CIM_ProcessorAllocationSettingData given they are of
primary interest to us for VM orchestration purposes. The extracted metadata
will be recorded as image properties on the Glance image record. Typically, the
image provider will specify metadata pertaining to hardware requirements and
deployment parameters that ensure optimal performance. This import
functionality, for the present, will be restricted to admin users, and the
feature itself can be disabled or enabled through configuration using
functionality as proposed in [L]. The metadata may serve, among other things,
to aid Nova in optimal placement/orchestration to ensure meeting vendor
performance, compliance, and/or other requirements.

Alternatives
------------

The alternative is to manually enter image metadata as it is done today, which
is both tedious and error prone, even as we try to automate service delivery in
the cloud.

A full fledged solution where an OVF package has multiple disk images is out of
scope for this effort but is a logical evolution of the feature. We anticipate
in the future the creation of OVF artifacts and transforming their contents
into Heat artifacts. The richness of OVF would need to be captured in Heat,
including its networking aspects.

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

Unpacking an unknown OVA tar file can have security risks, namely gzip
expansion and tar escalation of privilege attacks[J]. In this initial
implementation we shall restrict access to OVA import to admin users.
In a future extension we could address some of these vulnerabilities such as,
examining the tar manifest first (tar tvf foo.ova) to confirm no system paths
or high value files like /etc/passwd are mentioned. To protect from gzip bomb
style attacks an anti-virus program would come in handy and should be threaded
into the process flow. A signature verification functionality would enable
opening up the import functionality to non-admin users, particularly to trusted
image suppliers.

Notifications impact
--------------------

While notifications for OVA processing start and finish can be
helpful there shall be none at this point.

Other end user impact
---------------------

Ease of use.

Performance Impact
------------------

On image upload, additional processing takes place for the extracting and
parsing of the image data and metadata, but this only affects OVA files. Other
formats are unaffected.

With regards to Nova, launching an OVF package will be faster because it is
processed on import (once) rather than on each use.

Other deployer impact
---------------------

Existing OVF packages in Glance can be deployed as before using the VMware
driver. Once this functionality is delivered, disk images may be directly
deployed, like qcow and other images. The Nova OVF driver cannot be
deprecated until all OVF packages are processed using this new strategy.
Please note that this feature requires disk space to support untarring
of archives and that operations might fail due to inadequate disk resources.
Further, the deployer should check the value of image_property_quota in
glance-api.conf to ensure that the quota is set high enough to allow for all
the desired OVF metadata to be stored as image properties.

Developer impact
----------------

None


Implementation
==============

1) A global configuration parameter specifying the metadata of interest to
   extract. Per feedback, this shall be maintained in a separate file
   ovf-metadata.conf with a sample file provided.
   For example::

     {
       ovf_metadata_properties:
           ProcessorArchitecture,
           InstructionSet,
           InstructionSetExtensionName,
           ..
     }

   Possible values::

      ProcessorArchitecture: x86, x86-64, ARM, MIPS
      InstructionSet: ARM A32, ARM A64, MIPS32 (32-bit), MIPS64 (64-bit), POWER
      InstructionSetExtensionName:
          Advanced Vector Extensions (AVX),
          RDRAND (aka SecureKey),
          Advanced Encryption Standard New Instruction (Intel® AES-NI).

   See [H] for an exhaustive list.

2) Download OVA
3) Process the embedded .ovf descriptor file to extract metadata
   and the root disk. Parsing will use the schema in [G]
4) Save the root disk image in Glance
5) Attach the extracted metadata as image properties of the saved disk image

In this initial implementation we will not handle encryption keys or
OVF certificates. Doing so however would add to the security of the feature
and possibly reduce threats as mentioned in [J]. The defcore compliant
refactored image TaskFlow also provides for increased security by way of
limiting size of import and time taken.

An initial implementation using the TaskFlow task executor from Liberty is
ready. When the refactored image import API becomes available, by restricting
the OVF lite import feature to admins only, migrating to the same should be
smooth. Tests to establish the same required. Thus progress on both efforts
can occur in parallel.

Should we drop the desire to support upload of compressed ova, we eliminate
the threat of compression attacks. In conjunction with first examining the
embedded ovf file, it is possible to determine the anticipated size of the
disk image and ensure it is within quota before proceeding with the upload.
Thanks to Mike Gerdt for this compression constraint relaxation suggestion
to make the feature more generally available, that is not restricted to admin
users. However, for Mitaka, we shall restrict this feature to admin users
only, thus allowing compressed files, and in so doing better network
bandwidth use, and more importantly conforming to the image upload refactor
work [M] underway.

Assignee(s)
-----------

Primary assignee:
*  Deepti Ramakrishna (dramakri)
*  Lin Yang (ling-a-yang)

Other contributors:
*  Jakub Jasek
*  Kent Wang

Reviewers
---------

Core reviewer(s):
*  nikhil-komawar
*  Erno Kuvaja
*  Ian Cordasco
*  Flavio Percoco
*  Sabari Murugesan

Other reviewer(s):
*  Brian Rosmaita

Work Items
----------

- Create workflows for tasks, to parse .ovf file, to create glance image
  with metadata. Our Liberty solution missed the deadline.

- Update configuration file to indicate metadata of interest.

- Update configuration and usage documentation

Dependencies
============

* Image save task, shall confirm else enhance that it checks user quota.

Testing
=======

1) Tests for upload covering valid and invalid input such as invalid tar bundle,
   directory with no .ovf file, zero size and excessively large input file sizes.
2) With OVF Lite we would upload both an OVF file in Glance and a regular image.
   We could configure OpenStack to skip saving the OVF file.
3) Integration tests would involve being able to launch an image so loaded using Nova
   boot commands without using the VMware OVF driver.


Documentation Impact
====================

OVF API for CRUD operations need to be documented to indicate the additional image
creation. Delete and update operations would require delete and update of the
additional image in Glance. Will help to document.

Backward functionality is preserved in an upgraded system by maintaining the Nova
OVF driver.

In the future it would be good to introduce a script/task to be invoked in
an upgraded environment that provides OVF Lite support for existing
OVF files in Glance.  Further, should we want to enable/disable this feature
it would be good to work on [L] which currently is abandoned.

References
==========

A. https://en.wikipedia.org/wiki/Open_Virtualization_Format
B. https://en.wikipedia.org/?title=ETSI
C. http://specs.openstack.org/openstack/nova-specs/specs/juno/approved/vmware-driver-ova-support.html
D. http://docs.openstack.org/developer/glance/formats.html
E. Original blueprint: https://wiki.openstack.org/wiki/Enhanced-Platform-Awareness-OVF-Meta-Data-Import
F. https://blueprints.launchpad.net/glance/+spec/introspection-of-images
G. OVF Envelope XML Schema Document (XSD). http://schemas.dmtf.org/ovf/envelope/2/dsp8023_2.0.1.xsd
H. http://schemas.dmtf.org/wbem/cim-html/2/CIM_ProcessorAllocationSettingData.html
I. CIM V2.38.0 schema. http://dmtf.org/standards/cim/cim_schema_v2380
J. https://bugs.python.org/issue21109#msg215656
K. https://en.wikipedia.org/wiki/Zip_bomb
L. Config option for importing subflows: https://review.openstack.org/#/c/194898/
M. Image Import Refactor: https://review.openstack.org/#/c/232371
N. https://blueprints.launchpad.net/glance/+spec/image-signing-and-verification-support
O. https://review.openstack.org/#/c/214810/
P. DMTF Common Information Model (CIM). http://dmtf.org/standards/cim
