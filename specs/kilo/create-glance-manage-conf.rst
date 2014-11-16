..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

============================================
Create and Use ``glance-manage`` config file
============================================

https://blueprints.launchpad.net/glance/+spec/create-glance-manage-conf

``glance-manage`` currently uses the configuration files meant for
``glance-registry`` and ``glance-api``. This was ostensibly done to reduce the
number of places that an operator may need to add, update, or remove settings.
I would like to create a ``glance-manage.conf`` file to allow
``glance-manage`` to be independently configured.

Problem description
===================

If ``glance-api`` is started by a user (or service) but a different user tries
to use ``glance-manage`` they can encounter permissions errors if
``/var/log/glance/api.log`` is not writable to by the user trying to use
``glance-manage``. While this is one symptom of the dependence on the registry
and api configuration files, more may soon appear. Further, having separate
configuration files will allow end users and deployers to configure the tools
separately as well as use ``glance-manage`` on a node without requiring the
presence of both ``glance-api.conf`` and ``glance-registry.conf``.

See also `bug 1391211`_.

Proposed change
===============

I am proposing that we add another configuration file, ``glance-manage.conf``
to side-step this and any other issues we have with depending on the registry
and api's configuration files.

For Kilo, we will add the ``glance-manage.conf`` file and continue to load the
``glance-registry.conf`` and ``glance-api.conf`` files in the
``glance-manage`` command setup step. Currently the load order of
configuration files (which causes ``glance-manage`` to use
``/var/log/glance/api.log``) is:

- ``glance-registry.conf``

- ``glance-api.conf``

We will preserve this order and then load ``glance-manage.conf``. We will only
default to setting ``log_file`` in ``glance-manage.conf`` to prevent
overriding settings from the other two files. We will also issue a deprecation
warning pointing to this specification so that operators and end users know to
configure ``glance-manage.conf`` for the L cycle. In the L cycle, we will stop
depending on ``glance-registry.conf`` and ``glance-api.conf``. The
documentation should also immediately, starting in the K cycle, begin to
instruct users to configure settings for ``glance-manage`` in
``glance-manage.conf``.


Alternatives
------------

One way we could address this would be to remove the default ``log_file``
values in Glance's configuration files. If we did this, all log files would
then be named ``/var/log/{{service}}/{{ command }}.log``, e.g.,
``/var/log/glance/glance-api.log`` would be the file used by ``glance-api``.
Changing this would not only break current documentation but also end user
expectations. Due to the considerable difference in behaviour without prior
warning, we decided to take the approach outlined in this specification
instead of using the same conventions as other projects.

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

This would introduce another file that would need to be edited by end users.
Some settings configured in ``glance-manage.conf`` may also be present in
``glance-registry.conf`` and ``glance-api.conf``. Any potential security
problems caused by needing to copy and synchronize settings between three
files are applicable here. Alternatively, since ``glance-manage`` can be
configured separately now, there will be no need to have the full API and
registry configuration files on a node in order to run ``glance-manage``.

Notifications impact
--------------------

None

Other end user impact
---------------------

This introduces another file with configuration options. Common configuration
options for will need to be copied and pasted from file-to-file and will need
attention to keep synchronized. This will likely increase the complexity of
maintaining an installation of Glance.

Performance Impact
------------------

None

Other deployer impact
---------------------

Deployers will be able to run ``glance-manage`` from nodes without needing
``glance-registry.conf`` or ``glance-api.conf`` to be present. This
specification does introduce another file that deployers need to be aware of
and know how to configure.

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  icordasc

Other contributors:
  None

Reviewers
---------

Core reviewer(s):
  nikhil-komawar

Other reviewer(s):
  kragniz
  jokke\_

Work Items
----------

- Generate a default ``glance-manage.conf`` as described above

- Begin loading it in ``glance-manage``

- Add deprecation messages regarding ``glance-registry.conf`` and
  ``glance-api.conf``.

- Update the documentation to describe how to configure ``glance-manage`` with
  ``glance-manage.conf``.


Dependencies
============

None


Testing
=======

We can test this by ensuring that a separate log file is generated for
``glance-manage``, i.e., ``/var/log/glance/manage.log`` is present after
running the command.


Documentation Impact
====================

This will require the changes to describe how to configure ``glance-manage``
to continue working as it has in the past.


References
==========

* https://bugs.launchpad.net/glance/+bug/1391211

.. _bug 1391211: https://bugs.launchpad.net/glance/+bug/1391211
