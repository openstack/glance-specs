.. _mitaka-priorities:

===========================
Mitaka Project Priorities
===========================

List of priorities (in the form of use cases) the glance development team is
prioritizing in Liberty (in no particular order).

+---------------------------+------------------------+--------------------------+
| Priority                  | Owner(s)               | Specs                    |
+===========================+========================+==========================+
| `DefCore Updates`_        | `Flavio Percoco`_      |                          |
+---------------------------+------------------------+--------------------------+
| `Image Import Refactor`_  | `Brian Rosmaita`_,     |  `image refactor`_       |
|                           | `Stuart Mclaren`_      |                          |
+---------------------------+------------------------+--------------------------+
| `Nova V1 -> V2 Support`_  | `Flavio Percoco`_,     |  `nova.image refactor`_  |
|                           | `Mike Fedosin`_        |                          |
+---------------------------+------------------------+--------------------------+

.. _Brian Rosmaita: https://launchpad.net/~rosmaita
.. _Flavio Percoco: https://launchpad.net/~flaper87
.. _Mike Fedosin: https://launchpad.net/~mfedosin
.. _Stuart Mclaren: https://launchpad.net/~stuart-mclaren
.. _image refactor: https://review.openstack.org/#/c/232371/
.. _nova.image refactor: https://review.openstack.org/#/c/229891/


Priorities without a clear plan
-------------------------------

Here are some things we would like to be a priority, but we are currently
lacking either a clear plan or someone to lead that effort:

* Revisit tempests tests
    * Verify all the required tests for the API v2 exist
    * Tempest's tests are used as a reference by DefCore
    * These tests will prove the interoperability of the API
* Glance trusts
* Pull V3 out of glance-api's process into its own process/endpoint

DefCore Updates
---------------

Establish a communication channel with DefCore so that constant syncs can be had. Interactions with the DefCore team are important, especially when it comes down to our API evolution. We must make sure this becomes a standard practice.

Image Import Refactor
---------------------

Define and implement a consistent, reliable, user-friendly and public capable image import workflow.

The work here is focused on evolving the existing workflows into something that could be standardized and used as a reference by other groups like DefCore.

Nova V1 -> V2 Support
---------------------

Start and complete the support for Glance's v2 in Nova. This will be a joint effort between both communities and it'll be split into several parts. Our tasks for this consist in contributing to Nova and helping them move forward.
