..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=============================================
Notification Support for Metadata Definitions
=============================================

https://blueprints.launchpad.net/glance/+spec/metadefs-notifications

This blueprint adds metadata definition notification support.

The implemented juno spec for metadata notifications is here for reference:

http://specs.openstack.org/openstack/glance-specs/specs/juno/metadata-schema-catalog.html

Problem description
===================

Metadata definition resources - namespaces, objects, properties,
tags, and resource types - don't provide any notification events when
certain operations are performed on them. This doesn't allow for any
intelligent caching of the data, meaning that the only opportunity for
catalog users to be aware of changes is to continually poll. Polling is not
performant for catalog users and puts extra load on the API and database.

Proposed change
===============

We are proposing to support notifications for events on the
Metadata Definitions Catalog.

This implementation will include the following events that will be
triggered when necessary:

* metadef_namespace.create - namespace has been created
* metadef_namespace.update - namespace has been updated
* metadef_namespace.delete - namespace has been deleted
* metadef_object.create - object has been created
* metadef_object.update - object has been updated
* metadef_object.delete - object has been deleted
* metadef_property.create - property has been created
* metadef_property.update - property has been updated
* metadef_property.delete - property has been deleted
* metadef_tag.create - tag has been created
* metadef_tag.update - tag has been updated
* metadef_tag.delete - tag has been deleted
* metadef_resource_type.create - resource type has been added to namespace
* metadef_resource_type.delete - resource type has been removed from namespace

In addition we will add a new configuration option to allow for disabling
individual notifications.  It will be a comma separated list with the
following syntax::

    disabled_notifications = <type>.<action>

For example, the following would disable all tag notification and property
deletions::

    disabled_notifications = metadef_tag,metadef_property.delete

The notifier will read this configuration and ignore notifications that are
in the disabled list.

The reason for this proposed addition is that we aren't sure whether or not
tag notifications could get too chatty for some reason.  Therefore,
we'd like to give an option for deployers to disable it.

Alternatives
------------

No notification support could be added.  In this event,
constant polling for changes could be done.  The constant polling would lead
to both latency in getting updates and extra load on the API and database.

Data model impact
-----------------

None

REST API impact
---------------

No external API impacts will be visible.  The API itself will have a notifier
added as part of the call.

Security impact
---------------
None

Notifications impact
--------------------
A notifier will be added to the REST API calls.  The notifications listed
above will be added. A new configuration option will be added to disable
specific notifications.

Other end user impact
---------------------

None

Performance Impact
------------------

Additional notifications will be generated, but the amount of changes to
metadata definitions are not anticipated to be enough to impact performance.

However we want to add the new disabled_notifications configuration option to
allow operators to disable the notifications if they determine that are too
chatty.

Other deployer impact
---------------------
Deployers will have to setup listeners to received notification on metadefs
if they desire them.

Developer impact
----------------
None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
 kamil-rykowski

Other contributors:
 none

Reviewers
---------

Core reviewer(s):
  jokke

Other reviewer(s):
  lakshmi-sampath
  travis-tripp

Work Items
----------

Changes would be made to:

#. Glance v2 metadef APIs to add notifiers
#. notifer
#. gateway

Dependencies
============

Need to sync openstack/common from oslo-incubator for service module.

https://bugs.launchpad.net/glance/+bug/1413861

Testing
=======

Unit tests will be added for all possible code with a goal of being able to
isolate functionality as much as possible.

Tempest tests will be added wherever possible.

Documentation Impact
====================

Docs needed for new notification usage

References
==========

`Current glance metadata definition catalog documentation.
<http://docs.openstack.org/developer/glance/metadefs-concepts.html>`_
