..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=======================================================
Migrate glance-replicator to requests for HTTPS Support
=======================================================


https://blueprints.launchpad.net/glance/+spec/migrate-replicator-to-requests

As operators and users become more security conscious, it is important to
support deployments of Glance served only over HTTPS. In its current state,
``glance-replicator`` uses ``httplib`` and thus does not properly verify
HTTPS connections. This allows for various and very serious attacks to be
performed while the user of ``glance-replicator`` attempts to communicate with
Glance.


Problem description
===================

Many deployments currently support both HTTP and HTTPS connections to Glance's
API. As best practices evolve, it will become more common that Glance and
other OpenStack services are served only over HTTPS with valid X.509
certificates. Currently, if an operator were to deploy Glance and serve it
using only HTTPS, ``glance-replicator`` would still allow for a large range of
attacks by an observer since it does not verify the certificate that the
server provides.

Among other things, the user's connection to Glance could easily be
intercepted by a man-in-the-middle serving a phony certificate who would then
proxy or even alter the data sent over the connection. Since the typical user
of ``glance-replicator`` is an administrator, any service token they have
could then be intercepted and used, which is dangerous given the privileges
associated with an administrator.


Proposed change
===============

This specification proposes that the code using ``httplib`` in
``glance-replicator`` be rewritten to use ``requests``. ``requests`` supports
automatic certificate verification on all HTTPS connections and allows users
to provide custom certificate bundles for self-signed certificates.

Given that an operator may choose to sign their own ceritificates for their
deployment of Glance, this specification also proposes the addition of a
command-line option to ``glance-replicator`` to allow the operator to specify
a custom certificate bundle to use when verifying the certificate.

Alternatives
------------

One alternative to ``requests`` that's already used in other OpenStack
projects is ``httplib2``. This library provides a nearly identical API to
``httplib`` and performs certificate verifcation. The library, however, is
being actively replaced by many of these same projects by ``requests``.
Reducing the number of dependencies that an operator needs to install is also
very favorable.

An alternative to making the user specify their custom certificate bundle is
to provide a ``glance-replicator.conf`` file. This would be an entirely new
file. Adding yet another configuration file may add to confusion as to which
files are necessary when Glance is deployed as a whole.

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

For deployments of Glance being served over HTTPS, this will improve the
security of the user's connection.

Notifications impact
--------------------

None

Other end user impact
---------------------

Users who have not properly configured HTTPS may receive errors. Since
``glance-replicator`` previously did not generate errors, this may be an
unpleasant experience for the user. It is the position of the author of this
specification that an option to insecurely connect to Glance is a poor choice
since the errors will encourage the operators to properly configure Glance to
be served over HTTPS.

Performance Impact
------------------

None

Other deployer impact
---------------------

None

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
  junhongl

Reviewers
---------

Core reviewer(s):
  flaper87
  flwang

Other reviewer(s):
  nikhil-komawar
  kragniz

Work Items
----------

- Refactor ``glance-replicator`` to drop a some of its conventions surrounding
  ``httplib``
- Replace ``httplib`` with ``requests``
- Add option to specify a custom certificate bundle
- Add documentation to ``glance-replicator`` surrounding the new option and
  features


Dependencies
============

None


Testing
=======

``requests-mock`` will be used to write unit tests for ``glance-replicator``
to ensure that proper coverage is achieved.


Documentation Impact
====================

``glance-replicator``'s man page will need to be updated regarding the new
configuration options. We should note the two current ways of setting a custom
certificate:

#. ``requests`` will look for ``REQUESTS_CA_BUNDLE`` and ``CURL_CA_BUNDLE``
   environment variables
#. The new ``glance-replicator`` option.


References
==========

Bugs:

- https://bugs.launchpad.net/glance/+bug/1408940
