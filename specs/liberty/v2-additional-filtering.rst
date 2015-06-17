..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

================================================
Add created and updated time filtering to v2 API
================================================

https://blueprints.launchpad.net/glance/+spec/v2-additional-filtering

This spec introduces a feature to the Glance v2 API for filtering image lists
based on when they were created or last updated using a comparative operators.

The introduction of this feature is important because it provides a migration
path for consumers of the Glance v1 API who depend on changes-since filtering
to begin consuming the v2 API instead.

Problem description
===================

From the v2 API list images spec protected properties such as ``created_at``
and ``updated_at`` are not identified as available for comparison operator
filtering the way ``size_min`` and ``size_max`` effectively are. [1]_

The ``created_at`` and ``updated_at`` fields are not indexed resulting in
full-table scans in the database when the default sort [2]_ on image lists is
used or the changes-since filter from v1 is used.

Further, v2 does not support the changes-since filter which was available in
v1 [3]_. This creates a situation where functionality available in the v1 API
is not available in the v2 API and this limits operators and users ability to
usefully filter images.

To promote the adoption of the Glance v2 API providing feature parity would be
helpful. As a complete replacement for the v1 API becomes available so too
does the option to begin deprecation of the v1 API. To advance both of these
ends, feature parity is important.

Proposed change
===============

Two new filters are proposed to be added for the image list endpoint of the
v2 API: the ``created_at`` and ``updated_at`` times for images.

With the proposed feature we enable consumers of the v2 API to quickly
identify old instance snapshots for clean-up and other potential use cases.

Alternatives
------------

Something must be done to address the missing ``changes-since`` filter to
address priorities of both the Nova and Glance projects as expressed through
the Liberty summit.

We could implement changes-since as it exists in v1 API instead of making the
functionality more rich by allowing many comparative operators.

We could exclude the created_at filter from the feature at this time, but the
additional effort to include it is minimal, and it is possible that other
potential use cases may benefit as well as taking the opportunity to raise an
index on the column to benefit the default sort.

Data model impact
-----------------

Modify the Image domain class to raise indexes for the ``created_at`` and
``updated_at`` columns on the images DB table.

The additional indexes raised will impose a longer upgrade window for larger
Glance installs while the indexes are built.

REST API impact
---------------

Following the pattern of existing filters, the new filters may be specified as
query parameters, using the field to filter as the key and the filter criteria
as the value in the parameter.

Changes apply exclusively to Image API v2 Image entity listings:
    GET /v2/images/{image\_id}

Filter by adding optional query parameters::

 created_at     = Specifies to limit returned images based on when the image
                  was created, with value expressed as an ISO 8601 datetime.
 updated_at     = Specifies to limit returned images based on when the image
                  was last updated, with value expressed as an ISO 8601
                  datetime.

These filters will be added using syntax that conforms to the latest
guidelines from the OpenStack API Working Group, and any applicable draft
guidelines [4]_. This implies support for optional comparison operators with
the implied default comparison operator being 'equals' for exact matches.

An example of an acceptable criteria using an optional comparison operator::

  gte:1985-04-12T23:20:50.52Z

This represents any time at or after 20 minutes and 50.52 seconds after the
23rd hour of April 12th, 1985 in UTC.

.. note:: In all cases, literal expressions in any of these filters will be
   treated as case-insensitive.

Both new filters will support access control through oslo.policy enforcement
to allow a deployer to restrict usage of these filters. Because these filters
support this access control, no guarantee is given for availability of these
filters for all API consumers. Performance or security concerns around these
filters in any given deployment can be addressed through the use of custom
policy rules. Standard response codes will apply when access to the filter is
forbidden.

Security impact
---------------

None

Notifications impact
--------------------

None

Other end user impact
---------------------

Update python-glanceclient as needed.

Performance Impact
------------------

The appropriate indexes will also be updated on each row create and/or update
to the associated image row. This is considered a minimal impact.

Performance for sort operations on the indexed columns would be improved.

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
  steve-lewis

Reviewers
---------

Core reviewer(s):
  flwang
  flaper87

Other reviewer(s):
  None

Work Items
----------

* Registry changes to support new filters

* API changes to expose new filters

* Add Policy enforcement hooks

Dependencies
============

None

Testing
=======

Unit and functional tests will be added as appropriate.

Documentation Impact
====================

Docs needed for new API filters and usage as well as the additional policy
options.


References
==========

.. [1]

  `Image service API v2 <http://developer.openstack.org/
  api-ref-image-v2.html>`_

.. [2]

  `Glance sorting enhancements <http://specs.openstack.org/openstack/
  glance-specs/specs/kilo/sorting-enhancements.html>`_

.. [3]

  `Image service API v1 <http://developer.openstack.org/
  api-ref-image-v1.html>`_

.. [4]

  `API Working Group filtering guidelines draft <https://review.openstack.org/
  #/c/177468/>`_

* Nova blueprint to use Images V2 API
  https://blueprints.launchpad.net/nova/+spec/use-glance-v2-api

* Nova change request supporting the blueprint
  https://review.openstack.org/#/c/144875/
