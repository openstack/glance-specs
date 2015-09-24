..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=====================================
Glance Image Signing and Verification
=====================================

https://blueprints.launchpad.net/glance/+spec/image-signing-and-verification-support

OpenStack currently does not support the following feature:

* Signature validation of uploaded signed images

Deploying authentication will protect image integrity by verifying that an
image has not been modified after the upload by the user.  This feature
improves the enterprise-ready posture of OpenStack.


Problem description
===================

There is no method for users to verify that a previously uploaded image has
not been modified.  An image could potentially be modified in transit (such as
when it is uploaded to glance or transferred to nova) or glance itself could
be untrusted and modify images without a user's knowledge.  An image that is
modified could include malicious code.  Providing support for image signatures
and signature verification would allow the user to verify that an image has
not been modified prior to booting the image.

There are several use cases that this feature will support:

* An image is signed by an End User, using the user's private key.  The user
  then uploads the image to Glance, along with the signature created and a
  reference to the user's public key certificate.  Glance uses this
  information to verify that the signature is valid, and notifies the user
  if the signature is invalid.

* An image is created in Nova, and Nova signs the image at the request of the
  End User.  When the image is uploaded to Glance, the signature and public
  key certificate reference are also provided.  Glance verifies the signature
  before storing the image, and notifies Nova if the signature verification
  fails.

* A signed image is requested by Nova, and Glance provides the signature and
  a reference to the public key certificate to Nova along with the image so
  that Nova can verify the signature before booting the image.


Proposed change
===============

For the initial implementation, this change will use the property feature of
Glance to store the metadata items needed for image signing and verification.
These include a public key certificate reference, and the signature.  These
are provided when the image is created, and are accessible when the image is
uploaded.  Note that this proposed change will only support image uploads with
the glance api v2 (and will not support using the glance api v1).  Also note
that multiple formats for the key (such as SubjectPublicKeyInfo) and for the
signature (such as PSS) will be supported.  The format of the signature will
be stored as one of the properties.

The certificate reference will be used to access the certificate from a key
manager, where the certificate will be stored.  This certificate is added to
the key manager by the end user before uploading the image.  Note that the
signature is done offline.

Glance already supports computing checksums of images when an image is
uploaded, and this checksum is stored with the image.  This same hash (which
by default is MD5) will be used for the signature verification.

The checksum hash is computed in glance_store (when the image data is
uploaded), and is then used to verify the signature.  The Glance frontend
should use the reference to the public key certificate to retrieve the
certificate from the key manager, and then use this public key along with the
signature, the computed checksum, and the rest of the signature metadata to
verify the signature.  If the signature verification fails, the image will
transition to a killed state, and the user will be notified that the upload
failed and given a reason why.

Alternatives
------------

An alternative to using the hash already created in the store backend for the
signature verification/creation is to compute a hash in the store frontend.
However, eventlet.wsgi.Input file-like object that represents the image data
can only be read once, and needs to be read in the store backend in order to
upload the image.  In order to read the image data in the Glance frontend,
Glance could copy the data into a file, use the file to verify/create the
signature, and then give this file to the store backend to upload.  This would
be similar to what is done with the S3 backend [1]. However, this approach
would take significantly more time (during image upload), and there would not
be much gained.

An alternative to storing a reference to the public key certificate in Glance
would be to store the actual public key certificate in Glance.  However, this
approach would be insecure, since Glance, unlike a dedicated key manager, has
not been created with storing keys or certificates in mind.

An alternative to using asymmetric keys for integrity and confidentiality is
to use symmetric keys.  However, in order for Glance to be able to verify the
image, it would need to have access to the key used to create the signature.
This access would enable Glance to modify the image and create a new signature
without the user's knowledge.  Using asymmetric keys enables Glance to verify
the signature without giving Glance the power to modify the image and
signature.

An alternative to using the Glance properties to store and retrieve the
signature metadata would be to create an API extension that support
signatures. Then, instead of the user setting the metadata using the property
key value pairs, the API extension would be used. Currently, if a user were to
use the metadata keys (for the certificate and signature) for other purposes,
the image uploads would fail.  Another item of note is that an API extension
would allow for the management of multiple signatures per image in a clean
manner, which is not possible with the properties approach. However, the
Images API does not support extensions, so this is not a valid approach.

Another alternative to using the Glance properties to store and retrieve the
signature metadata would be to use the CMS (cryptographic message syntax)
format as defined in RFC 5652 Section 5.  However, the size for this would be
variable, and could not use the existing Glance properties, which would
require API modifications.  For the initial implementation, Glance properties
will be used, with the plan to migrate to using CMS in a future implementation
as the need for increased flexibility arises.

An alternative to requiring the user to provide the signature separate from
the image is to support images that already have an embedded signature.
Although this could be included as a future improvement, the initial
implementation will not provide embedded signature support, since it is
advantageous to keep the initial effort focused and small.

An alternative to using the existing MD5 hash algorithm is to create a
separate configurable hash for use with verifying/creating the signature.
However, creating a separate hash negatively affects the performance, without
providing much benefit.  Note that since there are preferable hash algorithms
to MD5 that are more secure, a separate change is being proposed to allow for
the configuring of this hash algorithm [2].  This will not be included as a
part of this change, in the interest of having a straightforward initial
implementation.

An alternative to focusing on a single-cloud implementation would be to
include support for multi-clouds in the initial implementation.  If images are
exchanged between different clouds, signature verification could be used to
confirm that images have not be modified.  However, in the interest of a more
simplistic initial implementation, explicit support for multi-clouds will be
saved for future iterations.

Data model impact
-----------------

None.

REST API impact
---------------

No API changes will be needed for the initial implementation, provided that
other services are able to retrieve all of the properties of a given image.

Note that the existing API allows for providing the signature metadata as
glance properties, and returning an error message if verification fails.

Security impact
---------------

This change improves the enterprise-ready posture of OpenStack by enabling
signature signing and verification.

Although keys are used in this change, the keys themselves are assumed to be
stored in a key manager, and only a reference to the certificate is stored in
Glance.

This change involves hashing the image data for use in verifying and creating
signatures for the image.

Note that the signature length is currently limited to 255 bytes, since this
is the maximum size supported for glance properties.  In turn, this limits
the size of the keys that can be used for signature creation.

Notifications impact
--------------------

This change will involve adding log messages to indicate the success or
failure of signature verification and creation.

Other end user impact
---------------------

The user will be required to provide the appropriate information needed for
the signing and verification in order to use this feature.

There are no changes that need to be made to python-glanceclient.

Performance Impact
------------------

The feature will only be used if a user has provided the appropriate
properties during the image upload.  Otherwise, no signature verification or
creation will occur.

When signature verification and creation do occur, there will be some latency
associated with retrieving the certificate from the key manager.  Since the
hash is already being created for images, the hash creation has no impact to
performance.

Other deployer impact
---------------------

None.

Developer impact
----------------

None.


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  brianna-poulos

Other contributors:
  dane-fichter

Reviewers
---------

Core reviewer(s):
  flaper87
  sigmavirus24
  nikhil_k

Other reviewer(s):
  joel-coffman

Work Items
----------

The feature will be tackled in the following stages:

1. Enable Glance to verify signatures provided by the user during an image
   upload initiated by the user.
2. Enable Glance to verify signatures provided by Nova during an image upload
   of a snapshot taken by Nova.


Dependencies
============

The cryptography library, which will be used for hash creation and signature
verification and creation, is already a part of the global-requirements of
OpenStack.  However, it is not a part of glance, and will need to be added
there.

Glance currently does not interact with any key managers.  Since a key manager
is needed to manage the keys, changes will need to be made to allow Glance to
retrieve the public key certificate using a key manager.  Specifically,
Castellan [3] will be used to interface with the key manager chosen.  The
initial key manager will be Barbican, but Castellan can be configured to use a
different backend.

In order to take advantage of the signatures in Glance, Nova will need to
be updated to retrieve the signatures from Glance and verify them.  However,
Glance does not depend on Nova to have this support in order to have the
feature added.  The spec for this in Nova [4] has not yet been approved.


Testing
=======

Before Nova support for this feature is added, unit tests will be sufficient.
Once Nova support is added, Tempest tests should ensure that the interaction
between Nova and Glance works as expected.


Documentation Impact
====================

Instructions for how to use the change will need to be documented.  These
include instructions for the user on how to create keys and signatures
offline before providing this information during the creation of an image.

This documentation will also include descriptions for each of the following
signature metadata properties:

* signature: the signature of the "checksum hash" encoded in base64 format
* signature_hash_method: the hash method used to create the signature
* signature_key_type: the key type used in creating the signature

  - valid values are: "RSA-PSS"

* signature_certificate_uuid: the uuid used to retrieve the certificate from
  castellan
* mask_gen_algorithm: only used for RSA-PSS, defines the mask generation
  algorithm used in the signature generation, optional and defaults to "MGF1"

  - valid values are: "MGF1"

* pss_salt_length: only used for RSA-PSS, defines the salt length used in the
  signature generation, optional and defaults to PSS.MAX_LENGTH


References
==========

cryptography: https://cryptography.io/en/latest/

[1] http://goo.gl/Y3u3lK
[2] https://review.openstack.org/191542
[3] http://git.openstack.org/cgit/openstack/castellan
[4] https://review.openstack.org/#/c/188874/