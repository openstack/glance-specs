..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================================
Software Metadata Definitions
==========================================

Include the URL of your launchpad blueprint:

https://blueprints.launchpad.net/glance/+spec/software-metadefs

The spec will provide a base library of metadata definitions for various
common software products, components, and libraries that may exist on
particular image (or volume or instance). These metadata definitions will
make it easier for end users and admins to easily describe the software and
its properties. This information will enable an improved and faster user
experience for applying software metadata, searching based on software
metadata, and viewing the software information about an image.

Various improvements in horizon are underway to take advantage of this
metadata. For example, a user launching an instance will be able to expand
the image row to see addition information about the image.  This will include
providing the metadata definition for properties on the image.  This same
information will also be visible from the image and instance details page.

The following blueprint is for launch instance:

https://blueprints.launchpad.net/horizon/+spec/launch-instance-redesign

The following screenshot mockup provides an example from the instance details:

https://wiki.openstack.org/w/images/3/37/Instance-details-mock-january-2015.png

The following blueprint is for instance details (see source tab):

https://blueprints.launchpad.net/horizon/+spec/instance-details-redesign

Additional horizon blueprints are being prepared that will display metadata,
but are still undergoing collaborative UX design first.

Problem description
===================

In Juno, the metadata definitions catalog was introduced with a primary
intent to improve collaboration on the metadata that can be applied to
different resources such as images, flavors, host aggregates,
and volumes. The primary development focus in Juno was on what is currently
system metadata in OpenStack (properties that affect scheduling and driver
behavior).

The metadata fields on these same resources can also be used to provide
additional, rich information that describes the resource for user
understanding and search. This information can be leveraged to improve
instance launching, application catalogs, and a variety of other user
interaction points.

Current methodologies present and proposed in OpenStack require repetitive
descriptions, categorization, imagery, and attributes to be applied on each
instance of a resource.

For example, if multiple images contain Apache then each image will require
the user to type in information about Apache, will require them to provide
some sort of categorization tag, and will not have any common "template" like
fields for the software which can be used for faceted search.

This leads to redundancy, spelling mistakes, inconsistency as well as a
general lack of ability to present a rich UI experience. In addition,
there is no common set of base definitions for software that can be shared
across deployments.

Proposed change
===============

The implementation of this spec will provide a base library of metadata
definitions for various common software products, components,
and libraries that may exist on particular image (or volume or instance).

The following are examples of the type of commonly used software that will
be included:
* Databases such as MySQL, PostgreSQL, Oracle, MongoDB, etc.
* Web servers such as Apache, nginx, IIS
* Runtimes like php, java, python, etc.

The review process of the actual proposed definitions will allow for the
community to suggest additional software to include or to suggest removing
certain definitions.

These metadata definitions will make it easier for end users and admins to
easily describe the software and its properties. This information will
enable an improved and faster user experience for applying software
metadata, searching based on software metadata, and viewing the software
information about an image.

Users of the glance client / cli will be able to lookup the available
definitions just like they do today. So the below methodology that can be
done to look up something like virtual CPU topology properties will work for
the software definitions::

 glance --os-image-api-version 2 md-namespace-list

 glance --os-image-api-version 2 md-namespace-show OS::Compute::VirtCPUTopology

 glance --os-image-api-version 2 md-property-show OS::Compute::VirtCPUTopology cpu_maxsockets

The metadata definitions will be included as additional json files in the
etc/metadefs directory just like the existing example system metadata
definitions.

Alternatives
------------

As every single image, artifact, or other type of resource is added to the
system, the admin and users could be responsible for putting a good description
that is consistent with other descriptions, could try to remember all the
right tags to add, or could try to remember all the same properties to
upload to it. This leads to redundancy, spelling mistakes,
inconsistency as well as a general lack of ability to present a rich UI
experience. It also doesn't enable predictable search facets for rich search
experience.

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

None

Notifications impact
--------------------

None

Other end user impact
---------------------

No impacts glance client.

Work is being done in horizon to take better advantage of these definitions.

Performance Impact
------------------

None.

Other deployer impact
---------------------

This spec will provide deployers with a base set of metadata definitions for
software similar to what they are provided for system metadata definitions.
They can choose to either use or not use the base definitions provided in this
spec.

In Juno, example software definitions were not provided.  To upgrade,
they will need to deploy these files to etc/glance/metadefs and then call
glance-manage db_load_metadefs. This call automatically loads new namespaces
that aren't already loaded.

Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  travis-tripp

Other contributors:
  lakshmi-sampath
  murali-sundar

Reviewers
---------

Core reviewer(s):
  nikhil-komawar
  <launchpad-id or None>

Other reviewer(s):
  wayne-okuma
  murali-sundar

Work Items
----------

Provide definition files for different categories of software.
 - Databases
 - Web servers
 - Runtime environments
 - More

Dependencies
============

None

Testing
=======

Existing code ensures that metadata definitions are loaded properly.

Documentation Impact
====================

Possibly update docs to talk about the base software definitions provided.

References
==========

http://docs.openstack.org/developer/glance/metadefs-concepts.html