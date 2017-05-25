..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

======================================================
Tag Metadata Definitions - python-glanceclient Changes
======================================================

https://blueprints.launchpad.net/glance/+spec/metadefs-tags-cli

This blueprint adds in supporting code for Metadata Definition (metadef) tags.
The metadef tag catalog was approved and added into the Glance server in the
Kilo release.

The implemented Kilo spec is here for reference:
https://github.com/openstack/glance-specs/blob/master/specs/kilo/metadefs-tags.rst

Problem description
===================

This blueprint specifies the CRUD details for the metadef tags.

The bulk of the work for this blueprint was committed within the Kilo time
frame, but, did not make it out of the review process in time for the release.

Proposed change
===============

We are proposing enhancements to the python-glanceclient to allow metadef
tags to be created, retrieve, updated and deleted.

The following sub-commands will be added to python-glanceclient:

o md-tag-create --name <NAME> <NAMESPACE>
  Adds tag <NAME> to namespace <NAMESPACE>. Retains all other tag names.

o md-tag-create-multiple --names <NAMES> [--delim <DELIM>] <NAMESPACE>
  Replaces all tags in the <NAMESPACE> with those listed in <NAMES>.
  The delimeter used in the list can be overidden with the single char <DELIM>
  Comma is the default delimter.

o md-tag-delete <NAMESPACE> <TAG>
  Deletes the tag <TAG> from the namespace.

o md-tag-list <NAMESPACE>
  List all tags associated with the namespace.

o md-tag-show <NAMESPACE> <TAG>
  Shows the details of the specified tag.

o md-tag-update --name <NAME> <NAMESPACE> <TAG>
  Renames the tag associated with <NAMESPACE> <TAG> to the new <NAME>.

o md-namespace-tags-delete <NAMESPACE>
  Deletes all tags associated with the namespace.

The sub-commands will be allowed when specified with --os-image-api-version
of 2. Example: glance --os-image-api-version 2 md-tag-list <NAMESPACE>

This is consistent with how the other metadef commands have been implemented.

Alternatives
------------

An alternative to the "help" listing of metadef related sub-commands has been
suggested to lessen the amount of "md" related subcommands. This should be
handled in a separate bug if done.

Data model impact
-----------------

None.
The following DB schema is the implemented schema in Kilo.
Constraints not shown for readability.

Basic Schema::

  CREATE TABLE `metadef_tags` (
    `id`                     int(11) NOT NULL AUTO_INCREMENT,
    `namespace_id`           int(11) NOT NULL,
    `name`                   varchar(80) NOT NULL,
    `created_at`             timestamp NOT NULL,
    `updated_at`             timestamp
  )

REST API impact
---------------

None.
The python-glanceclient will use the metadef Tag REST API created in Kilo.

**API Version**

All URLS will be under the v2 Glance API.  If it is not explicitly specified
assume /v2/<url>

Security impact
---------------
None

Notifications impact
--------------------
None

Other end user impact
---------------------

We intend to expose this via Horizon and are working on related blueprints.

Performance Impact
------------------

None anticipated.

This is expected to be called from Horizon when an admin wants to annotate
tags onto things likes images and instances. This API would be hit for them to
get available tags or create new ones.

Other deployer impact
---------------------
None

Developer impact
----------------
None (New API)

Implementation
==============

Assignee(s)
-----------

Primary assignee:
 wayne-okuma

Other contributors:
 None

Reviewers
---------

Core reviewer(s):
  zhiyan
  Ian Cordasco (sigmavirus24)
  Stuart McLaren

Other reviewer(s):
  lakshmi-sampath
  travis-tripp

Work Items
----------

 Changes would be made to:

 #. The python-glanceclient to support the new sub-commands

Dependencies
============

Same dependencies as Glance.

Testing
=======

Unit tests will be added for all possible code with a goal of being able to
isolate functionality as much as possible.

Documentation Impact
====================

Docs needed for new API extension and usage

References
==========

.. Had to format links strangely in order to meet 80 character limit

`Youtube summit recap of Graffiti Juno POC demo that included tags.
<https://www.youtube.com/watch?v=Dhrthnq1bnw>`_

`Current glance metadata definition catalog documentation.
<http://docs.openstack.org/developer/glance/metadefs-concepts.html>`_

*Simple application category tags (no hierarchy)*

Images, volumes, software applications can be assigned to a category.
Similarly, a flavor or host aggregate could be "tagged" with supporting a
category of application, such as "BigData" or "Encryption". Using the
matching of categories, flavors or host aggregates that support that category
of application can be easily paired up.

Note: If a resource type doesn’t provide a "Tag" mechanism (only key value
pairs), a blueprint should be added to support tags on that type of resource.
In lieu of that, a key of "tags" with a comma separated list of tags as the
value be set on the resource
