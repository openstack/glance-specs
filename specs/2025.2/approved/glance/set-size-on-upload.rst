..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================================
Make provision to set image size on upload
==========================================

https://blueprints.launchpad.net/glance/+spec/set-size-on-upload

Historically, the python-glanceclient included the option to specify a
``--size`` parameter for the image-upload and image-stage commands. However,
this feature is currently unused and is retained in the codebase solely
for backward compatibility. Even if a user provides this option when
executing the aforementioned commands, it is not forwarded to the Glance API.


Problem description
===================

As the python-glanceclient uploads image data without requiring a prior
specification of the image size, it functions as intended. However, this can
lead to complications when Glance utilizes Cinder, RBD, or S3 as its backend.
Since Glance does not have the data size beforehand, it conducts an iterative
"resize-before-write" process, gradually expanding the Cinder volume by 1
GB at a time until all image data is received. This approach poses a challenge
because the Cinder volume needs to be detached and reattached during each
iteration, which can significantly slow down the process.

The same issue arises when using Ceph (RBD) as the backend, where a
similar "resize-before-write" operation occurs, resulting in time-consuming
operations.

If Glance is configured to use S3 as a backend, the multipart upload feature
cannot be utilized because the image size is unknown in advance.


Proposed change
===============

We propose to enable the use of the ``--size`` option for the image-upload and
image-stage commands, as well as to add this option to the image-create
command. The image size will be calculated automatically if a file-like object
is detected during the upload or staging operations. Otherwise, users can
specify the image size via the ``--size`` command-line option. If the
``--size`` option is provided, we will not calculate the image size internally,
and the user-specified size will be sent directly to the Glance API. We will
introduce a new request header ``x-openstack-image-size`` which will be
passed to API.

On the API side, we will read the size passed from glanceclient or any
request source via header ``x-openstack-image-size`` and pass it to the
designated storage backend. This approach will help prevent resize-on-write
operations for Cinder and RBD backends and enable the use of the multipart
upload feature for the S3 backend. Each backend of glance_store will
verify the size during the data pipeline whether the total data size
exceeds the user-specified limit. If the size exceeds the allowed limit,
the upload will be rejected, the data will be removed from the backend,
and an appropriate error message will be returned to the user. Additionally,
at the end of the process, we will compare the actual image size to the
size provided by the user. If there is any mismatch in actual and expected
size, the data will be deleted from the backend, the upload rejected, and
a warning will be logged, consistent with existing checks for image disk
format and hash.

If the image size is not included in the request header, we will have no option
but to allow the storage backends to perform resize-on-write operations or
to utilize the single-part upload feature for the S3 backend.

For asynchronous operations (import APIs), such as the glance-direct and
web-download import methods, we already gather data in a local staging area
before transferring it to the backend. We will ensure that the image size is
set before starting the import operation to avoid these resize operations.

Alternatives
------------

The Python Requests library also facilitates streaming uploads by sending
data in chunks with a "Content-Length: <file size>" header, rather than
using "Transfer-Encoding: chunked." This approach avoids chunked transfer,
which we should steer clear of, as it is a more stable method for long
transfers. Since the development of the glanceclient library is currently
at a standstill, we should avoid introducing changes that could lead to
instability.

Data model impact
-----------------

None

REST API impact
---------------

The PUT /v2/images/{image_id}/file and PUT /v2/images/{image_id}/stage
APIs will be modified to recognize the ``x-openstack-image-size`` header.

HTTP 400 response will be returned if user provided size does not matches
with actual image size.

Security impact
---------------

None

Notifications impact
--------------------

None

Other end user impact
---------------------

The end user can provide the image size in advance if they are aware of it.

Performance Impact
------------------

This will improve the upload/import process for cinder, ceph (rbd) and s3 backend
of glance.

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
  abhishekk

Other contributors:
  abhishekk

Work Items
----------

* Add command line option ``--size`` to image-create command
* Calculate file size if file like object is provided
* Make sure upload and stage commands passes size to API as request header
* Make similar provision in openstack client and sdk
* At Glance side read the size form request header and pass it to backend
* Then compare provided size with actual size
* Make sure image size is set before import operation starts
* Required functional, unit and tempest tests
* Document new behavior


Dependencies
============

* https://bugs.launchpad.net/glance-store/+bug/2110185


Testing
=======

* Required unit, functional and tempest tests


Documentation Impact
====================

Document the use of ``--size`` command line option and new request header
``x-openstack-image-size`` at glance side


References
==========

* https://requests.readthedocs.io/en/latest/user/advanced/#chunk-encoded-requests
* https://requests.readthedocs.io/en/latest/user/advanced/#streaming-uploads

