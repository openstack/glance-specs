===========================
Adding a Member to an Image
===========================

.. include:: deprecation-note.inc

We want to authorize a tenant to access a private image. We issue a
``PUT`` request to
``http://glance.example.com/images/1/members/tenant1``. With no body,
this will add the membership to the image, leaving existing memberships
unmodified and defaulting new memberships to have \`can\_share\` set to
\`false\`. We may also optionally attach a body of the following form:

.. code::

    {'member':
     {'can_share': true}
    }

If such a body is provided, both existing and new memberships will have
\`can\_share\` set to the provided value (either \`true\` or \`false\`).
This query will return a 204 ("No Content") status code.

