============================
Requesting Image Memberships
============================

We want to see a list of the other system tenants (or users, if
"owner\_is\_tenant" is False) that may access a given virtual machine
image that the Glance server knows about. We take the \`uri\` field of
the image data, append ``/members`` to it, and issue a ``GET`` request
on the resulting URL.

Continuing from the example above, in order to get the memberships for
the first public image returned, we can issue a ``GET`` request to the
Glance server for ``http://glance.example.com/images/1/members``. What
we will get back is JSON data such as the following:

.. code::

    {'members': [
     {'member_id': 'tenant1',
      'can_share': false}
     ...]}

The \`member\_id\` field identifies a tenant with which the image is
shared. If that tenant is authorized to further share the image, the
\`can\_share\` field is \`true\`.

