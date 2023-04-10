========================
Team and repository tags
========================

.. image:: https://governance.openstack.org/tc/badges/glance-specs.svg
    :target: https://governance.openstack.org/tc/reference/tags/index.html
    :alt: The following tags have been asserted for the Glance Specifications
          repository:
          "project:official".
          Follow the link for an explanation of these tags.
.. NOTE(rosmaita): the alt text above will have to be updated when
   additional tags are asserted for glance-specs.  (The SVG in the
   governance repo is updated automatically.)

.. Change things from this point on

===============================
OpenStack Glance Specifications
===============================

This git repository is used to hold approved design specifications for additions
to the Glance project. Reviews of the specs are done in gerrit, using a
similar workflow to how we review and merge changes to the code itself.

The general layout of this repository is::

  specs/<release>/

You can find an example spec in `specs/template.rst`.

Beginning with the Mitaka release, there is a further subdivision into::

  specs/<release>/approved
  specs/<release>/implemented

A specification is proposed for a given release by adding it to the
`specs/<release>/approved` directory and posting it for review.  The
implementation status of a blueprint for a given release can be found by
looking at the blueprint in launchpad.  Not all approved blueprints will get
fully implemented.

When a feature has been completed, its specification will be moved to the
'implemented' directory for the release in which it was implemented.

Specifications have to be re-proposed for every release.  The review may be
quick, but even if something was previously approved, it should be re-reviewed
to make sure it still makes sense as written.

Prior to the Juno development cycle, this repository was not used for spec
reviews.  Reviews prior to Juno were completed entirely through Launchpad
blueprints::

  https://blueprints.launchpad.net/glance

Please note, Launchpad blueprints are still used for tracking the
current status of blueprints. For more information, see::

  https://wiki.openstack.org/wiki/Blueprints

For more information about working with gerrit, see::

  https://docs.openstack.org/infra/manual/developers.html#development-workflow

To validate that the specification is syntactically correct (i.e. get more
confidence in the Jenkins result), please execute the following command::

  $ tox

After running ``tox``, the documentation will be available for viewing in HTML
format in the ``doc/build/`` directory. Please do not checkin the generated
HTML files as a part of your commit.

At the start of a new cycle, the right files and directories can be created and modified using the following command:

  $ tox -eprepare-next-cycle <cycle>

For instance:

  $ tox -eprepare-next-cycle 2023.2

The changes should then be reviewed and committed manually.