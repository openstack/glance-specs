..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.
 http://creativecommons.org/licenses/by/3.0/legalcode

==============================================================
Spec Lite: Add support for extending attached (in-use) volumes
==============================================================

:project: glance_store

:problem: When creating an image in cinder store, we perform a series of
          API calls to cinder creating, attaching, detaching, extending etc
          the volume. The sequence of operations performed to copy image into
          the volume are, attach the volume, copy image contents into the
          volume (until we've space left in volume), detach the volume,
          see if extend is required (if image is bigger than current volume
          size) and perform it. We repeat the operations until the whole
          image is copied into the volume.
          The part where we detach the volume, extend and attach it again is
          very inefficient as we've to do it for every 1GB of image. For some
          backends, cinder supports extending attached (in-use) volumes and
          we should use that to optimize the image create operation.
          Cinder backends that support extend in-use volumes:
          https://docs.openstack.org/cinder/latest/reference/support-matrix.html#operation_online_extend_support

          Another issue noticed related to this is, since cinder only supports
          extend and not shrink, we end up with extending the volume 1 GB
          at a time and eventually taking more time to create large images.

:solution: We will introduce a new config option,
           ``cinder_do_extend_attached`` which will be a boolean option.
           Operators can set it to ``true`` if the cinder backend they are
           using supports extending attached volumes. The default value will
           be ``false``.
           If we have ``cinder_do_extend_attached`` set to ``true``, we will
           call the cinder ``os-extend`` API with microversion ``3.42`` that
           will allow us to extend the attached volume.
           Finally, we will call the ``extend_volume`` method of os-brick to
           instruct the kernel to resize the volume on the host.

           Additional efforts:

           To address the concern related to 1 GB resize, cinder store already
           has handling of size, if correctly passed by glance, we initialize
           the volume size with the image size avoiding unnecessary extend
           operations. So glance needs to be updated to pass correct image
           size to cinder store.


:impacts: None

:alternatives: None

:timeline: 2023.1

:link:
       * https://review.opendev.org/c/openstack/glance_store/+/843103
       * https://review.opendev.org/c/openstack/glance_store/+/868742

:reviewers: Abhishek Kekane, Brian Rosmaita, Dan Smith, Erno Kuvaja

:assignee: Rajat Dhasmana (whoami-rajat)
