.. glance-specs documentation master file

============================
Image Service (Glance) Plans
============================

The Glance Project Team has the responsibility for maintaining the
following projects:

* Glance: https://git.openstack.org/cgit/openstack/glance
* The glance_store library: https://git.openstack.org/cgit/openstack/glance_store
* The Glance client: https://git.openstack.org/cgit/openstack/python-glanceclient

This repository contains proposals for new features, or proposals for
changes to the current projects that are sufficiently complicated or
controversial that in-depth discussion is required.

The Glance Project Team uses two types of design document:

**Spec**
  A *spec* is an in-depth description of the proposed feature.  It's required
  for any proposal that affects an API supplied by Glance, for any proposal
  that changes the data model, for any proposal that would require a database
  migration, or any change that requires a thorough exploration of alternative
  ways to accomplish the feature.

**Spec Lite**
  A *spec lite* is a brief proposal for a small enhancement to Glance.

Please see the `Glance Contribution Guidelines`_ for further information about
how to make a proposal to this repository.

.. _Glance Contribution Guidelines: https://docs.openstack.org/developer/glance/contributing/blueprints.html

Priorities
==========

During each Project Team Gathering (or "design summit"), we agree on what the
whole community wants to focus on for the upcoming release. This is the output
of those discussions:

.. toctree::
   :glob:
   :maxdepth: 1

   priorities/victoria-priorities
   priorities/ussuri-priorities
   priorities/train-priorities
   previous-priorities

Specifications
==============

Current
-------

.. toctree::
   :glob:
   :maxdepth: 1

   specs/victoria/*
   specs/ussuri/*
   specs/train/*
   specs/untargeted/*

.. Future
.. ------

.. .. toctree::
..   :glob:
..   :maxdepth: 1

Past
----

.. toctree::
   :glob:
   :maxdepth: 1

   specs/stein/*
   specs/rocky/*
   specs/queens/*
   specs/pike/*
   specs/ocata/*
   specs/newton/*
   specs/mitaka/*
   specs/liberty/index
   specs/kilo/index
   specs/juno/index


Image Service API Guide
=======================

Image Service API v2
--------------------

.. toctree::
    :maxdepth: 1

    specs/api/v2/image-api-v2.rst
    specs/api/v2/image-metadata-api-v2.rst
    specs/api/v2/image-binary-data-api-v2.rst
    specs/api/v2/lists-image-api-v2.rst
    specs/api/v2/retrieve-image-api-v2.rst
    specs/api/v2/delete-image-api-v2.rst
    specs/api/v2/sharing-image-api-v2.rst
    specs/api/v2/http-patch-image-api-v2.rst

Image Service API v1
--------------------

.. include:: specs/api/v1/deprecation-note.inc

.. toctree::
    :maxdepth: 1

    specs/api/v1/image_service_v1_api
    specs/api/v1/authentication
    specs/api/v1/adding_a_new_virtual_machine_image
    specs/api/v1/retrieving_a_virtual_machine_image
    specs/api/v1/requesting_detailed_metadata_on_a_specific_image
    specs/api/v1/requesting_detailed_metadata_on_public_vm_images
    specs/api/v1/requesting_shared_images
    specs/api/v1/requesting_image_memberships
    specs/api/v1/adding_a_member_to_an_image
    specs/api/v1/removing_a_member_from_an_image
    specs/api/v1/replacing_a_membership_list_for_an_image
    specs/api/v1/filtering_images_returned_via_get__images_and_get__images_detail


==================
Indices and tables
==================

* :ref:`search`
