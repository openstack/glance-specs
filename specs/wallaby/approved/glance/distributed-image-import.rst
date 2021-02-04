..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

================================
Distributed Image Import Support
================================

https://blueprints.launchpad.net/glance/+spec/distributed-image-import

Glance is moving towards supporting rich operations on images, mostly
during create time, via the import mechanism. This opens the door to
things like metadata injection, format conversion, and copying between
stores. Currently in order for this to work for what the user would
consider the closest analog to ``image-upload`` (which is the
``glance-direct`` import method), the API nodes require access to
shared storage which is a real blocker to adoption by deployers, and
is the subject of this spec.

Problem description
===================

Currently, when images are uploaded via the import mechanism, they are
stored in a special area called "staging." This is implemented under
the covers as a ``glance_store`` but it must be a locally-accessible
directory on the host filesystem. When using multiple API worker nodes
(as any real deployment would), the staging directories of all worker
nodes must be shared (i.e. mounted on a common NFS server) in order to
support the ``glance-direct`` import method. This is obviously a
problem for HA, performance, and a non-starter for any arrangement
where some glance API workers are located in remote sites.

In order to get an image from zero to usable with a ``glance-direct``
import, there are multiple API requests that are required. One of
these is the "staging" of the image data, which is followed by an
"import" operation which moves the data from the staging area to its
final destination(s). In a multi-node load-balanced scenario, the
"stage" operation will almost definitely hit a different worker than
the "import" operation, which will result in the latter not having
access to the staged image data in its staging store, and thus a
failure.


Proposed change
===============

The goal of the work outlined by this spec, is to allow the API
workers to keep their staging store directories local and
un-shared, but still enabling the import operation to work. In order
to do this, we will:

#. Record the URL by which the staging worker can be reached from the
   other workers in the database, and
#. Proxy the import request to the host that has it staged via that
   URL if the image is not local.
#. Any delete request while the image is staged also needs to be
   proxied, to ensure that the temporary file is deleted from the
   staging directory on the appropriate node.

With the above change, we can eliminate the need for shared storage
between the API worker nodes, allowing them to be isolated from an HA
point of view, as well as distributed geographically. It requires very
little actual change, as the non-local recipient node simply proxies
the request it receives to the node that has it staged and returns the
result. Both the ``import`` and ``delete`` operations are quick and do
not require a chained client -> proxy -> destination arrangement to
persist for long periods of time.

Alternatives
------------

One alternative is always to do nothing. We could continue to require
shared storage for the staging area between the API nodes to support
the import feature. We could also direct users to use image uploading
instead of importing in cases where a shared directory is not
feasible.

Another alternative would be to do effectively the same thing as
described here, but over RabbitMQ or some other RPC mechanism. That
has the disadvantage of needing additional supporting infrastructure
that glance does not currently require today, as well as new code to
handle sending and receiving those RPC calls and directing them to the
appropriate internal actions.

Data model impact
-----------------

In order to do this, we only need to store one new piece of
information, and only for a short period of time. That is the direct
URL of the API worker node that has staged an image. When the image is
finally imported (which usually happens immediately after staging),
that URL is no longer needed (nor relevant).

Initially, this implementation will use the reserved and
quota-independent ``os_glance`` namespace to store the URL in the
image's ``extra_properties``.

Later, when work is done to complete the usage of the staging
directory as a proper glance store, we may be able to store the URL in
the location metadata when the staging image data is registered
there. When this happens and assuming there is an appropriate
interface to use that location metadata, the plan will be to make this
implementation use that metadata store instead.

REST API impact
---------------

None.

Security impact
---------------

The proxy behavior will be done with the user's token, as presented to
the worker that the load balancer selects. No additional authorization
is added, and that token is used to make the request to the
appropriate worker on the user's behalf. Thus, this operation is
entirely transparent from a security perspective.

Notifications impact
--------------------

None.

Other end user impact
---------------------

More users will be able to use the image import functionality after
this is implemented as operators unwilling or unable to provide shared
storage between their workers will no longer need to disable
``glance-direct`` import for their users.

Performance Impact
------------------

Eliminating the use of a shared NFS (or similar) storage location for
the staging store should improve performance of upload and import,
since the staging directory can be local. It also vastly reduces the
need to move a potentially very large image back and forth over the
network multiple times in the process of doing a single image import
(reduces from a minimum of four round-trips of the image data to two).

Other deployer impact
---------------------

Deployers may wish to enable image import after upgrading to a release
that supports this, where previously they needed to disable the
feature (or just ``glance-direct``. They will need to configure each
API worker with an additional element indicating the direct URL by
which they can be reached, and ensure that API nodes are able to
communicate with each other in this way.

Deployers that currently support import via shared storage may want to
quiesce image activity while they split the workers from the shared
storage location to local directories.

Deployers wishing to keep the shared storage for image staging may
choose to do so with no impact or action required.

Deployers wishing to keep the import feature (or just the
``glance-direct`` method) disabled, may also do so with no impact or
action required.

Developer impact
----------------

When we move to the location-based metadata approach detailed above,
we will need to change the API from using the image
``extra_properties`` dict to passing that information through to the
store routines. It is expected that this will be less than ten lines
of code.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  danms

Work Items
----------

#. Build a mechanism by which we can use the user's authorization
   token to make an outbound call to another service
#. Add a configuration element allowing the operators to teach the API
   workers what their externally-visible URL is.
#. Make the API workers record their own URL on the image during the
   image ``stage`` operation.
#. Make the ``import`` and ``delete`` operations proxy to the
   appropriate URL when it is determined appropriate to do so.

Dependencies
============

* Devstack needs support for starting additional glance workers in
  order to properly test this.
* Tempest needs support for looking up alternative image services in
  the service catalog.

Testing
=======

Unit tests for the API behaviors and import tasks are sufficient, as
the changes are minimal.

Functional tests for the image proxying.

A set of tempest tests that stage and import/delete images on
different glance workers with separate staging directories will be
written to ensure CI coverage for this behavior in a realistic sense.


Documentation Impact
====================

Since this just makes something work that did not before, no large
amount of documentation will need to be written. As mentioned above,
deployers will have one new config option to set on API nodes as well
as network and firewall considerations to address in order for this to
work, which will be covered in the documentation.

References
==========

Much discussion on this was done on another spec:

* https://review.opendev.org/c/openstack/glance-specs/+/763574

The code implementation for this also has discussion relevant to the
topic:

* https://review.opendev.org/c/openstack/glance/+/769976

This was discussed at the Wallaby PTG in the glance sessions, under
the topic of "Cluster Awareness":

* https://etherpad.opendev.org/p/glance-wallaby-ptg

This has been discussed in multiple glance meetings:

* http://eavesdrop.openstack.org/meetings/glance/2021/glance.2021-01-28-14.01.log.html#l-26
* http://eavesdrop.openstack.org/meetings/glance/2021/glance.2021-02-04-14.00.log.html#l-30
