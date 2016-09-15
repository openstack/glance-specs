===============================
Removing a Member from an Image
===============================

.. include:: deprecation-note.inc

We want to revoke a tenant's right to access a private image. We issue a
``DELETE`` request to
``http://glance.example.com/images/1/members/tenant1``. This query will
return a 204 ("No Content") status code.

