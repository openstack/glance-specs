===============================
Removing a Member from an Image
===============================

We want to revoke a tenant's right to access a private image. We issue a
``DELETE`` request to
``http://glance.openstack.example.org/images/1/members/tenant1``. This query
will return a 204 ("No Content") status code.

