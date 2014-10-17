Delete an Image
---------------

**DELETE /v2/images/<IMAGE\_ID>**

Encode the ID of the image into the request URI. Request body is
ignored.

Images with the 'protected' attribute set to true (boolean) cannot be
deleted and the response will have an HTTP 403 status code. You must
first set the 'protected' attribute to false (boolean) and then perform
the delete.

The response will be empty with an HTTP 204 status code.
