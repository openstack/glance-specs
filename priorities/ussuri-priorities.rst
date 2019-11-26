.. _ussuri-priorities:

=========================
Ussuri Project Priorities
=========================

The Ussuri review priorities were discussed at the Shanghai PTG. The
preliminary list was maintained on the `Shanghai PTG etherpad`_.

This list is an estimate of what the Glance project team can accomplish
during the Ussuri cycle based on our developers' estimates of how much
time they can commit to Glance.

The following list is roughly indicates milestonewise priorities.

.. list-table::
   :header-rows: 1

   * - Priority Item
     - Owner(s)
     - Spec(s)
     - Target release milestone
   * - Remove native ssl support
     - `Erno Kuvaja`_
     - None
     - M1
   * - Import image in multiple stores
     - `Grégoire Unbekandt`_
     - `multiple image import`_
     - M2
   * - Copy existing image in multiple stores
     - `Abhishek Kekane`_
     - `copy image in multiple stores`_
     - M2
   * - S3 driver for glance_store
     - `Naohiro Sameshima`_
     - `s3 driver`_
     - M2
   * - remove sheepdog driver from glance_store
     - `Abhishek Kekane`_
     - None
     - M2
   * - Permanent solution for Subunit parser error
     - `Abhishek Kekane`_
     - None
     - M2
   * - Nova - snapshot/backup upload to multiple stores
     - `Abhishek Kekane`_
     - `nova snapshot`_
     - M2
   * - Cinder - volume upload to multiple stores
     - `Abhishek Kekane`_
     - `cinder uploadtoimage`_
     - M2
   * - Cluster awareness of glance API nodes
     - `Erno Kuvaja`_
     - `cluster awareness`_
     - M2
   * - remove registry code from glance
     - `Abhishek Kekane`_
     - None
     - M2
   * - Delete image from single store
     - `Erno Kuvaja`_
     - `delete store from image`_
     - M2
   * - image-import.conf parsing issue with uwsgi
     - Unassigned
     - None
     - M2
   * - Multiple cinder store support in glance_store
     - `Abhishek Kekane`_
     - `cinder glance_store`_
     - M3
   * - Image encryption
     - `Josephine Seifert`_
     - `image encryption`_
     - M3
   * - Tempest work
     - `Abhishek Kekane`_
     - None
     - M3


.. _Shanghai PTG etherpad: https://etherpad.openstack.org/p/Glance-Ussuri-PTG-planning

.. _Grégoire Unbekandt: https://launchpad.net/~yebinama
.. _Erno Kuvaja: https://launchpad.net/~jokke
.. _Abhishek Kekane: https://launchpad.net/~abhishek-kekane
.. _Josephine Seifert: https://launchpad.net/~josei
.. _Naohiro Sameshima: https://launchpad.net/~nao-shark

.. _multiple image import: https://review.opendev.org/669201
.. _copy image in multiple stores: https://review.opendev.org/694724
.. _s3 driver: https://review.opendev.org/687390
.. _nova snapshot: https://review.opendev.org/641210
.. _cinder uploadtoimage: https://review.opendev.org/695630
.. _cluster awareness: https://review.opendev.org/664956
.. _cinder glance_store: https://review.opendev.org/695152
.. _image encryption: https://review.opendev.org/609667
.. _delete store from image: https://review.opendev.org/698018


Important dates
---------------

This is an abbreviated list focused on dates relevant to Glance.  See
`Ussuri Release Schedule`_ for the complete list for OpenStack.

.. _Ussuri Release Schedule: https://releases.openstack.org/ussuri/schedule.html

.. list-table::
   :header-rows: 1

   * - R-22
     - Dec 13
     - U-1 milestone
   * - R-13
     - Feb 14
     - U-2 milestone
   * - R-6
     - April 03
     - glance_store Ussuri release (final release for non-client libraries)
   * - R-5
     - April 22
     - * U-3 milestone
       * **Glance feature freeze**
       * python-glanceclient Ussuri release (final release for client libraries);
   * - R-3
     - April 24
     - RC-1 release and **string freeze**
   * - R-1
     - May 08
     - final RCs
   * - R-0
     - May 15
     - **Ussuri release**

