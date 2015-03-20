..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================================
Use keystoneclient Sessions
==========================================

https://blueprints.launchpad.net/python-glanceclient/+spec/session-objects

Keystoneclient sessions are being used as a common base library to standardize
handling of tokens and authentication credentials going beyond a basic username
and password.

This improves security as a single point of update for these issues and means
that additional authentication mechanisms may be added transparently to
individual clients.

Glanceclient should adopt sessions as other clients have.


Problem description
===================

The OpenStack clients all grew rather organically. Each handled their own
authentication and this was copied and pasted between every service. This
results in:

 * inconsistencies with what parameters are accepted between clients.
 * A security issue when bugs are found and need to be patched in each client.
 * Inconsistent use of the service catalog, regions etc.
 * Problems adding new features as they become available in keystone.

Glanceclient is structured differently from the other clients. It is one of the
few that nicely separates the responsibilities of the CLI and the library.
However it does do custom HTTPS handling and other security related fixes that
are not reused amongst other components.

Because of offloading to the CLI it does not handle things like token
refreshing, and puts the onus of operating the service catalog onto the user -
generally other services.

Proposed change
===============

I want to bring glanceclient more inline with other clients. Now that there is
the facilities that things like the service catalog can be managed consistently
by other libraries there is less of an excuse for glanceclient to avoid using
this information.

This will involve creating a different type of HTTPClient in the event that
session and other options are detected. This will allow glanceclient to
continue to operate as it does today unless users opt-in by using new
parameters. These new parameters are managed by the keystoneclient Adapter
object and so will simply involve passing kwargs through.

The CRUD layers of glanceclient and the requests path will be unaffected.

Alternatives
------------

Glanceclient can continue to operate as it does now. This is not as bad as
other clients as it pushes this configuration back on the service, rather than
incorrectly handling options internally. However this makes it a special case
and glanceclient will not benefit from the efforts to standardize
authentication flows and options that the other services gain.

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

This change will reimplement how glanceclient handles authentication, token
management and how you select endpoints. It handles this though by offloading
these concepts to keystoneclient so that any security issues can be handled
there.

It will deprecate the custom HTTPs handling that glanceclient does. It is my
understanding that this custom handling was largely to disable BEAST style
attacks by preventing the client from advertising SSL compression capabilities.
Whilst compatibility will be maintained for the current client it may not be
possible to maintain this functionality when using a common handling logic.

Notifications impact
--------------------

None

Other end user impact
---------------------

None

Performance Impact
------------------

None

Other deployer impact
---------------------

The flow on effect here is that other services that have credentials and
parameters in config files that are used to talk to glance will be standardized
with other services.

Developer impact
----------------

This will change the parameters that are provided when establishing a
glanceclient. The new parameters are standardized across all the other
OpenStack client libraries. Existing parameters will obviously be maintained
and deprecated in time.

This will greatly assist integration with service to service communication as
auth_token middleware is providing an auth plugin that can be used directly, as
well as standardizing the options that are used for all the clients.

Implementation
==============

Assignee(s)
-----------

Who is leading the writing of the code? Or is this a blueprint where you're
throwing it out there to see who picks it up?

If more than one person is working on the implementation, please designate the
primary author and contact.

Primary assignee:
  jamielennox

Other contributors:

Reviewers
---------

I would appreciate anyone who wants to be a point of contact for review.

Core reviewer(s):
  None at this time

Work Items
----------

* There are some initial changes to testing that are required to fit the new
  model. These are considered generally useful and not necessarily specific to
  this review.
* Add session handling and handling of existing parameters to the glanceclient.
* Convert the glanceclient CLI to use the standard parameters and option
  handling. In other projects I have done this for we have not always completed
  this step. Most clients are moving towards the OpenStackClient project for
  CLI and are not worried about significant refactoring of their CLI
  applications.

Dependencies
============

None

Testing
=======

We can unit test these changes. It should also be possible to use a
testscenarios approach such that existing CRUD tests are run with both a
traditionally created client and a client created with a session.

Documentation Impact
====================

Update documentation on how to instantiate a Client.

References
==========

None
