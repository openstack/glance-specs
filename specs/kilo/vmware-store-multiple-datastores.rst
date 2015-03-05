..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==================================================
Glance VMware store to support multiple datastores
==================================================

https://blueprints.launchpad.net/glance/+spec/vmware-store-multiple-datastores

Glance, when configured to use VMware store, stores the images in a virtual
storage container called datastore, identified by the configuration option
vmware_datastore_name. The size of the datastore can only be increased to a
certain limit which also depends upon the underlying physical storage.

The capacity of the store is thus bound by the size of a single datastore and
poses serious scalability issues.


Problem description
===================

Currently the number of images stored by glance, when configured to use VMware
store, is limited by the capacity of a single datastore. The size of a
datastore has an upper bound [1].

e.g The maximum datastore size is 64TB when backed by VMFS-5 filesystem. While
the same for a datastore with NFS may depend on the storage array vendor. While
this is the theoretical maximum based on the supported filesystem, datastores
are also sized based on the underlying physical storage, including internal and
external devices and networked storage. With networked storage the choice of
storage protocol (iSCSI, FC, FCoE) also play a vital role in deciding the
optimal size. Thus, the capacity of a datastore used in a datacenter varies by
deployment.

Apart from the capacity, there may be a performance bottleneck when many
compute nodes concurrently access a single datastore to download images.


Proposed change
===============

To allow adding more capacity and improving performance, we suggest the use of
multiple datastores for storing images.

There is only one major aspect of the proposed change:
- Datastore Selection.

**1) Datastore Selection:**

This change proposes to select a datastore based on the priority given to it by
the operator and the capacity to accommodate the image. A new configuration
option (say vmware_datastores) will be added that would enable the operator to
specify multiple datastores along with their relative weights. In case of equal
priority the selection will be based on the maximum freespace available on the
datastore. This approach is very similar to filesystem_store_datadirs used by
filesystem store.

Example: say vmware_datastores is configured with nfs_datastore,
iscsi_datastore, ssd_datastore with weights 100, 100 and 200 respectively.
Here, ssd_datastore will be the preferred datastore if it
can accommodate the image data being added. Otherwise, nfs_datastore or
iscsi_datastore will be chosen based on maximum freespace available.

Alternatives
------------

1) The datastore selection can be done through round-robin/randomized strategy
instead of priority-based. This would be ideal if all datastores are of same
type and perform similarly. But since datastores are of different types, the
strategy is best driven by operator input. e.g SSD backed datastores may be
faster that networked datastores. While its possible to determine
the type of datastore, implicit assumptions cannot be made.

Data model impact
-----------------

Does not have any impact on glance data model.

REST API impact
---------------

None

Security impact
---------------

This spec only adds a selection logic to the existing functionality and hence
does not have any security impact.

Notifications impact
--------------------

None

Other end user impact
---------------------

None

Performance Impact
------------------

The use of multiple datastores will reduce concurrent operations on a single
datastore.

Other deployer impact
---------------------

This proposal will allow administrators to configure multiple datastores to
save the image data in VMware storage backend. If enabled, it will override
the existing configuration option *vmware_datastore_name* that allows to
specify a single datastore. If disabled, the store will fallback to
vmware_datastore_name option. Thus, the change is backwards compatible. We
will deprecate the vmware_datastore_name option going forward.

New Multi Strings configuration option in *glance-api.conf*

**vmware_datastores**
Optional. Default: Not set.

A datastore along with its datacenter path and a weight. If the
datastore is a member of a datastore cluster, then the name of the cluster
should also be included. Otherwise, the cluster name can be omitted. This
option can be specified multiple times to specify multiple datastores.
Thus, the required format becomes:

vmware_datastores =
  <datacenter_path>:<datastore1>:<weight>
vmware_datastores =
  <datacenter_path>:<datastore_cluster_name>:<datastore2>:<weight>

The weights are used to establish the relative priorities of the specified
datastores. Thus, they can be any arbitrary integer values.

Examples:
  vmware_datastores =
    datacenter1:nfs_datastore:2
  vmware_datastores =
    datacenter1:ssd_datastore:3
  vmware_datastores =
    datacenter1:backup_datastore:1

In the above example, ssd_datastore will be given highest priority, followed
by nfs_datastore and backup_datastore.

  vmware_datastores =
    datacenter1:nfs1_datastore:100
  vmware_datastores =
    datacenter1:nfs2_datastore:100
  vmware_datastores =
    datacenter1:backup_datastore:50

In this example, the nfs datastores will be given equal priority, followed by
the backup_datastore. With equal priority, the contention between nfs
datastores is resolved by the maximum freespace.

Note:- If the datacenter path or datastore name contains a colon (:) symbol,
it must be escaped with a backslash.


Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  smurugesan (sabari)

Other contributors:
  None

Reviewers
---------

Core reviewer(s):
  nikhil-komawar
  arnaudleg

Other reviewer(s):
  rgerganov

Work Items
----------

1) Implement new config option in VMware store driver.
2) Implement datastore selection logic in the VMware store driver.
3) Implement unit tests.
4) Change glance-api sample conf in glance repository.
5) Add a deprecation warning for vmware_datastore_name.
6) Update the documentation.


Dependencies
============

* oslo.vmware has introduced a Datastore object which will be used in this
  implementation.
* oslo.vmware has a vim_util module that has some low-level utility methods
  to interact with the vmware api's. This is required to parse api responses.


Testing
=======

* Tempest tests are not required.


Documentation Impact
====================

* Document new configuration options.


References
==========

[1] http://www.vmware.com/pdf/vsphere5/r55/vsphere-55-configuration-maximums.pdf
