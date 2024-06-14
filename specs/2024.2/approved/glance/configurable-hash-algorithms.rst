..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=================================
User-configurable hash algorithms
=================================

Include the URL of your launchpad blueprint:

https://blueprints.launchpad.net/glance/+spec/configurable-hash-algorithms

Allow end-users to specify a hash algorithm to be used when creating a new
image, allowing them to compare existing hashes provided by the creator of the
image with hashes returned by Glance, rather than having to generate the hashes
themselves on the client side.

Problem description
===================

As described `in the docs
<https://docs.openstack.org/glance/latest/user/os_hash_algo.html>`__, the
Secure Hash Algorithm feature adds image properties that may be used to verify
image integrity based on its hash. Two properties are added, ``os_hash_algo``
which contains the name of the hash algorithm used to generate the hash, and
``os_hash_value`` which contains the hash itself.

We would like to be able to use ``web-download`` to upload an image
to Glance - be that an OpenShift release images or a stock CentOS Stream or
Ubuntu image - and then verify the hash of the uploaded image against a
signature given by the image provider. However, currently the hash algorithm
represented by ``os_hash_algo`` is not user-configurable: it can only be
configured by the ``[DEFAULT] hashing_algorithm`` configuration option. This
defaults to ``sha512``, which was chosen as it was more performant than SHA-256
(see :doc:`/specs/rocky/implemented/glance/multihash`), but SHA-512 signatures
are not published by all image providers: for example, while Debian publishes
SHA-512 signatures (`source
<https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/>`__), Ubuntu only
publishes SHA-256 signatures (`source <https://releases.ubuntu.com/24.04/>`__)
as does Fedora (`source
<https://fedora.ip-connect.vn.ua/linux/releases/40/Workstation/x86_64/iso/>`__).
When signatures are not provided in a suitable format, it is necessary to
either ask an admin to change the hash algorithm (which affects the entire
deployment and might not be possible, particularly in public cloud
environments) or generate the hash on the client-side before uploading the
image (which limits the usefulness of the ``web-download`` image import
mechanism). We would like to address this gap.

Proposed change
===============

To resolve this, we propose allowing users to select the hash algorithm to be
used when creating the image. We will rename the ``[DEFAULT]
hashing_algorithm`` config option to ``[DEFAULT] default_hashing_algorithm``
(providing an alias for the older name) and add a new config option,
``[DEFAULT] allowed_hashing_algorithms``, which will be a list of algorithms
that are permitted to specified by the user and will initially default to
``['sha512', 'sha256', 'sha1', 'md5']``. In this way, users can select a
hashing algorithm that suits their use case while operators can still restrict
certain algorithms to e.g. maintain regulatory compliance.

Alternatives
------------

- Instead of allowing users to specify the hash algorithm to be used, we could
  start storing multiple hash algorithms. This would require replacing the two
  image properties, ``os_hash_algo`` and ``os_hash_value`` with either a new
  map-like property or flat algorithm-specific properties (e.g.
  ``os_hash_value.sha512``).

  This was rejected because it has a far larger API impact, would require
  database changes, and would increase CPU utilisation due to the need to
  generate multiple hashes for every image.

- Instead on introducing a new configuration option, we could modify the
  behavior of the existing ``[DEFAULT] hashing_algorithm`` option such
  that it now accepts a list of allowed hashing algorithms, with the first item
  (index 0) being the default used.

  This was rejected because it overloads the option to have two purposes - both
  configuring a default and configuring allowed options - which could be
  confusing for operators. In addition, any deployments that have non-default
  values (e.g. ``sha256``) will have those values persisted and the value will
  now affect both default and allowed hashing algorithms, which may be
  undesirable from an operator perspective yet easy to miss.

Data model impact
-----------------

None.

REST API impact
---------------

The ``POST /images`` API will now allow users to specify the ``os_hash_algo``
property during image creation. If a user specifies an unsupported algorithm,
the request will be rejected with a HTTP 400 (Bad Request) error and
appropriate error message.

Security impact
---------------

There are a number of potential issues with these but we believe none of them
are actual issues.

- A malicious user could rely on a hash collision with a (significantly) weaker
  or insecure algorithm to trick users into believing they are downloading e.g.
  an official Ubuntu image when in fact they are downloading a weaker image.

  Using this would require that the malicious user has the ability to create
  public or community images, or they would require the potential victim to
  accept a share request for a shared image. This is unlikely in a public cloud
  environment. In addition, and perhaps more importantly, a hash collision
  attack using SHA-256 or SHA-512 has not been publicly demonstrated. This is
  obviously not the case for SHA1 and MD5 but as both algorithms' lack of
  security is well documented and well known, there should be no expectation of
  security from end-users.

- A malicious user could conduct a denial-of-service attack on Glance by
  uploading images using an expensive hashing algorithm.

  The set of hashing algorithms that a user can specify will be
  operator-configurable, meaning only well-known, well-understood algorithms
  will be permitted by default. In addition, such a hashing algorithm would
  have to be **astoundingly** expensive to make a dent in the existing overhead
  costs of downloading and storing a glance image. We are not aware of any such
  hash algorithms in practical use.

- Use of a particular algorithm could cause the operator to run afoul of
  regulatory requirements.

  The supported hashing algorithms will be operator-configurable. The operator
  can merely disable those that are not permitted due to e.g. FIPS compliance
  requirements.

Notifications impact
--------------------

None.

Other end user impact
---------------------

This field is already supported by openstacksdk but is currently silently
ignored. This will no longer be the case. Put another way, this will now work:

.. code-block:: python

    import openstack

    conn = openstack.connect()
    openstack.enable_logging(debug=True)

    image = conn.image.create_image(
        'foobar',
        os_hash_algo='sha256',
    )
    print(image)

Or, using OpenStackClient (OSC):

.. code-block:: shell

    openstack image create --property os_hash_algo=sha256 foobar

We may wish to add a new helper alias to the ``image create`` command in
OpenStackClient, to allow users to specify this well-known alias easily but
this is a nice-to-have.

Performance Impact
------------------

None.

Other deployer impact
---------------------

Deployers will now have the ability to configure the hashing algorithms that
users can use when creating image. While this will default to a sensible set of
default algorithms, they may wish to tweak this further to meet regulatory or
organisational requirements.

Developer impact
----------------

None.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  stephen.finucane

Other contributors:
  None

Work Items
----------

- Add the new configuration option
- Add necessary API logic to allow the user to specify this option during image
  creation and respect it during image upload.
- Update documentation

Dependencies
============

None.

Testing
=======

Unit test and manual testing should suffice here, though we can also test this
via a new Tempest test.

Documentation Impact
====================

We will need to update the API documentation along with the Secure Hash
Algorithm feature documentation.

References
==========

None.
