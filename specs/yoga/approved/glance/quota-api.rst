..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

================
Glance Quota API
================

https://blueprints.launchpad.net/glance/+spec/quota-api

In the Xena cycle, Glance gained quota support. Through the use of
unified limits, it was possible to implement this without introducing
an API. However, for full functionality and a better user experience,
Glance should expose an API so that users can see their current usage
(and limit) instead of just receiving an error when they go over. This
spec outlines the addition of that API.


Problem description
===================

Glance users can now be limited by quotas set by the operator, but are
unable to see their current usage (and limits) in any way other than
the error message they receive when they go over. An API is required
to expose the limit and usage to the user.


Proposed change
===============

Glance already has an information discovery API, which will be used as
a base for exposing the information: a new route for ``/info/quota``
will be added. Information exposed will include the limit and current
usage for each quota type for the calling user. If a quota is
disabled, then the limit for that element will be exposed as ``-1`` in
accordance with Keystones "unlimited" sentinel notation.

Alternatives
------------

We could continue to have no API.

Data model impact
-----------------

None

REST API impact
---------------

This spec includes a single new endpoint:

**New API**

* List quotas

**Common Response Codes**

* Success: `200 OK`
* Failure: `400 Bad Request` with details
* Forbidden: `403 Forbidden`

**[New API] List quotas**

List all quotas available for the user::

    GET /v2/info/quotas
    {
      "quotas": {
        "image_size_total": {
          "usage": 32,
          "limit": 1024
        },
        "image_staging_total": {
          "usage": 0,
          "limit": 1024
        },
        "image_count_total": {
          "usage": 4,
          "limit": 100
        },
        "image_count_uploading": {
          "usage": 0,
          "limit": 10
        }
      }
    }

Response codes:

* 200 -- Upon authorization and successful request. The response body
  contains the JSON payload with quota information.
* 400 -- Quota information is not available (likely due to
  configuration or backend error)
* 403 -- Permission denied

JSON schema for the response::

     'usage': {
        'type': 'array',
        'items': {
            'type': 'object',
            'additionalProperties': True,
            'validation_data': {
                'type': 'object',
                'additonalProperties': False,
                'properties': {
                    'usage': {'type': 'integer'},
                    'limit': {'type': 'integer'},
                },
            },
        },
    },


Security impact
---------------

The other information discovery APIs do not check any policy, and none
will be added for this new quota API. It is assumed that there is no
reason to disable a user's view of their own usage and limit
information. The former is already visible by listing current
resources and doing the math.

Notifications impact
--------------------

None.

Other end user impact
---------------------

A glanceclient and openstackclient change will be required to expose
this to interactive users.

Performance Impact
------------------

None.

Other deployer impact
---------------------

No impact beyond the requirements for enabling quotas in general.

Developer impact
----------------

None.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  danms

Work Items
----------

* Implement the API with unit/functional tests
* Document the API in api-ref
* Write a tempest test to check the API
* Implement support in OpenstackClient
* Implement support in glanceclient
* Client docs


Dependencies
============

* This will require a bump to an (already-released) new version of
  oslo.limit in order to query the limits without active enforcement.

Testing
=======

Unit and functional tests in Glance. Tempest tests against the
existing quota-enabled jobs.


Documentation Impact
====================

The api-ref will need updating, as well as usage information for the
interactive clients.

References
==========

* https://specs.openstack.org/openstack/glance-specs/specs/xena/approved/glance/glance-unified-quotas.html
