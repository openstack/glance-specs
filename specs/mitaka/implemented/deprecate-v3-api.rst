..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=======================
Deprecate Glance v3 API
=======================

https://blueprints.launchpad.net/glance/+spec/move-v3-to-glare

On Mitaka summit it was decided [1] to make v3 (artifact) API a standalone
service with its own endpoint. To do that we have to deprecate Glance v3 API
and related things, and create new service with all required utilities.

Problem description
===================

Initially it was planned to make artifacts a new API with incremented version,
i.e. "v3". But since Glance is a core project, it falls under the DefCore
specifications, which require (among other things) uniqueness of public APIs.
Unfortunately v3 api is pluggable and it can't be unique by design.

Also there are issues with understanding what Glance API is, because v1 and v2
are Image APIs, and they work with images only. But v3 was considered to be
unified (Artifact) API, which may work with objects of any nature.
The general feeling in the broader OpenStack community is that rather than
being a new version of the Images API, the Artifacts API should be considered
an entirely different thing.

Proposed change
===============

Because v3 API has experimental status, it's proposed to deprecate v3 API and move
all its code to the whole new standalone service with new endpoint. It will
release the Artifacts project from being subject to DefCore requirements and
will allow the project to move forward faster.

Having the independent service also removes misunderstanding, because there will be
stable, DefCore-approved Glance Image API and pluggable independent Artifact API,
which may include Glance API in the future.

Alternatives
------------

It's possible to leave everything as-is, but it doesn't remove all of the above
issues.

Data model impact
-----------------

None. All created for artifacts tables with prefix 'artifacts-' will stay in DB, but
will be used by another service.

REST API impact
---------------

All of experimental APIs, that start with '/v3', are deprecated and will be removed.

Security impact
---------------

None.

Notifications impact
--------------------

None.

Other end user impact
---------------------

Experimental 'feature/artifacts' branch will be removed from 'python-glanceclient'
repo.

Performance Impact
------------------

None.

Other deployer impact
---------------------

'apiv3app' application has to be removed from 'glance-api-paste.ini'

'enable_v3_api' parameter has to be removed from glance-api config

Developer impact
----------------

None.


Implementation
==============

Assignee(s)
-----------

Primary assignee:

  * dshakray

Other contributors:

  * mfedosin

Reviewers
---------

* flaper87

* nikhil-komawar

* ativelkov

Work Items
----------

* glance-api-paste.ini: remove 'apiv3app' application;

* glance/common/config.py: remove 'enable_v3_api' parameter;

* glance/api/middleware/version_negotiation.py: remove major version discoverability,
  if version is 3, raise ValueError instead;

* move glance/api/v3/* code into glance/artifacts/api;

* make related changes in the tests;

Dependencies
============

None.

Testing
=======

None.

Documentation Impact
====================

None.


References
==========

[1] Mitaka glance artifacts review: https://etherpad.openstack.org/p/mitaka-glance-artifacts-review
