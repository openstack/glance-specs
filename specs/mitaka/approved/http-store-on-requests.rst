..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================================
  Migrate the HTTP Store to Use Requests
==========================================

https://blueprints.launchpad.net/glance/+spec/http-store-on-requests

Currently, the ``glance_store`` uses ``httplib`` to talk to the backing HTTP
Store. In the case where the the store is served over plain-text (``http://``)
this isn't an issue. In the event that the store is served over TLS
(``https://``) then the connection was not verified by ``httplib``.  In
order to provide verification of the connection on all versions of Python,
``glance_store`` is moving to use Requests.

Problem description
===================

Currently, the ``glance_store`` uses ``httplib`` to talk to the backing HTTP
Store. In the case where the the store is served over plain-text (``http://``)
this isn't an issue. In the event that the store is served over TLS
(``https://``) then the connection was not verified by ``httplib`` [#]_.
If an operator is serving their store over HTTPS, they may be expecting Glance
to verify the connection when downloading the image which is not the case.

At the moment, when Glance downloads an image from the backing store, it does
not verify the checksum. If an attacker can properly position themselves, they
can intercept the connection by providing a fake (a.k.a., spoofed) certificate.
This allows the attacker to essentially perform a denial of service attack by
providing bad image data on the behalf of the store. This assumes that the
service consuming Glance's images validates the checksum provided by Glance in
the ``Content-MD5`` header. (This also assumes the attacker cannot change that
value in the database or before the header reaches the service making the
request.) If an attacker is properly positioned, they can also easily perform
surveillance of the system, even if they choose not to poison the data.

Further, the attacker could monitor Glance long enough to generate a malicious
image with the appropriate checksum (since it is currently MD5 which is
no longer cryptographically secure and is increasingly easy to create a
collision [#]_ [#]_ [#]_).

Proposed change
===============

In order to provide verification of the connection on all versions of Python,
``glance_store`` should use Requests. A refactor has already taken place, but
in order to provide proper backwards compatibility the HTTP Store needs new
configuration options.

Users will need:

- A way to disable HTTPS Verification

  This spec proposes naming that option ``disable_https_verification``.

- A way to provide a certificate bundle for verification

  This spec proposes naming that option ``https_ca_bundle``.

- A way to provide proxy information

  This spec proposes naming that option ``http_proxy_information``.

In order to reduce the impact on upgrades, this spec proposes defaulting the
new ``disable_https_verification`` option to ``True`` with logged warnings
that it will be changing to ``False`` by default in the next cycle. There will
be an accompanying OpenStack Security Note (OSSN) written for this case.

Alternatives
------------

The `Encrypted and Authenticated Image Support`_ specification might seem to
be an alternative but that merely secures the image data, it does not secure
the transport.

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

This will improve the security of the system.

Notifications impact
--------------------

None

Other end user impact
---------------------

If the HTTP Store's certificate expires, users will be unable to download
images.

Performance Impact
------------------

By using sessions in Requests, multiple requests will be faster due to
Requests implementation of connection pooling.

Other deployer impact
---------------------

Deployers using self-signed certificates for their HTTP Store will need to
provide the certificate as part of a bundle to be used by ``glance_store`` for
verification.

Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  icordasc

Other contributors:
  None

Reviewers
---------

Core reviewer(s):
  nikhil-komawar
  flaper87

Other reviewer(s):
  sabari

Work Items
----------

- Re-factor the HTTP Store to use Requests

- Add configuration options and documentation described above

- Write and publish an OSSN

Dependencies
============

None

Testing
=======

Unit tests should be added to the ``glance_store`` library to ensure that
operators can disable verification or provide their own bundle.

Documentation Impact
====================

New configuration options will be added and explained.

References
==========

.. [#] `CVE-2014-9365`_

.. [#] http://www.mathstat.dal.ca/~selinger/md5collision/

.. [#] https://en.wikipedia.org/wiki/MD5#Collision_vulnerabilities

.. [#] https://eprint.iacr.org/2013/170.pdf

.. _CVE-2014-9365:
    https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2014-9365

.. _Encrypted and Authenticated Image Support:
    https://review.openstack.org/177948
