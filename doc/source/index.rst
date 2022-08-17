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

   priorities/antelope-priorities
   previous-priorities

Specifications
==============

Current
-------

.. toctree::
   :glob:
   :maxdepth: 1

   specs/antelope/*
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

   specs/zed/*
   specs/yoga/*
   specs/xena/*
   specs/wallaby/*
   specs/victoria/*
   specs/ussuri/*
   specs/train/*
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

==================
Indices and tables
==================

* :ref:`search`
