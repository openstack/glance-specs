=========================
Image service v1 REST API
=========================

.. include:: deprecation-note.inc

The OpenStack Image service offers retrieval, storage, and metadata
assignment for your images that you want to run in your OpenStack cloud.
The project is code-named Glance.

OpenStack Image service enables users to store and retrieve images
through a simple Web Service (ReST: Representational State Transfer)
interface.

For more details on the OpenStack Image service, please refer to
`docs.openstack.org/developer/glance/ <http://docs.openstack.org/developer/glance/>`__

We welcome feedback, comments, and bug reports at
`bugs.launchpad.net/glance <http://bugs.launchpad.net/glance>`__.

Intended Audience
-----------------

This guide is intended to assist software developers who want to develop
applications using the OpenStack Image Service API. It fully documents
the ReST application programming interface (API) that allows developers
to interact with the storage components of the OpenStack Image system.
To use the information provided here, you should first have a general
understanding of the OpenStack Image Service and have access to an
installation of OpenStack Image Service. You should also be familiar
with:

-  ReSTful web services

-  HTTP/1.1

Glance has a RESTful API that exposes both metadata about registered
virtual machine images and the image data itself.

A host that runs the ``bin/glance-api`` service is said to be a *Glance
API Server*.

Assume there is a Glance API server running at the URL
``http://glance.example.com``.

Let's walk through how a user might request information from this
server.

Requesting a List of Public VM Images
-------------------------------------

We want to see a list of available virtual machine images that the
Glance server knows about.

We issue a ``GET`` request to ``http://glance.example.com/images/`` to
retrieve this list of available *public* images. The data is returned as
a JSON-encoded mapping in the following format:

.. code::

    {'images': [
      {'status: 'active',
       'name': 'Ubuntu 10.04 Plain',
       'disk_format': 'vhd',
       'container_format': 'ovf',
       'size': '5368709120'}
      ...]}

All images returned from the above `GET` request are public images
