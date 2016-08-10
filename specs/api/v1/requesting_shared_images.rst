========================
Requesting Shared Images
========================

We want to see a list of images which are shared with a given tenant. We
issue a ``GET`` request to
``http://glance.openstack.example.org/shared-images/tenant1``. We will get back
JSON data such as the following:

.. code::

    {'shared_images': [
     {'image_id': 1,
      'can_share': false}
     ...]}

The \`image\_id\` field identifies an image shared with the tenant named
by *member\_id*. If the tenant is authorized to further share the image,
the \`can\_share\` field is \`true\`.

