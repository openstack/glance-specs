.. _queens-priorities:

========================
Queens Review Priorities
========================

The Queens review priorities were discussed at the Denver PTG and refined
during the spec review process early in the Queens cycle.  The preliminary
list was maintained on the `Denver PTG etherpad`_.

This list is an estimate of what the Glance project team can accomplish
during the Queens cycle based on our developers' estimates of how much
time they can commit to Glance.  If additional resources become available,
it's possible that some of the :doc:`../specs/untargeted/index` could be
added to Queens.

The following list is roughly in priority order (highest to lowest).

.. list-table::
   :header-rows: 1

   * - Priority Item
     - Owner(s)
     - Spec(s)
   * - Image Import Refactor
     - `Erno Kuvaja`_
     - `image import refactor`_
   * - Inject Metadata Automatically
     - `Abhishek Kekane`_
     - `inject metadata automatically`_
   * - Secure Hash Algorithm Support
     - `Scott McClymont`_
     - `multihash`_
   * - Fix OSSN-0075
     - `Brian Rosmaita`_
     - `fix ossn-0075`_
   * - Glanceclient: Switch to Turn Off Schema Validation
     - unassigned
     - `validation switch`_
   * - Refactor Glance Scrubber
     - `Xiyuan Wang`_
     - `refactor glance scrubber`_
   * - Remove the Images API v1
     - `Brian Rosmaita`_
     - `remove v1`_
   * - Actually Deprecate the Glance Registry
     - `Erno Kuvaja`_
     - `deprecate glance registry`_
   * - Glanceclient: Deprecate Images API v1 Support
     - `Brian Rosmaita`_
     - `deprecate v1 support`_
   * - OpenStack Queens "Community" Goal
     - `Lance Bragstad`_
     - `policy in code`_

.. _Denver PTG etherpad: https://etherpad.openstack.org/p/glance-queens-ptg-roadmap

.. _Erno Kuvaja: https://launchpad.net/~jokke
.. _Scott McClymont: https://launchpad.net/~smcclymont
.. _Abhishek Kekane: https://launchpad.net/~abhishek-kekane
.. _Brian Rosmaita: https://launchpad.net/~brian-rosmaita
.. _Xiyuan Wang: https://launchpad.net/~wangxiyuan
.. _Lance Bragstad: https://launchpad.net/~lbragstad

.. _image import refactor: http://specs.openstack.org/openstack/glance-specs/specs/mitaka/approved/image-import/image-import-refactor.html
.. _multihash: https://specs.openstack.org/openstack/glance-specs/specs/queens/approved/glance/multihash.html
.. _inject metadata automatically: https://specs.openstack.org/openstack/glance-specs/specs/queens/approved/glance/inject-automatic-metadata.html
.. _fix ossn-0075: https://review.openstack.org/#/c/468179/
.. _deprecate glance registry: https://specs.openstack.org/openstack/glance-specs/specs/queens/approved/glance/deprecate-registry.html
.. _refactor glance scrubber: http://specs.openstack.org/openstack/glance-specs/specs/queens/approved/glance/lite-spec-scrubber-refactor.html
.. _remove v1: http://specs.openstack.org/openstack/glance-specs/specs/queens/approved/glance/remove-v1.html
.. _validation switch: http://specs.openstack.org/openstack/glance-specs/specs/queens/approved/python-glanceclient/no-schema-validation.html
.. _deprecate v1 support: http://specs.openstack.org/openstack/glance-specs/specs/queens/approved/python-glanceclient/deprecate-v1-support.html
.. _policy in code: https://specs.openstack.org/openstack/glance-specs/specs/queens/approved/glance/spec-lite-policy-and-docs-in-code.html


Important dates
---------------

This is an abbreviated list focused on dates relevant to Glance.  See
`Queens Release Schedule`_ for the complete list for OpenStack.

.. _Queens Release Schedule: https://releases.openstack.org/queens/schedule.html

.. list-table::
   :header-rows: 1

   * - Milestone
     - Week of
     - What
   * - R-22
     - Sept 25
     - Glance spec proposal freeze (Thursday 28 Sept 13:00 UTC)
   * - R-21
     - Oct 2
     - **Glance spec freeze** (Friday 6 Oct 23:59 UTC)
   * - R-19
     - Oct 16
     - Q-1 milestone
   * - R-16
     - Nov 6
     - Sydney Summit/Forum (expect low activity)
   * - R-12
     - Dec 4
     - Q-2 milestone
   * - R-9
     - Dec 25
     - Holidays (expect low activity)
   * - R-8
     - Jan 1
     - Holidays (expect low activity)
   * - R-6
     - Jan 8
     - glance_store Queens release (final release for non-client libraries)
   * - R-5
     - Jan 22
     - * Q-3 milestone
       * **Glance feature freeze**
       * python-glanceclient Queens release (final release for client libraries);
       * remove Images API v1
       * remove Registry API v1
       * Queens community goal completion
   * - R-3
     - Feb 5
     - RC-1 release and **string freeze**
   * - R-1
     - Feb 19
     - final RCs
   * - R-0
     - Feb 26
     - **Queens release**
