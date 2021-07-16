..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

====================================
Spec Lite: Remove sqlalchemy-migrate
====================================

..
  Mandatory sections

:project: glance

:problem: The sqlalchemy-migrate library is unmaintained and has been
          deprecated in favour of alembic. It is not compatible with sqlalchemy
          2.0 and is issuing many warnings suggesting Python 3.10 compatibility
          may be in doubt. Glance switched to alembic for new migrations during
          the Ocata cycle and no longer needs to carry the old
          sqlalchemy-migrate-based migrations.

:solution: Remove the sqlalchemy-migrate-based migrations and related tooling.

:impacts: None. Users coming from a pre-Ocata deployment will need to deploy a
          pre-Xena glance before deploying Xena, but that's standard practice
          anyway.

..
  Optional sections -- delete any that don't apply to this spec lite

:timeline: Xena milestone 3

:link: https://review.opendev.org/c/openstack/glance/+/760411

:assignee: stephenfin
