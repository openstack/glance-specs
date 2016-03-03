..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=====================================
Glance Image Signing and Verification
=====================================

https://blueprints.launchpad.net/glance/+spec/image-signing-and-verification-support

Before Liberty, OpenStack did not support the following feature:

* Signature validation of uploaded signed images

Deploying authentication protects image integrity by verifying that an
image has not been modified after the upload by the user.  This feature
improves the enterprise-ready posture of OpenStack.

Although an initial implementation was merged into Glance for the Liberty
release, adding functionality for this feature to Nova requires modifications
to this implementation [1].


Problem description
===================

Before Liberty, there was no method for users to verify that a previously
uploaded image had not been modified.  An image could potentially be modified
in transit (such as when it is uploaded to Glance or transferred to Nova) or
Glance itself could be untrusted and modify images without a user's knowledge.
An image that is modified could include malicious code.  Providing support for
image signatures and signature verification would allow the user to verify
that an image has not been modified prior to booting the image.

There are several use cases that this feature supports:

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

For the initial implementation in Liberty, this change used the property
feature of Glance to store the metadata items needed for image signing and
verification. These include a public key certificate reference, and the
signature.  These are provided when the image is created, and are accessible
when the image is uploaded.  Note that the feature only supports image uploads
with the Glance API v2 (and does not support using the Glance API v1).  Also
note that multiple formats for the key (such as SubjectPublicKeyInfo) and for
the signature (such as PSS) are supported.  The format of the signature is
stored as one of the properties.

The certificate reference is used to access the certificate from a key
manager, where the certificate is stored.  This certificate is added to
the key manager by the end user before uploading the image.  Note that the
signature is done offline.

Glance supports computing a checksum of an image when an image is uploaded,
and this checksum is stored with the image.  In the Liberty implementation,
this same hash (which is hardcoded to be MD5) was used for the signature
verification.   The checksum hash is computed in glance_store (when the image
data is uploaded), and is then used to verify the signature in Liberty.  The
Glance frontend uses the reference to the public key certificate to retrieve
the certificate from the key manager, and then uses this public key along with
the signature, the computed checksum, and the rest of the signature metadata
to verify the signature.  If the signature verification fails, the image is
transition to a killed state, and the user is notified that the upload failed
and given a reason why.

However, in Mitaka, this approach will be modified to instead validate a
signature of the image data, rather than validating an image signature of a
hash of the image data.  To explain this further, consider the following two
options using 'RSA-PSS' as the signature type, and 'SHA-256' as the signature
hash method:

1. A signature of the Glance checksum of the image data (hardcoded to MD5)

signature = RSA-PSS(SHA-256(MD5(IMAGE-CONTENT)))

2. A signature of the image data directly

signature = RSA-PSS(SHA-256(IMAGE-CONTENT))

The first approach ('sign-the-hash') was implemented in Liberty, but the
second approach ('sign-the-data') will be used instead in Mitaka.  Although
the sign-the-hash approach will still be supported in Mitaka, it will be
deprecated, and removed in a later release.  Note that, as seen above, the
'sign-the-data' approach still involves creating a hash of the image. However,
this is done as part of the signature verification process, and is internal to
the signature verifier.  This is in contrast to the 'sign-the-hash' approach,
where the verifier does a hash of the hash of the image data as part of the
verification process.

To support the 'sign-the-data' approach, a few modifications will have to be
made. Currently, the 'checksum' is computed in each of the
glance_store/_drivers/\*.py 'add' methods.  When 'checksum.update()' is called
for the image data chunk, this data chunk will also be passed to a
signature_utils module (through an optional callback method), provided that
the necessary signature properties are present.  These data chunks will then
be used to update the signature verifier, and when the image data is done
being read the verifier will be finalized and the verification will occur.  As
in Liberty, if the signature verification fails, the image is transition to a
killed state, and the user is notified that the upload failed and given a
reason why.

Alternatives
------------

An alternative to replacing the sign-the-hash approach with the sign-the-data
approach would be to leave the Liberty implementation as-is.  However, there
has been pushback from the Nova community with this approach [2], since it
requires initially using MD5 (which is not cryptographically secure) as the
basis, and then querying Glance for the hash method used, assuming the hash
was made configurable. In the interest of using an implementation that is
accepted by both Glance and Nova, as well as removing any attachment to MD5,
it is necessary to modify the initial approach.

An alternative to the sign-the-data approach is to create a
separate configurable hash for use with verifying/creating the signature.
However, creating a separate hash is no different performance-wise to signing
the image data directly, since part of the signature verification process is
computing a hash of the image for use with verification.  Also, the use of
this separate hash, though stronger than MD5, would be limited, since having
a signature makes the need for a hash obsolete.

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
Glance properties, and returning an error message if verification fails.

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
is the maximum size supported for Glance properties.  In turn, this limits
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
associated with retrieving the certificate from the key manager.  Also, as a
part of the signature verification or creation, a hash of the image data
is computed by the 'verifier' or 'signer' which will have a small impact
on performance.

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
  nikhil_k

Other reviewer(s):
  joel-coffman

Work Items
----------

The feature will be tackled in the following stages:

1. Add signature verification on upload to verify a signature of
   the image data directly, rather than a signature of the MD5 hash of the
   image data, when the new signature metadata property names are present.
2. Add a log entry to mark the sign-the-hash verification path as deprecated
   in Mitaka, when the old signature metadata property names are present.
3. Remove the sign-the-hash verification steps in the release after Mitaka.


Dependencies
============

In order to take advantage of the signatures in Glance, Nova will need to
be updated to retrieve the signatures from Glance and verify them.  However,
Glance does not depend on Nova to have this support in order to have the
feature added.  The spec for this in Nova [2] has been approved.


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
signature metadata properties (note that "img\_" has been included at Nova's
request):

* img_signature: the signature of the "checksum hash" encoded in base64 format
* img_signature_hash_method: the hash method used to create the signature
* img_signature_key_type: the key type used in creating the signature

  - valid values are: "RSA-PSS"

* img_signature_certificate_uuid: the uuid used to retrieve the certificate
  from castellan


References
==========

cryptography: https://cryptography.io/en/latest/

[1] http://bit.ly/1Q0M0C7

[2] https://review.openstack.org/#/c/188874/

[3] http://git.openstack.org/cgit/openstack/castellan