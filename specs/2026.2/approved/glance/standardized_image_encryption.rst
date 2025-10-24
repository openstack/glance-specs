..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===========================================
Standardize Image Encryption and Decryption
===========================================

OpenStack already has the ability to create encrypted volumes and ephemeral
storage to ensure the confidentiality of block data. Even though it is also
already possible to store encrypted images, there is only one service (Cinder)
that utilizes this option, but it is only indirectly usable by Nova (a user
must create a volume from the image first), and thus users don't have an
intuitive way to create and upload encrypted images. In addition, all metadata
needed to detect and use encrypted images is either not present or specifically
scoped for Cinder right now. In conclusion, support for encrypted images does
exist to some extent but only in a non-explicit and non-standardized way. To
establish a consistent approach to image encryption for all OpenStack services
as well as users, several adjustments need to be implemented in Glance, Cinder
and OSC.


Problem description
===================

An image, when uploaded to Glance or being created through Nova from an
existing server (a VM snapshot), may contain sensitive information. The already
provided signature functionality only protects images against alteration.
Images may be stored on several hosts over long periods of time. First and
foremost this includes the image storage hosts of Glance itself. Furthermore it
might also involve caches on systems like compute hosts. In conclusion they are
exposed to a multitude of potential scenarios involving different hosts with
different access patterns and attack surfaces. The OpenStack components
involved in those scenarios do not protect the confidentiality of image data.

Using encrypted storage backends for volume and compute hosts in conjunction
with direct data transfer from/to encrypted images can enable workflows that
never expose an image's data on a host's filesystem. Storage of encryption keys
on a dedicated key manager host ensures isolation and access control for the
keys as well.

As stated in the introduction above, some disk image encryption implementations
for ephemeral disks in Nova and volumes in Cinder already touch on this topic
but not always in a standardized and interoperable way. For example, the way of
handling image metadata and encryption keys can differ. Furthermore, users
are not easily able to make use of these implementations when supplying their
own images in a way that encryption can work the same across services.

That’s why we propose the introduction of a streamlined encrypted image format
along with well-defined metadata specifications which will be supported across
OpenStack services for the existing encryption implementations and increase
interoperability as well as usability for users.

Use Cases
---------

1. A user wants to upload an image, which includes sensitive information. To
   ensure the integrity of the image, a signature can be generated and used
   for verification. Additionally, the user wants to protect the
   confidentiality of the image data through encryption. The user generates or
   uploads a key in the key manager (e.g. Barbican) and uses it to encrypt the
   image locally before uploading it. A mechanism to let the OpenStack Client
   (OSC) do the encryption could be added in a later version.
   Consequently, the image stored on the Glance host is encrypted.

2. A user wants to create a new server or volume based on a) an encrypted image
   created externally or b) an image created as a backup from already encrypted
   storage objects in components like Nova and Cinder. The corresponding
   compute or volume host has to be able to directly use the encrypted image or
   (if incompatible) transfer its encryption from e.g. qcow2-LUKS to raw
   LUKS-encrypted blocks to be used for volumes. For this the OpenStack
   services need access to the key in the key manager and a few image
   properties about the encrypted image.

3. A user wants to download and directly decrypt an encrypted image to be used
   privately or in another deployment. If possible, the download mechanism
   could be adjusted on client side to directly decrypt such an image.


Proposed change
===============

We propose two major format choices for encrypting images. The first is
creating a qcow2-formatted disk with qcow2's native LUKS encryption feature.
The 'container_format' for such an image will be 'bare' and its 'disk_format'
will consequently be 'qcow2'. The encryption in this case can be detected
through the presence of the proposed additional metadata or by inspecting the
qcow2 header. The second choice is a LUKS-encrypted disk with either raw or gpt
content. Such image's 'container_format' must be set to 'luks' and the
'disk_format' will be used to indicate the decrypted format: raw or gpt.

Because of these two flavors of encrypted images, we propose the new
'container_format' 'luks' for the raw format, which distinguishes it from the
qcow2-based alternative and makes identification and handling easier.

Furthermore, we propose the following additional metadata properties carried by
images of this format:

* 'os_encrypt_format' - the specific mechanism used, e.g. 'LUKSv1'
* 'os_encrypt_key_id' - reference to key in the key manager
* 'os_encrypt_key_deletion_policy' - on image deletion indicates whether the
  key should be deleted too
* 'os_decrypt_size' - size after payload decryption

Glance acts as the first layer of defense when images are uploaded and inspects
their format and structure on upload. We intend to preserve this defense
mechanism for encrypted images. As a result, Glance may need to look at the
first few data blocks of the decrypted payload of an image in order to identify
the inner format and validate against the claimed 'disk_format' value specified
in the image's metadata. This will be necessary for encrypted images with
'container_format' being 'luks' since the payload may be entirely arbitrary.
If in such case the 'disk_format' is specified as 'raw' but the inspector
finds any recognizable non-raw format within (which could've been specified
by setting 'disk_format' to the appropriate equivalent), it will reject the
image due to mismatching specification.
This differentiation is important for services like Nova which will base their
decision on whether to interpret/boot an image depend heavily on the
'disk_format' property.
For this purpose, the image encryption key will be used in the Glance defender
mechanisms to decrypt the first few blocks of the image payload in-memory and
identify the contained disk format based on its header (if any). As this
forms a dedicated encryption implementation separate from the image consuming
entities, it will have its own configuration values added to it. For example to
configure the hash iteration limit for LUKS encryption.

We have to also introduce the following limitation:

* encrypted images cannot be combined with compression.

Due to both 'luks' and 'compressed' being individual values for the container
format of an image, they cannot be combined on a metadata level to properly
represent the image. However, given the result of a LUKS block encryption, any
compression would have negligible benefits anyway, as the encrypted data is
hardly compressible. As such, we consider this an acceptable limitation.

To upload an encrypted image to Glance we want to extend the OpenStack Client
to allow the specification of the necessary metadata properties as the key ID
and the encryption and optionally metadata properties as for example the
specification of the key deletion policy.
Later on there might be support added for encrypting images using the specified
key ID directly in the OpenStack Client.

In other words: the user has to encrypt an image before the upload. While
uploading the encrypted image to Glance, the metadata properties above have to
be specified.

We propose to align the encryption with Nova and Cinder and use LUKS, which
will be allowed in combination with qcow2 and raw images. We use these two
variations for the following reasons:

1. Nova might be able to directly use qcow2+LUKS encrypted images when creating
   a server. The qcow2 format is already familiar to Nova and used by it to
   directly boot instances from. Currently, support for encrypted ephemeral
   storage is not yet implemented in Nova, so qcow2+LUKS cannot be used by it
   yet but since the LUKS encryption is a native feature of qcow2, this
   will provide a good starting point for a lightweight future extension.

2. Cinder allows the creation of images from encrypted volumes. These will
   always result in LUKS-encrypted raw images. Those images can be converted
   directly to volumes again. This behavior is already implemented and requires
   no format conversion as the LUKS encryption is native to Cinder.
   The intention is to keep this functionality and make the format usable
   outside of Cinder and provide interoperability or it.

In the latter case it is already possible to upload such an encrypted image to
another OpenStack infrastructure, upload the key as well and set the
corresponding metadata. After doing so the image can be used in the second
infrastructure to create an encrypted volume.

We want to align the existing implementations between Nova and Cinder by
standardizing the used metadata parameters and adding interoperability where
applicable. Furthermore, we want to provide users with the means to encrypt
images outside of the infrastructure for upload in Glance which will later be
handled in similar ways by both Cinder and Nova.

The key management is handled differently than with encrypted volumes or
encrypted ephemeral storage. The reason for this is, that the encryption and
decryption of an image does mostly happen outside of Glance on client side
where the image is produced or consumed.
Therefore the service which needs to create a key for a newly created
encrypted image may not be the same service which then has to delete the key
(in most cases Glance). To delete a key, which has not been created by the same
entity, is bad behavior. To avoid this, we choose to do the following:

1. if a user uploads an image the user is responsible for creation and deletion
   of the key.
2. if Cinder or Nova are uploading an image, they are responsible for creating
   a key (e.g. as it is handled in Cinder currently).

Optionally the deletion of the secret can be delegated to Glance through
setting the special metadata parameter "os_encrypt_key_deletion_policy" to
"on_image_deletion". This behavior is already implemented for encrypted images
from Cinder, we will only rename the property so it is not solely be usable by
Cinder.

To not accidentally delete a key, which is used to encrypt an image, we will
let Glance register as a consumer of that key (secret in Barbican [1]) when
the corresponding encrypted image is uploaded and unregister as a consumer
when the image is deleted in Glance. When the parameter
"os_encrypt_key_deletion_policy" is set to "on_image_deletion", we will try to
delete the key. If that fails, because there was still a consumer, we let
Glance log that as a warning and proceed with the image deletion process. In
this case the key might still be used for another image or some other
ressource and we do not want to delete it, we rather assume that
the "os_encrypt_key_deletion_policy" was mistakenly set to "True".

The image conversion plugin will not be extended to be able to handle image
encryption as part of this spec and as such, conversion of encrypted images
during import will not be supported. The usage of the conversion plugin is not
a user choice and because of this, converting an encrypted image to
potentially unencrypted formats by removing the encryption without the user
knowing would undermine its purpose entirely. Furthermore, any conversion of
encrypted images would require decryption to be handled by the Glance import
plugin and appropriate access to Barbican from within the plugin flow
architecture, which exceeds the scope of this spec. So if image conversion is
enabled and an encrypted image is uploaded, the conversion plugin will simply
skip the conversion like it currently does for ISO images and leave the image
in its original format.

Alternatives
------------

Regarding container formats:

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

We evaluated to use a single container format for all encrypted images, but as
Cinder already stores Images within different containers (e.g. 'compressed')
we decided to use the usual container format and check for the presence of
encryption parameters instead to detect an encrypted image.

Regarding the encryption mechanism and algorithm:

We also evaluated an image encryption implementation based on GPG. The downside
with such an implementation is, that everytime such an image is used to create
a server or a volume the image has to be decrypted and maybe re-encrypted for
another encryption format as both Nova and Cinder use LUKS as an encryption
mechanism. This would not only have impact on the performance of the operation
but it also would need free space for the encrypted image file, the decrypted
parts and the encrypted volume or server that is created.

Regarding the inspection of decrypted payload by Glance:

The choice to have Glance decrypt and look at the first few blocks of payload
data of an encrypted image might seem controversial at first. In such case the
confidentiality might seem to be unnecessarily disregarded in a place that
on a conceptional level should only act as a storage for the image (Glance).
An alternative could have been to not let Glance decrypt any parts of the image
at all or even grant it access to the encryption key.
However, considering past CVEs like OSSA-2024-001 or OSSA-2026-002 which stem
from unverified image format headers triggering unwanted command execution,
the defense mechanisms in Glance play a crucial role in preventing maliciously
crafted images to cause problems on compute and storage nodes when being
interpreted or converted.
Furthermore, due the interaction with the Secret Consumer interface of the
Barbican key manager and the fact that the key id is part of the image
metadata, Glance already has both the reference and access to the encryption
key anyway. Even if Glance would not actively decrypt any parts of the image
by itself, it certainly would already have the means to do so.

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

Example request:
```
REQ: curl -g -i -X POST
http://a.b.c.d/image/v2/images -H "Content-Type: application/json" .... -d '
{"disk_format": "gpt", "name": "cirros", "container_format": "luks",
"os_encrypt_format": "LUKSv1", "os_encrypt_key_id": "...",
"os_encrypt_key_deletion_policy": "True", "os_decrypt_size": "...", ...}'
```

Additionally the GET image API call will display all set properties.

Security impact
---------------

There are impacts on the security of OpenStack:

* Confidentiality of data in images will be addressed in this spec. This
  mainly concerns image data that is at-rest, cached or in-transit.

* Image encryption is introduced formally, thus cryptographic algorithms will
  be used in all involved components (Nova, Cinder, OSC).

* Glance must retain the ability to provide a first-layer defense.
  In order for the Glance defender mechanisms for verifying image formats to
  work for the inner formats raw LUKS images, their decryption key will be
  retrieved and used by Glance during the verification process.

There has been extensive discussion around the problem of verifying encrypted
data payload and how to handle the corresponding disk formats at the Project
Team Gathering (PTG) on October 30st 2025, involving Glance, Cinder and Nova
developers.

* For the qcow-LUKS format, the Glance defender mechanisms for checking qcow2
  headers and format details can be reused as the LUKS encryption is only a
  detail/feature of the qcow2 format.

* In case of raw LUKS images with gpt disk format, the Glance defender
  mechanism could be extended to verify the existence of the GPT header within
  the first blocks of the encryption payload by using the encryption key which
  is available to the involved OpenStack services anyway.

* The case of raw LUKS images with raw disk format is a more complicated one.
  To avoid vulnerabilities related to interpreting maliciously crafted image
  contents like in OSSA-2024-001, these images must be handled with care.
  In contrast to OSSA-2024-001, such image would need to pass through a
  decryption first for the decrypted payload to cause issues by being
  interpreted.

For Nova, the PTG discussion concluded with the decision that Nova will only
directly boot or interpret raw LUKS images when the disk format is gpt and has
been verified. Encrypted images with disk format raw will only be allowed to
be attached as secondary storage devices but not booted from or interpreted
directly.

For Cinder, the situation is a bit different as Cinder might act as a producer
of raw LUKS-encrypted images with raw disk format itself. This is due to the
fact that the LUKS-based block storage encryption offered for Cinder volumes
is the same as the proposed raw LUKS image encryption format and Cinder has
effectively been creating raw LUKS images from encrypted volumes all the time
using its upload-to-image API action for volumes.
When encrypted volumes have been attached to Nova instances, users might have
placed application-specific arbitrary data on them, potentially even omitting
any partition header (e.g. GPT) or any kind of recognizable data at all. As
such, images resulting from these volumes cannot be assumed to have a
verifiable disk format. Their disk format can only be classified as raw.

For Cinder to be able to restore encrypted images originating from itself, it
needs to be able to create bootable volumes even from those with raw disk
format. This is in contrast to Nova, where such images would not be acceptable
for booting instances directly.
However, for Cinder there are two key differences to be considered here:

1. Firstly, since the image encryption format of raw LUKS matches the volume
   encryption format, the data is never converted or interpreted when creating
   a volume from such image. Data is simply copied from image to volume
   directly, preserving the LUKS-encrypted blocks, so no interpretation is
   happening within Cinder.

2. Secondly, when volumes are handled in Nova, they are not interpreted in the
   same way as images. For LUKS-encrypted volumes there are two ways for them
   to be handled. In case of QEMU/KVM, they can be passed to the hypervisor
   directly leveraging the native LUKS implementation in QEMU. In any other
   case, the encryption is handled by the host kernel using dm-crypt and the
   block device interface exposing the decrypted block data is passed directly
   into the guest.
   In both cases, the decrypted payload described by the raw disk format is
   only interpreted by the guest virtual machine as it is passed as a block
   device directly into it.

As such, encrypted volumes originating from an encrypted image with raw disk
format would not cause issues in Nova in the same way as the encrypted images
themselves would directly.


Notifications impact
--------------------

None


Other end user impact
---------------------

* Users should be able to optionally, but knowingly upload an encrypted image.

* Users will need to be educated on how to create encrypted images and how to
  choose the correct format including both qcow-LUKS and raw LUKS as well as
  raw and gpt disk format variants for the latter. They will need to be made
  aware of the implications and restrictions of each of them.


Performance Impact
------------------

The proposed encryption/decryption mechanisms in the OpenStack components will
only be utilized on the client side and skipped entirely for images that
aren’t encrypted.

When creating a volume or server from an encrypted image the only operation
that may be triggered is the conversion between qcow-LUKS and raw LUKS blocks.

When encrypted images are inspected by Glance, a decryption of a few blocks of
encrypted data will happen for verification purposes. A malfunctioning or
maliciously crafted LUKS header with excessive hash iteration count for example
will be limited by a configurable threshold and rejected if exceeded.
With reasonable limits in place, decrypting few blocks of data should not
result in major performance impact for Glance hosts receiving such images.

Thus, any performance impact is only applicable to the newly introduced
encrypted image type where the processing of the image will have increased
computational costs and longer processing times than regular images. Impact
will vary depending on the individual host performance and supported CPU
extensions for cipher algorithms.


Other deployer impact
---------------------

* A key manager - like Barbican - is required, if encrypted images are to be
  used.

* One or more configuration values for the image inspection behavior will be
  provided to adjust the behavior of the decryption mechanism, especially the
  hash iteration limit. Deployers might need to adjust the default values to
  better match their intended thresholds.


Developer impact
----------------

None

Upgrade impact
--------------

We can assume, that all images that are encrypted and already present in an
OpenStack deployment were created from encrypted Cinder volumes. They need to
be adjusted in the following way:

* all images that have 'cinder_encryption_key_id' set, need to have their
  'container_format' property rewritten from 'raw' to 'luks'

* all images that have 'cinder_encryption_key_id' set, need to have this
  property renamed to 'os_encrypt_key_id'

* all images that have 'cinder_encryption_key_deletion_policy' set, need to
  have this property renamed to 'os_encrypt_key_deletion_policy'

Database migration scripts will be added to Glance to automate this process.


Implementation
==============

Assignee(s)
-----------

Primary assignee: Markus Hentsch (IRC: mhen)

Other contributors: Josephine Seifert (IRC: Luzi)

Work Items
----------

* Add standardized parameters with encryption support to Glance

* Extend the defender mechanisms of Glance to be able to inspect encrypted
  images of the raw LUKS format and analyze the inner payload format

* Add registering as consumer for a Barbican secret when uploading an
  encrypted image

* Add unregistering as consumer for a Barbican secret when deleting an
  encrypted image

* Add support for providing the new image properties to the
  python-openstackclient and openstacksdk, so that an encrypted image
  can be uploaded

* Change the usages of 'cinder_encryption_key_deletion_policy' and
  'cinder_encryption_key_id' throughout the Glance codebase to the new
  parameters

* Add unit test and functional test for uploading encrypted images

* Add a migration script for the transformation of legacy properties of the
  volume based encrypted images

* Introduce appropriate configuration variables to adjust the image inspection
  behavior, for example its hash iteration limit for decryption

* Adjust the documentation to show the new and changed parameters

* Add the image encryption as documentation in the security guide


Dependencies
============

* The secret consumer API in Barbican is required for Glance to be able to
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
OpenStack configuration. An end user should have documentation on how to create
and use encrypted images.


References
==========

[1] Barbican Secret Consumer Spec:
https://review.opendev.org/#/c/662013/


History
=======

.. list-table:: Revisions
   :header-rows: 1

   * - Release Name
     - Description
   * - Gazpacho
     - Introduced
