.. _pike-priorities:

======================
Pike Review Priorities
======================

Here are the Pike review priorities.  Due to the Pike cycle Glance personnel
situation, this list is reduced from what was published on the `PTG etherpad`_.
Thus in this cycle we're introducing a category of *untargeted* specs.  These
specs have been reviewed, approved, and are sufficiently detailed that they
could be implemented by new contributors, but given the current personnel
situation, we cannot realistically include them as priorities for the Pike
release.

.. list-table::
   :header-rows: 1

   * - Priority Item
     - Owner(s)
     - Spec(s)
   * - Image Import Refactor
     - `Erno Kuvaja`_
     - `image import refactor`_
   * - OpenStack Pike "Community" Goal 1
     - was `Alexander Bashmakov`_, seeking new owner
     - `support python 3.5`_
   * - OpenStack Pike "Community" Goal 2
     - `Matthew Treinish`_
     - `control plane API endpoints deployment via WSGI`_

.. _PTG etherpad: https://etherpad.openstack.org/p/glance-pike-ptg-roadmap-prelim

.. _Alexander Bashmakov: https://launchpad.net/~abashmak
.. _Matthew Treinish: https://launchpad.net/~treinish
.. _Erno Kuvaja: https://launchpad.net/~jokke

.. _support python 3.5: https://specs.openstack.org/openstack/glance-specs/specs/pike/approved/glance/lite-specs.html#community-goal-support-python-3-5
.. _control plane API endpoints deployment via WSGI: https://specs.openstack.org/openstack/glance-specs/specs/pike/approved/glance/lite-specs.html#community-goal-control-plane-api-endpoints-deployment-via-wsgi
.. _image import refactor: http://specs.openstack.org/openstack/glance-specs/specs/mitaka/approved/image-import/image-import-refactor.html


Important dates
---------------

This is an abbreviated list focused on dates relevant to Glance.  See
`Pike Release Schedule <https://releases.openstack.org/pike/schedule.html>`_
for the complete list for OpenStack.

.. list-table::
   :header-rows: 1

   * - Milestone
     - Week of
     - What
   * - R-22
     - March 27
     - Glance spec proposal freeze
   * - R-20
     - April 10
     - P-1 milestone
   * - R-19
     - April 17
     - virtual midcycle meeting; **Glance spec freeze**
   * - R-16
     - May 8
     - OpenStack Summit/Forum
   * - R-12
     - June 5
     - P-2 milestone
   * - R-6
     - July 17
     - glance_store Pike release (final release for non-client libraries)
   * - R-5
     - July 24
     - P-3 milestone; **Glance feature freeze**;
       python-glanceclient Pike release (final release for client libraries);
       Pike community goals completion
   * - R-3
     - August 7
     - RC-1 release and **string freeze**
   * - R-1
     - August 21
     - final RCs
   * - R-0
     - August 28
     - **Pike release**
