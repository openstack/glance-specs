..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==============================================
Swift Multi-tenant Store Service Token Support
==============================================

This is a proposal for how Composite Tokens (aka Service Tokens) can be
used by Glance to improve the Swift Multi-Tenant store.

Specifically, to:

* Guarantee consistency between the Glance database and the Swift store.
  (For example remove the ability for users to delete image objects
  without Glance knowing.)
* Store images separately from users' regular Swift data, preventing
  noise in their account, and more clearly abstracting the Glance API.
* Ensure policy enforcement
* Remove the potential for namespace collisions

Blueprint:
 https://blueprints.launchpad.net/glance/+spec/swift-multi-tenant-store-service-token-support


Problem description
===================

Glance uses Swift to store data on behalf of users.

There are two approaches to how the data is stored:

* *Single-tenant*. Objects are stored in a single dedicated Swift account
  (i.e., all data belonging to all users is stored in the same account).

* *Multi-tenant*. Objects are stored in the end-user's Swift account (project).
  Typically, dedicated container(s) are created to hold the objects.

There are advantages and limitations with both approaches as described in the
following table:

==== ==========================================  ==========    ========
Item Feature/Topic                               Single-       Multi-
                                                 Tenant        Tenant
---- ------------------------------------------  ----------    --------
1    Fragile to password leak (CVE-2013-1840)    Yes           No
2    Fragile to token leak (*)                   Yes           No
3    Fragile to container deletion               Yes           No
4    Fragile to service user deletion            Yes           No
5    "Noise" in Swift account                    No            Yes
6    Namespace collisions (user and service      No            Yes
     picking same name)
7    Guarantee of consistency (Glance            Yes           No
     database vs swift account) ($), (+)
8    Policy enforcement (e.g., Image Download)   Yes           No
9    Fair Swift rate limiting (users unaffected
     by others' Swift use)                       No            Yes
==== ==========================================  ==========    ========

(*) "Fragile" here means that a single leaked token could be used to
    access all users' image data.
($) Users can delete objects which underpin images in the multi-tenant
    case.
(+) If delayed delete is enabled it's not clear that the multi-tenant
    case will 'scrub' properly. This is not being considered as part
    of this spec.


Proposed change
===============

Optionally require a Service Token when accessing image data stored in a
multi-tenant Swift store.

This proposal uses the "Service Token Composite Authorization" support in
the Keystone middleware [1]_.

This proposal also uses the Swift support for multiple reseller prefixes
which allow storing objects in project-specific accounts while retaining
control over how those objects are accessed via Composite Tokens [2]_.

The changes will apply to all accesses to the Swift backend (upload,
download etc).

Example: Existing Image Download::

    +----------------+
    |      User      |
    +-------+--------+
            |
            | 1. Get Glance Image 123
            |
            | GET http://glance:9292/v2/images/123/file
            | X-AUTH-TOKEN: <token for user project 'abc'>
            |
    +-------v---------+
    |     Glance      |
    +-------+---------+
            |
            | 2. Get Swift Object Data
            |
            | GET http://swift:8080/v1/AUTH_abc/glance_123/123
            | X-AUTH-TOKEN: <token for user project 'abc'>
            |
    +-------v---------+
    |      Swift      |
    +-----------------+


The proposed access model has two changes:

* Rather than using the standard ``AUTH_`` Swift reseller prefix a specialized
  prefix, eg ``IMAGE_`` will be used.
* A service token will be generated and supplied with the Swift request

Example: Proposed Image Download::

    +----------------+
    |      User      |
    +-------+--------+
            |
            | 1. Get Glance Image 456
            |
            | GET http://glance:9292/v2/images/456/file
            | X-AUTH-TOKEN: <token for user project 'abc'>
            |
    +-------v---------+
    |     Glance      |
    +-------+---------+
            |
            | 2. Get Swift Object Data
            |
            | GET http://swift:8080/v1/IMAGE_abc/glance_456/456
            | X-AUTH-TOKEN: <token for user project 'abc'>
            | X-SERVICE-TOKEN: <token for Glance service project>
            |
    +-------v---------+
    |      Swift      |
    +-----------------+


The service token will be generated much as a token for the single-tenant
Swift store is today, ie credentials will be stored as part of Glance's
configuration. Unlike the single-tenant store credentials, if the
multi-tenant service account credentials leak they will not give direct
access to all images.

The combination of the user and service token will allow access for for
project ``abc`` under the ``IMAGE_`` reseller prefix. Specifically, Swift
will verify that the service token contains the particular role required
to access the relevant reseller prefix. (For more detailed information
see the relevant Swift spec [2]_).

The Swift reseller prefix can be operator defined, and will be part of
both the Swift and Glance configuration.

Requests to Swift for the ``IMAGE_`` prefix which do not contain a suitably
scoped service token will return HTTP Forbidden (403).

Existing non-service token behaviour will continue to be supported.

Service token generation will not be tied to a particular project. There
is no reliance on a particular project. If the project is deleted a new
project with the same role can be created and used to generate the service
token.

A rolling password change of the service project can be performed by
using either two separate projects or two users in the same project.

If an operator modifies their configuration to take advantage of the new
behaviour pre-existing images — images stored under the old reseller prefix
``AUTH_`` — will continue to be accessible. The service token will
still be supplied to Swift, but it will be ignored.

Example: Image Download, backwards compatibility::

    +----------------+
    |      User      |
    +-------+--------+
            |
            | 1. Get Glance Image 123
            |
            | GET http://glance:9292/v2/images/123/file
            | X-AUTH-TOKEN: <token for user project 'abc'>
            |
    +-------v---------+
    |     Glance      |
    +-------+---------+
            |
            | 2. Get Swift Object Data
            |
            | GET http://swift:8080/v1/AUTH_abc/glance_123/123
            | X-AUTH-TOKEN: <token for user project 'abc'>
            | X-SERVICE-TOKEN: <token for Glance service project>
            |
    +-------v---------+
    |      Swift      |
    +-----------------+


Alternatives
------------

Two Swift installations could be used to give similar behaviour by firewalling
user access to one Swift. That would incur a lot of hardware and operator overhead.

Data model impact
-----------------

There is no impact on the data model per se.

(New image 'location' entries will be slightly different, as they will contain
a different Swift path.)


REST API impact
---------------

None.



Security impact
---------------

This change enhances security by preventing direct access to image
data via Swift. This removes the ability to bypass, for example, the image
download policy for public images, shared images, and user owned images.


Notifications impact
--------------------

None


Other end user impact
---------------------

New image objects will not be listed in users' Swift accounts.


Performance Impact
------------------

A service token will need to be requested by the Glance API process when
Swift data is accessed.  This should have minimal impact.  The token
can be cached so will only impact a minority of requests which access
Swift. Requests which do not access Swift (eg listing images) will not
require a service token.

There may be more cases of tokens expiring (and hitting uploads/downloads)
as both the user token and the service token can potentially expire.
There are some current efforts around mitigating token expiration. It
may be possible to re-use some of those efforts for the service token.

Other deployer impact
---------------------

Operators will need to create a service project and modify their Swift
and Glance configurations if they wish to take advantage of the new
behaviour. (Unmodified configurations will work as before.)

Pre-existing images will continue to be accessible.


Developer impact
----------------

We may propose some changes to python-swiftclient.


Implementation
==============

Assignee(s)
-----------

Primary assignee: Stuart McLaren


Reviewers
---------

Core reviewer(s): Flavio Percoco, Nikhil Komawar

Other reviewer(s): TBD

Work Items
----------

 * Handle new configuration (Service credentials, Swift reseller prefix)
 * Token generation/caching
 * Any swift client changes
 * Test rolling password change

Dependencies
============

Keystone changes to introduce the concept of Service Tokens have been implemented [1]_

Swift changes to introduce support for Service Tokens/multiple reseller prefixes have been implemented [2]_

Required Swift client changes have been implemented [3]_

Testing
=======

Ideally this would become the default configuration for Glance tests in
Tempest, and also the default configuration for devstack.


Documentation Impact
====================

* Example policy files will need to be created that show how to use the new
  data provided from ``X-SERVICE-TOKEN`` when making policy enforcement
  decisions.

* Update the Glance configuration docs


References
==========

.. [1] http://git.openstack.org/cgit/openstack/keystone-specs/tree/specs/keystonemiddleware/implemented/service-tokens.rst
.. [2] http://git.openstack.org/cgit/openstack/swift-specs/tree/specs/done/service_token.rst
.. [3] https://review.openstack.org/#/c/182640
