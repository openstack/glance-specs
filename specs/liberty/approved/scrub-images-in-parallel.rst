..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

========================
Scrub Images in Parallel
========================

https://blueprints.launchpad.net/glance/+spec/scrub-images-in-parallel

This change proposal introduces a way for the scrubber to scrub images in
parallel when delayed delete is enabled.


Problem description
===================

As of today, when delayed delete is enabled, images are being scrubbed
serially while the image locations, if multiple, are being scrubbed in
parallel. For the general case, this may not achieve much performance gain as
the number of images is likely to be more than the number of image locations
per image. Consequently, the scrubber can fall behind when the number of
pending_delete images increase.

Proposed change
===============

This change will attempt to parallelize image scrubbing while leaving image
locations to be scrubbed serially.

A new config option would be introduced to offer the flexibility to choose
between serial or parallel scrubbing. Also, using this config option, one can
regulate the degree of parallelism to a desired level.

Alternatives
------------

- One can run multiple scrubbers to keep up with the increase in pending_delete
  images. However, in that case, scrubbers may race as they all get the same
  set of images from the registry. This may not be a bad option if one can
  ignore all the errors in the logs. Nevertheless, scrubbing images serially
  is still inefficient.

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

As mentioned in the performance impact section, while setting the degree of
parallelism one should take into account any rate-limits enforced by the
backend store. If the degree of parallelism is set to go beyond the
rate-limits, an attacker may be able to force the scrubber hit the rate-limits
by creating and deleting several images in a short span of time.

Notifications impact
--------------------

None

Other end user impact
---------------------

None

Performance Impact
------------------

When using parallel scrubbing one must take into account any rate-limits on the
backend store. Depending on extent of parallelism desired, scrubber may hit the
rate-limits of the backend store and may eventually slowdown or fail.

Other deployer impact
---------------------

Deployers would have to set the new configuration option introduced with this
change proposal to be able to scrub images in parallel.

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
    hemanth-makkapati

Other contributors:
    jesse-j-cook

Reviewers
---------

Core reviewer(s):
    nikhil-komawar


Other reviewer(s):
    flaper87
    brian-rosmaita

Work Items
----------
- Use eventlet to parallelize image scrubbing
- Monkey-patch required modules for eventlet
- Test on devstack


Dependencies
============

None

Testing
=======


Documentation Impact
====================

The new configuration option would require documentation.

References
==========

None
