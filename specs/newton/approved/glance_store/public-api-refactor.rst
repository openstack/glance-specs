..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==================================
Public glance_store's API refactor
==================================

Include the URL of your launchpad blueprint:

https://blueprints.launchpad.net/glance_store/+spec/public-api-refactor

The glance_store library was pulled out of Glance some cycles ago. In the
process, the code was not changed at all and the refactor of such code was put
on-hold for future cycles as the main goal was to have a working library as soon
as possible.

The above forced the Glance team to ship a library with an API that was never
meant to be public, hence the adoption of the library in other projects has been
advised against.


Problem description
===================

The glance_store public API is based on functions with inconsistent signatures,
which may or may not behave the same depending on the passed arguments.

These set of functions worked well when the library was part of Glance but they
don't anymore. Just to name a few examples:

* There are multiple ways to store data: `add_to_backend` and
  `store_add_to_backend`
* Each store needs to implement a `StoreLocation` class
* It's possible to get a store class from a scheme (`get_store_from_scheme`), an
  URI (`get_store_from_uri`) or well, from a location (*shrugs*)
  (`get_store_from_location`)

The above might not strike as critical issues but they do cause a bad experience
for consumers of this library.


Proposed change
===============

The proposal is to refactor this API and provide a more consistent, backwards
compatible and clean API. The proposed change is to have a single class capable
of doing what the current set of functions do following some of the principles
in the current API:

* It *must* be stateless
* It *must* be capable of storing, reading and deleting data from the store.

Some functions are going to be entirely deprecated as part of this change:

* `verify_default_store` Users should not need this function and it should've
  never been public to begin with.

* `get_store_from_(scheme|uri|location)` Users shouldn't need to access the
  store driver at all. These 2 functions should've never been public to begin
  with.


The existing functions are going to be marked as deprecated and they'll be
refactored to use the new class instead. This will help us testing the behavior
of the new implementation and it'll verify we're not breaking backwards
compatibility. For example, functions like `get_from_backend` will use the new
class but the tests for this function won't be changed during the Newton release.

It's important to note that this spec doesn't propose changing *any* of the
driver's code. It'll focus on the **public** API. Future enhancements of
glance_store will take care of the internal API's like driver's.

Alternatives
------------

* Rewrite the whole library at once. We've attempted to do this and we've never
  gotten past the spec step.

* Do nothing. This would leave us with a library that exposes unnecessary
  functionality and provides a bad experience for users.


Security impact
---------------

N/A... I mean, none that I'm aware of besides the usual stuff ("don't mess this
up")

Other deployer impact
---------------------

N/A

Developer impact
----------------

It'll make devs happy/happier.


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  Flavio Percoco (flaper87)

Other contributors:
  Anyone? Pretty please?

Reviewers
---------

Core reviewer(s):
  Anyone? Pretty please?

Other reviewer(s):

Work Items
----------

* Write the new class and tests for it
* Rewrite the existing functions
* Mark the functions to remove in the Q release as deprecated

Dependencies
============

N/A

Testing
=======

Existing tests won't be changed. New tests will be written and we'll rely on
Glance's gate to ensure backwards compatibility until we improve our gate story
in glance_store.


Documentation Impact
====================

Docs will be written for this new class

References
==========

N/A
