..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

====================
Handle sparse images
====================

https://blueprints.launchpad.net/glance-store/+spec/handle-sparse-image

Some drivers like rbd and filesystem support sparse image, meaning
not really write null byte sequences but only the data itself at a given
offset, the "holes" who can appear will automatically interpreted by the
storage backend as null bytes, and do not really consume your storage.

Problem description
===================

As glance deal with instance image, it appear that they are majorly composed
of null bytes sequence to represent the whole disk size of the instances, by
exemple the 8GB base CentOS 7 cloud image contain 1GB of data for 7GB of
holes, so it will significantly optimize storage usage and upload time.

Current implementation of rbd and filesystem driver rely on the
``utils.chunkreadable`` function, which will basically split the file to
import into block of ``CHUNK_SIZE``, then these blocks will be directly written
to the backend whatever the content, and the offset will be incremented by the
size of the chunk.

Here is an example for a ceph backend with a standard CentOS 7 cloud image
using Glance:

.. code-block:: shell

    $ rbd du 9b86961e-6bf3-4d0d-99dc-7c762fe6881d
    NAME                                      PROVISIONED USED
    9b86961e-6bf3-4d0d-99dc-7c762fe6881d@snap       8 GiB 8 GiB
    9b86961e-6bf3-4d0d-99dc-7c762fe6881d            8 GiB   0 B
    <TOTAL>                                         8 GiB 8 Gi
    $ rbd export 9b86961e-6bf3-4d0d-99dc-7c762fe6881d /tmp/Centos7full.raw
    $ md5sum /tmp/Centos7full.raw
    aae49f6f57aecb9774f399149a0b7f35 /tmp/Centos7full.raw

And the same result when uploading the same image with qemu-img convert or rbd
import:

.. code-block:: shell

    $ rbd du 437e8de0-b897-4846-96aa-aff70cd8794c
    NAME                                      PROVISIONED USED
    437e8de0-b897-4846-96aa-aff70cd8794c@snap       8 GiB 1008 MiB
    437e8de0-b897-4846-96aa-aff70cd8794c            8 GiB      0 B
    <TOTAL>                                         8 GiB 1008 MiB
    $ rbd export 437e8de0-b897-4846-96aa-aff70cd8794c /tmp/Centos7sparse.raw
    $ md5sum /tmp/Centos7sparse.raw
    aae49f6f57aecb9774f399149a0b7f35 /tmp/Centos7sparse.raw

We can see here that the checksum of the downloaded file, either sparse or not
stay the same, so it should not have impact on the file integrity. In both
case, the ``glance image-download`` command will produce a non sparse file
because download process just read the file in the backend chunk after chunk,
so null byte sequence will be read, sparse file or not.

Proposed change
===============

There is two successive optimization we can make to achieve the same result
as other import tool like qemu-img:

* Do not write null bytes sequences inside chunk (Write optimization)
* Rely on filesystem instruction to skip holes (Read optimization)

A new configuration option ``enable_thin_provisioning`` will be added to rbd
and filesystem backend in order to make it switchable by operator. Enable it
will enable both read and write optimization.

Do not write null bytes sequences inside chunk
----------------------------------------------

This first optimization will work in all case, wether or not the image file
is sparse or not, it is the behaviour implemented in qemu-img. It consist on
checking if the chunk readed is only composed of null bytes, if it's the
case, just increase the offset without writing any data to the store.

Rely on filesystem instruction to skip holes
--------------------------------------------

This second optimization will rely on the syscall SEEK_HOLE and SEEK_DATA,
available since kernel 3.8 and python 3.3. It consist on directly skipping
holes, without even reading the null bytes sequences, which can be very long
in case of a large image like an appliance (hundred of GB). As it rely on
linux kernel syscall, older linux kernel or Windows node will just
skip the optimization and work like before.

This second optimization can only work when the image file is actually
considered as sparse by the filesystem, so it require to be converted
"in-place" on staging store to raw file by the convert plugin of import
workflow. If not, by exemple by sending directly a raw file trough Glance
REST API, filesystem of the staging store won't be aware of the hole.

Alternatives
------------

None

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

Write optimization
++++++++++++++++++

These tests have been done against 2 rbd backend sent through web-download
image-import workflow, with raw conversion enabled.

For a 8GO Centos qcow2:

+------------------------------------+---------------+---------------+---------------+
|             Chunk size             |      8MB      |     32MB      |     64MB      |
+====================================+===============+===============+===============+
| Time without sparse upload         | 3min31        | 3min26        | 3min28        |
+------------------------------------+---------------+---------------+---------------+
| Time with sparse upload            | 1min59        | 1min58        | 2min04        |
+------------------------------------+---------------+---------------+---------------+
|                                    | **-44%**      | **-43%**      | **-40%**      |
+------------------------------------+---------------+---------------+---------------+
| Storage used without sparse upload | 8 GiB/8 GiB   | 8 GiB/8 GiB   | 8 GiB/8 GiB   |
+------------------------------------+---------------+---------------+---------------+
| Storage used with sparse upload    | 1.0 GiB/8 GiB | 1.0 GiB/8 GiB | 1.0 GiB/8 GiB |
+------------------------------------+---------------+---------------+---------------+
|                                    | **-88%**      | **-88%**      | **-88%**      |
+------------------------------------+---------------+---------------+---------------+

For a 200GO Centos qcow2:

+------------------------------------+-------------------+
|             Chunk size             |        8MB        |
+====================================+===================+
| Time without sparse upload         | 4h                |
+------------------------------------+-------------------+
| Time with sparse upload            | 41min11           |
+------------------------------------+-------------------+
|                                    | **-83%**          |
+------------------------------------+-------------------+
| Storage used without sparse upload | 200 GiB/200 GiB   |
+------------------------------------+-------------------+
| Storage used with sparse upload    | 5.8 GiB/200 GiB   |
+------------------------------------+-------------------+
|                                    | **-88%**          |
+------------------------------------+-------------------+

Read optimization
+++++++++++++++++

The following tests have been done by reading data of a Centos 7 image file

+---------------------------------+------------------+----------------+--------------------+------------------+
|                                 | Centos 8GB Qcow2 | Centos 8GB RAW | Centos 100GB Qcow2 | Centos 100GB RAW |
+=================================+==================+================+====================+==================+
| Read all file (including holes) | 0m3.964s         | 0m16.746s      | 0m4.666s           | 3m4.003s         |
+---------------------------------+------------------+----------------+--------------------+------------------+
| Read only data (skip holes)     | 0m2.662s         | 0m4.686s       | 0m3.916s           | 0m4.425s         |
+---------------------------------+------------------+----------------+--------------------+------------------+
|                                 | **-32,8%**       | **-72,0%**     | **-16,1%**         | **-97,6%**       |
+---------------------------------+------------------+----------------+--------------------+------------------+

The optimization for the Qcow2 image tends to be negligible, as Qcow2 images
does not have holes, so it should be very fast in all case.
The point here is to show that there is no negative impact for Qcow2 images,
and huge positive one for raw images, so we can apply this behaviour in all
case.

Other deployer impact
---------------------

Addition of a new ``enable_thin_provisioning`` configuration option for rbd
and filesystem store will require operator to enable it. Without this option,
behaviour will stay the same as before.

As this configuration option is per store, it is possible in a multi-store
environment to choose on which store it will be enabled.

Developer impact
----------------

None, as these optimizations are handled inside drivers itself and should not
change their interfaces.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  alistarle

Other contributors:
  yebinama

Work Items
----------

* Update drivers who can handle sparse images: filesystem and rbd.

Dependencies
============

None

Testing
=======

* Testing that there is no functional regression for the modified drivers.
* Testing that it does not have a negative impact on system where
  SEEK_DATA/SEEK_HOLE instruction are not available.

Documentation Impact
====================

* Document the new configuration option ``enable_thin_provisioning`` for rbd
  and filesystem driver.

References
==========

Original ceph.io article who expose these optimizations:
https://ceph.io/planet/importing-an-existing-ceph-rbd-image-into-glance/

Initial abandonned patch in glance_store:
https://review.opendev.org/#/c/430641/

Python implementation of SEEK_HOLE/SEEK_DATA syscall:
https://bugs.python.org/issue10142