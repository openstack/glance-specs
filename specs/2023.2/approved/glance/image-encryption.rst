..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===============================
Image Encryption and Decryption
===============================

OpenStack already has the ability to create encrypted volumes and ephemeral
storage to ensure the confidentiality of block data. In contrast to that,
images are currently handled without protection towards confidentiality, only
providing the possibility to ensure integrity using image signatures. For
further protection of user data - e.g. when a user uploads an image containing
private data or confidential information - the image data should not be
accessible for unauthorized entities. For this purpose, an encrypted image
format is to be introduced in OpenStack. In conclusion, several adjustments to
support image encryption/decryption in various projects, e.g. Nova, Glance,
Cinder and OSC, need to be implemented.


Problem description
===================

An image, when uploaded to Glance or being created through Nova from an
existing server (VM), may contain sensitive information. The already provided
signature functionality only protects images against alteration. Images may be
stored on several hosts over long periods of time. First and foremost this
includes the image storage hosts of Glance itself. Furthermore it might also
involve caches on systems like compute hosts. In conclusion they are exposed
to a multitude of potential scenarios involving different hosts with different
access patterns and attack surfaces. The OpenStack components involved in
those scenarios do not protect the confidentiality of image data.

Using encrypted storage backends for volume and compute hosts in conjunction
with direct data transfer from/to encrypted images can enable workflows that
never expose an image's data on a host's filesystem. Storage of encryption
keys on a dedicated key manager host ensures isolation and access control for
the keys as well. With such a set of configuration recommendations for
security focused environments, we are able to reach a good foundation. Future
enhancements can build upon that and extend the provided security enhancements
to a broader set of variants.


That’s why we propose the introduction of an encrypted image format.

Use Cases
---------

1. A user wants to upload an image, which includes sensitive information. To
   ensure the integrity of the image, a signature can be generated and used
   for verification. Additionally, the user wants to protect the
   confidentiality of the image data through encryption. The user generates or
   uploads a key in the key manager (e.g. Barbican) and uses it to encrypt the
   image locally using the OpenStack client (osc) when uploading it.
   Consequently, the image stored on the Glance host is encrypted.

2. A user wants to create an image from an existing server with ephemeral
   storage. This server may contain sensitive user data. The corresponding
   compute host then generates the image based on the data of the ephemeral
   storage disk. To protect the confidentiality of the data within the image,
   the user wants Nova to also encrypt the image using a key from the key
   manager, specified by its ID. Consequently, the image stored on the Glance
   host is encrypted.

3. A user wants to create an image from an existing volume. This volume may
   contain sensitive user data. The corresponding volume host then generates
   the image based on the data of the volume. To protect the confidentiality
   of the data within the image, the user wants Cinder to also encrypt the
   image using a key from the key manager, specified by its ID. Consequently,
   the image stored on the Glance host is encrypted.

4. A user wants to create a new server or volume based on an encrypted image
   created by any of the use cases described above. The corresponding compute
   or volume host has to be able to decrypt the image using the symmetric key
   stored in the key manager and transform it into the requested resource
   (server disk or volume). For this, the user needs access to the key in the
   key manager which is controlled via their project role assignment.


Proposed change
===============

For Glance we propose to add a new container_format called 'encrypted'.
Furthermore, we propose the following additional metadata properties carried by
images of this format:

* 'os_glance_encrypt_format' - the main mechanism used, e.g. 'GPG'
* 'os_glance_encrypt_type'   - encryption type, e.g. 'symmetric'
* 'os_glance_encrypt_cipher' - the cipher algorithm, e.g. 'AES256'
* 'os_glance_encrypt_key_id' - reference to key in the key manager
* 'os_glance_decrypt_container_format' - format after payload decryption
* 'os_glance_decrypt_size' - size after payload decryption

To upload an encrypted image to Glance we want to add support for encrypting
images using a key ID which references the symmetric key in the key manager
(e.g. Barbican) in the OpenStack Client. This also involves new CLI arguments to
specify the key ID and encryption method and this implementation should
make use of a centralized encryption implementation provided by a global
library, shared between all involved OpenStack components to eliminate the need
of individual implementations of the encryption mechanism.

In other words: the user or openstack service as cinder for example has to
encrypt an image before the upload. While uploading the encrypted image to
glance, the metadata properties above have to be specified and the container
format has to be set to 'encrypted'.

We propose to use an implementation of symmetric encryption provided by GnuPG as
a basic mechanism supported by this draft. It is a well established
implementation of PGP and supports streamable encryption/decryption processes.

We require the streamability of the encryption/decryption mechanism for two
reasons:

1. Loading entire images into the memory of compute hosts or a users system is
   unacceptable.

2. We propose direct decryption-streaming into the target storage (e.g.
   encrypted volume) to prevent the creation of temporary unencrypted files.

There is already one existing case in Cinder’s current implementation where
encrypted images are created. This is when an image is created
directly from an encrypted volume. Since the encrypted block data is simply
copied into the image, the encryption (usually LUKS) is automatically
inherited - as is the encryption key, which is simply cloned in Barbican. We
will not change this behavior as a part of this spec. Our changes will only
apply, when the user actively intends to create an encrypted image from any
volume using the new image encryption extensions.

The key management is handled differently than with encrypted volumes or
encrypted ephemeral storage. The reason for this is, that the encryption and
decryption of an image will never happen in Glance but in all other services,
which consume images. Therefore the service which needs to create a key for
a newly created encrypted image may not be the same service which then has to
delete the key (in most cases Glance). To delete a key, which has not been
created by the same entity, is bad behavior. To avoid this, we choose to let
the user create and delete the key. To not accidently delete a key, which is
used to encrypt an image, we will let Glance register as a consumer of that
key (secret in Barbican [1]) when the corresponding encrypted image is
uploaded and unregister as a consumer when the image is deleted in Glance.


Alternatives
------------

We could introduce individual container types in Glance for each combination
of data format and cipher algorithm instead of a single container type with
metadata. This decision affects the implementation in nova and cinder.

Regarding the image encryption, we also explored the possibility of using more
elaborated and dynamic approaches like PKCS#7 (CMS) but ultimately failed to
find a free open-source implementation (e.g. OpenSSL) that supports streamable
decryption of CMS-wrapped encrypted data. More precisely, no implementation we
tested was able to decrypt a symmetrically encrypted, CMS-wrapped container
without trying to completely load it into memory or suffering from other
limitations regarding big files.

We also evaluated an image encryption implementation based on LUKS which is
already used in Cinder and Nova as an encryption mechanism for volumes and
ephemeral disks respectively. However, we were unable to find a suitable
solution to directly handle file-based LUKS encryption in user space. Firstly,
the handling of LUKS devices (even when file-based) via cryptsetup always
requires the dm-crypt kernel module and corresponding root privileges.
Secondly, in contrast to native LUKS used by LibVirt, the LUKS handling
available via cryptsetup creates temporary device mapper endpoints where data
is read from or written to. There is no direct reading/writing from/to an
encrypted LUKS file and LUKS opening/closing needs to be handled accordingly.
Lastly, LUKS is a format primarily designed for disk encryption. Although it
may be used for files as well (by formatting files as LUKS devices), the
handling is rather inconvenient; for example, the size of the LUKS container
file needs to be calculated and allocated beforehand since it acts like a disk
with a fixed size.


Data model impact
-----------------

The impact depends on whether the implementation will make actual changes to
the image data model or simply use the generic properties field in the
metadata. In the latter case the encryption properties would be added to
metadefs.


REST API impact
---------------

While uploading an image, which should be encrypted, additional properties in
the request body will need to be introduced to specify the desired encryption
format and key id. Both to be used while encrypting the image locally before
uploading it.

Security impact
---------------

There are impacts on the security of OpenStack:

* confidentiality of data in images will be addressed in this spec

* image encryption is introduced, thus cryptographic algorithms will be used
  in all involved components (Nova, Cinder, OSC)


Notifications impact
--------------------

None

Other end user impact
---------------------

* Users should be able to optionally, but knowingly upload an encrypted image.

* If an administrator has configured Glance to reject unencrypted images, such
  images will not be accepted when attempted to be uploaded to Glance.

Performance Impact
------------------

The proposed encryption/decryption mechanisms in the OpenStack components will
only be utilized on-demand and skipped entirely for image container types that
aren’t encrypted.

Thus, any performance impact is only applicable to the newly introduced
encrypted image type where the processing of the image will have increased
computational costs and longer processing times than regular images. Impact
will vary depending on the individual host performance and supported CPU
extensions for cipher algorithms.


Other deployer impact
---------------------

* Deployers can toggle the acceptance or enforce the usage of encrypted images
  by adding/omitting 'encrypted' in 'container_formats' accordingly.

* Deployers enforcing the usage of encrypted images by omitting all other image
  types in 'container_formats' will make public images unavailable due to the
  lack of a public secrets functionality in Barbican.

* A key manager - like Barbican - is required.


Developer impact
----------------

None

Upgrade impact
--------------

none


Implementation
==============

Assignee(s)
-----------

Primary assignee: Markus Hentsch (IRC: mhen)

Other contributors: Josephine Seifert (IRC: Luzi)

Work Items
----------

* Add container type(s) with encryption support to Glance

* Add registering as consumer for a Barbican secret when uploading an
  encrypted image

* Add unregistering as consumer for a Barbican secret when deleting an
  encrypted image

* Provide compatibility to the image_conversion plugin for Interoperable Image
  Import (skip conversion attempt for encrypted payload)

* Add support for providing the new image properties to the
  python-glanceclient, so that an image with the container_format: encrypted
  can be uploaded


Dependencies
============

* GPG is required to be installed on all systems that are required to perform
  encryption/decryption operations in order to support the proposed base
  encryption mechanism.

* This spec requires the implementation of appropriate encryption/decryption
  functionality in a global library shared between the components involved in
  image encryption workflows (Nova, Cinder, OSC). We determined to use
  os-brick.

* The secret consumer API in Barbican is required for glance to be able to
  register and unregister as a consumer of a secret


Testing
=======

Tempest tests would require access to encrypted images for testing. This means
that Tempest either needs to be provided with an image file that is already
encrypted and its corresponding key or needs to be able to encrypt images
itself. This point is still open for discussion.

Documentation Impact
====================

It should be documented for deployers, how to enable this feature in the
OpenStack configuration. An end user should have documentation on, how to use
encrypted images.


References
==========

[1] Barbican Secret Consumer Spec:
https://review.opendev.org/#/c/662013/

Nova-Spec: https://review.openstack.org/#/c/608696/

Cinder Spec: https://review.openstack.org/#/c/608663/


History
=======

.. list-table:: Revisions
   :header-rows: 1

   * - Release Name
     - Description
   * - Victoria
     - Introduced
