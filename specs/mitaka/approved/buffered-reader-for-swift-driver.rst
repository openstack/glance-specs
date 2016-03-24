..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================================
Buffered Reader for Swift Driver
==========================================

Include the URL of your launchpad blueprint:
https://blueprints.launchpad.net/glance/+spec/buffered-reader-for-swift-driver

This change proposal introduces a buffering wrapper around image data for use
during image uploads. This wrapper helps improve the reliability of
image uploads by providing the ability to recover from errors occurring during
the upload process. The recovering ability comes from buffering the image
segments before uploading to swift. When an error occurs, Swift client resumes
the upload process from the last successful position determined using 'seek'
and 'tell' operations on the buffered image segment.


Problem description
===================

What is the problem?
Nova uploads image data to glance via a gzip stream. Glance's swift backend
driver reads segments of data from the gzip stream and uploads it to Swift
cluster using the swift client. During this process, if an error occurs while
uploading data to Swift cluster, swift client aborts the upload as it is
incapable of recovering from errors. This eventually triggers the Swift driver
to delete all the data uploaded thus far.

Why is the problem a problem?
Being unable to recover from errors
- Has a direct and negative impact on the reliability of snapshots.
- Leads to wastage of network bandwidth utilized to upload data leading up to
the error

Why is swift client incapable of recovering from errors? Why not improve it
instead?
Swift client is actually equipped to recover from socket errors, 401s, 408s,
rate-limit errors, 5XXs and others. It handles a decent range of errors and
indeed tries to recover from each of the errors in an appropriate way.  When
an error occurs, swift client tries to resume the upload by repositioning the
input source to last successful position by using the reset function [0]. The
reset function itself utilizes the 'seek' and 'tell' operations [1] on the
input source to determine the appropriate position from which the upload shall
be resumed. This approach works really well when swiftclient is working with
a file on disk or any other input source that supports 'seek' and 'tell'
operations. However, in the case of image uploads from nova to glance, the
input source is a data stream, which unfortunately doesn't support the 'seek'
and 'tell' operations. This leads to swift client aborting the upload. So,
providing 'seek' and 'tell' operations on the image data source would help
solve this issue automatically by virtue of swift client's retry mechanism.

Proposed change
===============

Introduce a wrapper around image data, in the shape of a reader class called
BufferedReader, that supports 'seek' and 'tell' operations.

Currently, glance uploads image data to Swift as Dynamic Large Object (DLO),
which holds the data in several smaller objects called segments.
Glance's swift driver uses the swift client to upload each segment
individually to the backend storage. However, before passing on the image
segments to swift client, the swift driver wraps [2] the segments with
ChunkReader class [3], which enables the swift client to upload the image
segment in smaller chunks, usally 64KB in size.

In the proposed approach, instead of wrapping every segment with ChunkReader,
we wrap it with BufferedReader, which buffers the image segment by tee-ing
image data to a temporary file as it's being uploaded to Swift. As the image
segment is available on disk, BufferedReader proxies the 'read', 'seek' and
'tell' operations to the underlying temporary file. The temporary file is
deleted if the image segment is uploaded successfully or when the upload is
aborted after exhausting retries. If the segment fails to upload successfully,
swift client's retry mechanism resumes the upload by repositioning the input
using 'seek' and 'tell' operations that are now available.

We propose to introduce the BufferedReader as a configurable option, while
leaving the default behavior as is. Using this configuration option, the
amount of disk space used for buffering can be regulated as well. If the
allotted space for buffering is full, BufferedReader reverts to default
behavior, i.e. data is uploaded to Swift without being buffered.

Alternatives
------------

- An alternative is to use memory buffering instead of disk buffering. With
  memory buffering, there'll be a substantial increase in the memory footprint,
  which may degrade the API performance. Also, disk is a cheaper resource than
  memory but not necessarily faster.

- A solution is proposed in [4] to solve this problem for 401s specifically.
  This proposal basically works by ensuring the token is not nearing
  expiration. If it is expiring soon, it renews the token. Though this works
  well for 401 in particular, a similar approach may not be possible for other
  errors.


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

Notifications won't be added, modified or deleted.


Other end user impact
---------------------

None

Performance Impact
------------------

With buffering to disk, there is an additional cost involved with writing to
and reading from disk. This may potentially add a performance penalty to image
uploads. However, the bulk of time elapsed for image upload is spent in
transferring data over the network. In comparison, read and write operations
to disk are relatively much quicker. With some thorough testing, the
performance impact of this approach can be studied in further detail.

Other deployer impact
---------------------

As the image data is buffered to disk, there will be more disk utilization on
the API than before. The disk utilization will be equivalent to:
(image segment size * number of simultaneous snapshots)

Deployers need to take the extra disk utilization into account while using
this feature. Additional care should be taken so that this disk utilization
doesn't impact the disk space available for glance cache in any way.

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
    hemanth-makkapati

Other contributors:
    belliott
    jesse-j-cook

Reviewers
---------

Core reviewer(s):
    nikhil-komawar
    stuart-mclaren

Other reviewer(s):
    brian-rosmaita
    mfedosin

Work Items
----------
- Implement BufferedReader class
- Make the reader class configurable and leave the default behavior as-is
- Test on devstack


Dependencies
============

No dependencies as such but [4] is a related effort.

Testing
=======


Documentation Impact
====================

The new configuration option would require documentation.

References
==========

[0] https://github.com/openstack/python-swiftclient/blob/stable/kilo/swiftclient/client.py#L1296-L1297
[1] https://github.com/openstack/python-swiftclient/blob/stable/kilo/swiftclient/client.py#L1376-L1381
[2] https://github.com/openstack/glance_store/blob/master/glance_store/_drivers/swift/store.py#L546-L550
[3] https://github.com/openstack/glance_store/blob/master/glance_store/_drivers/swift/store.py#L928-L942
[4] https://review.openstack.org/#/c/199049/

