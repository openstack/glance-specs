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

Furthermore, we propose the following additional metadata properties carried by
images of this format:

* 'os_encrypt_format' - the main mechanism used, e.g. 'LUKS'
* 'os_encrypt_cipher' - the cipher algorithm, e.g. 'AES256'
* 'os_encrypt_key_id' - reference to key in the key manager
* 'os_encrypt_key_deletion_policy' - on image deletion indicates whether the
  key should be deleted too
* 'os_decrypt_container_format' - format change, e.g. from 'compressed' to
  'bare'
* 'os_decrypt_size' - size after payload decryption

The 'disk_format' of images, that will be used by Nova and Cinder are either
'qcow2' or 'raw'.

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
will be allowed in combination with qcow and raw images. We use this two
versions for the following reasons:

1. Nova can directly use qcow-LUKS encrypted when creating a server. This is
   the standard procedure of Nova. Nova can also handle LUKS-encrypted raw
   images.

2. Cinder allows the creation of Images from encrypted volumes. These will
   always result in LUKS-encrypted raw images. Those images can be converted
   directly to volumes again. Cinder currently expects encrypted images to be
   raw images.

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
decryption of an image should never happen in Glance but only on client side.
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
true. This behavior is already implemented for encrypted images from Cinder,
we will only rename the property so it is not solely be usable by Cinder.

To not accidentally delete a key, which is used to encrypt an image, we will
let Glance register as a consumer of that key (secret in Barbican [1]) when the
corresponding encrypted image is uploaded and unregister as a consumer when the
image is deleted in Glance. When the parameter "os_encrypt_key_deletion_policy"
is set to "True", we will try to delete the key. If that fails, because there
was still a consumer, we let Glance log that as a warning and proceed with the
image deletion process. In this case the key might still be used for another
image or some other ressource and we do not want to delete it, we rather assume
that the "os_encrypt_key_deletion_policy" was mistakenly set to "True".

Image conversion will not be encryption-aware as part of this spec and as such,
conversion of encrypted images will not be supported. The vmdk format is not
supported by this spec and the conversion itself would need decryption and
encryption to be handled by Glance. This would be more than the scope of this
spec will be. So if image conversion is enabled and an encrypted images that
needs conversion is uploaded the API will return a 400 Error and the image will
be put in the queued state as a result.

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

We also evaluated an image encryption implementation based on GPG. The downside
with such an implementation is, that everytime such an image is used to create
a server or a volume the image has to be decrypted and maybe re-encrypted for
another encryption format as both Nova and Cinder use LUKS as an encryption
mechanism. This would not only have impact on the performance of the operation
but it also would need free space for the encrypted image file, the decrypted
parts and the encrypted volume or server that is created.

We evaluated to use a single container format for all encrypted images, but as
Cinder already stores Images within different containers (e.g. 'compressed')
we decided to use the usual container format and check for the presence of
encryption parameters instead to detect an encrypted image.

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
{"disk_format": "raw", "name": "cirros", "container_format": "compressed",
"os_encrypt_format": "LUKS", "os_encrypt_key_id": "...",
"os_encrypt_key_deletion_policy": "True", "os_encrypt_cipher": "...",
"os_decrypt_container_format": "bare", "os_decrypt_size": "...", ...}'
```

Additionally the GET image API call will display all set properties.

Security impact
---------------

There are impacts on the security of OpenStack:

* confidentiality of data in images will be addressed in this spec

* image encryption is introduced formally, thus cryptographic algorithms will
  be used in all involved components (Nova, Cinder, OSC)

* Glance may lose the ability to provide a first-layer defense against image
  policy violations (such as rejecting invalid/disallowed formats), because
  inspection of encrypted data is not possible.


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
only be utilized on the client side and skipped entirely for images that
aren’t encrypted.

When creating a volume or server from an encrypted image the only operation
that may be triggered is the conversion between qcow-LUKS and raw LUKS blocks.

Thus, any performance impact is only applicable to the newly introduced
encrypted image type where the processing of the image will have increased
computational costs and longer processing times than regular images. Impact
will vary depending on the individual host performance and supported CPU
extensions for cipher algorithms.


Other deployer impact
---------------------

* A key manager - like Barbican - is required, if encrypted images are to be
  used.


Developer impact
----------------

None

Upgrade impact
--------------

We can assume, that all images that are encrypted and already present in an
OpenStack deployment were created from encrypted Cinder volumes. They need to
be adjusted in the following way:

* all images that have 'cinder_encryption_key_id' set, need to convert it to
  'os_encrypt_key_id'

* all images that have 'cinder_encryption_key_deletion_policy' set, need to
  convert it to 'os_encrypt_key_deletion_policy'


Implementation
==============

Assignee(s)
-----------

Primary assignee: Markus Hentsch (IRC: mhen)

Other contributors: Josephine Seifert (IRC: Luzi)

Work Items
----------

* Add standardized parameters with encryption support to Glance

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
   * - Dalmatian
     - Introduced
