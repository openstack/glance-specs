..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=====================================
Add distinction layer in domain model
=====================================

https://blueprints.launchpad.net/glance/+spec/add-distinction-layer

To improve the stability and performance it is suggested to make changes in
the domain by adding distinction layer, which will store all changes of the
object and pass to DB only modified attributes.


Problem description
===================

Current Glance Images v2 architectures have a defect associated with risks of
race conditions arising under heavy load on the system. Here is an example of
the race condition:
Suppose an image has properties ``{"foo": "bar", "goo": "far"}``.
User1 wants to change ``{"foo": "baz"}``.
User2 wants to change ``{"goo": "yuck"}``.
If user1 and user2 make concurrent requests, they both get the same data to
work with.
Suppose user1's change gets written first, resulting in:
``{"foo": "baz", "goo": "far"}``.
Then user2's change is written, resulting in:
``{"foo": "bar", "goo": "yuck"}``.
User1's change has been reverted, which is not desired behavior.

Besides this, there is an issue of unreasonably increased load on the database
when updating. This problem occurs because all image fields are being updated
each time whether they've been modified or not, so there is lots of
unnecessary traffic on the database. Also there is an issue an issue with
changing the status of the image.

These issues do not appear at low load, but in the future, with wider use,
it can lead to serious problems, such as loss of information and unstable
behaviour.

A more detailed description of the problems can be found on
references [7]_ and [8]_.


Proposed change
===============

When updating of image the original image is retrieved from the database.
Distinction layer creates dict representation of modified image and compares
it with the original one. Then it passes to DB layer dict of modified
attributes.

Continuing the example from the previous section, consider the situation after
user1's update has been processed and ``{"foo": "baz"}`` in the database.
User2's distinction layer image record contains ``{"foo": "bar"}``, since that
was the state of the image when the fetch occurred.  However, since user2's
change request doesn't touch ``foo``, only ``{"goo": "yuck"}`` will be written
to the database.
Thus the final image record will have ``{"foo": "baz", "goo": "yuck"}``
as both users intend. Of course, if user2 does actually change the value
of ``foo``, then user2's change will be persisted in the database, but this is
expected behavior.

Alternatives
------------

There have been attempts to solve the problem using inheritance.
References on commits [1]_, [2]_. But commits were abandoned, because
inheritance is contrary to the Glance design strategy of favoring flat
hierarchies and preferring aggregation over inheritance.

Alternatively, it was suggested to forbid updates while an image is in
"saving" state. But this idea was rejected, because images tend to be in
status 'saving' for a relatively long period, and users expect to be able
to modify the image record during this time.
Also it fixes only a special case, when status is 'saving', but the whole
problem with race conditions and unreasonably increased load on the database
is still here.


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

None

Performance Impact
------------------

Performance tests were conducted.
We used the database: MySQL Ver 14.14 Distrib 5.5.47
We determined the time spent in update one parameter of image. Tests showed
the dependence of the execution time of the number of requests.
Test code is presented in [3]_.

We tested two versions of the code:
1) "master" branch;
2) commit "Add distinction layer" [6]_.

The results are presented in table [4]_ and graph [5]_.

Graph showed the dependence of the execution time of the number of requests:
* Blue line - "master" branch;
* Red line - commit "Add distinction layer" [6]_.

The testing concluded that the use of distinction layer accelerates update
average of 34.54%.


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

  dshakhray

Reviewers
---------

  mfedosin
  nikhil
  rosmaita


Work Items
----------

1) Implement distinction layer:
    a. Create a distinction layer and add it to 'gateway.py'
    b. Add classes ImageProxy, ImageRepoProxy, ImageFactoryProxy.
    c. Add to ImageRepoProxy class methods get, add, save.
    d. Add the class ImageRepoProxy additional methods to implement the logic.
    e. Make the appropriate changes in the 'db/simple/api.py',
       'db/simple/api.py', 'db/__init__.py'.

2) Add related functional and unit tests.
3) Write a documentation about this layer.


Dependencies
============

None


Testing
=======

Unit and functional tests will be added as appropriate.


Documentation Impact
====================

All changes have to be described in detail in the related documentation
section.


References
==========

.. [1]

  `Fix incorrect status update during upload in v2 <https://review.openstack.org/#/c/123799/>`_

.. [2]

  `v2 update image persists only modified attributes <https://review.openstack.org/#/c/123722/>`_

.. [3]

  `Script for performance tests <http://paste.openstack.org/show/497360/>`_

.. [4]

  `Table of performance test results <http://paste.openstack.org/show/497353/>`_

.. [5]

  `Graph of performance test results <https://drive.google.com/file/d/0B0Tzc8_HuQodS1VMbGpUZHhEYUE/view?usp=sharing>`_

.. [6]

  `Commit "Add distinction layer" <https://review.openstack.org/#/c/315483/>`_

.. [7]

  `Concurrency Update issue in v2 <https://bugs.launchpad.net/glance/+bug/1371728>`_

.. [8]

  `Incorrect status change after image uploading in v2 <https://bugs.launchpad.net/glance/+bug/1372564>`_

