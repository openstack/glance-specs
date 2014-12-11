Image API Binary Data API calls
===============================

Binary Data API
===============

The following API calls are used to upload and download raw image data.
For image metadata, see `Metadata API <#metadata-api>`__.

Upload Image File
-----------------

**PUT /v2/images/<IMAGE\_ID>/file**

NOTE: An image record must exist before a client can store binary image
data with it.

Request Content-Type must be 'application/octet-stream'. Complete
contents of request body will be stored and become accessible in its
entirety by issuing a GET request to the same URI.

Response status will be 204.

Download Image File
-------------------

**GET /v2/images/<IMAGE\_ID>/file**

Request body ignored.

Response body will be the raw binary data that represents the actual
virtual disk. The Content-Type header will be
'application/octet-stream'.

The `Content-MD5 <http://www.ietf.org/rfc/rfc1864.txt>`__ header will
contain an MD5 checksum of the image data. Clients are encouraged to
verify the integrity of the image data they receive using this checksum.

If no image data has been stored, an HTTP status of 204 is returned.

