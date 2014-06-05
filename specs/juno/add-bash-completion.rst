..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================================
Add bash completion for command line
==========================================

https://blueprints.launchpad.net/python-glanceclient/+spec/add-bash-completion

Currently glance client does not support command completion.
The intention is to add this functionality to the client.

Problem description
===================

Nowadays glance client does not have bash completion for the command line.
This feature will improve the client usability.

Proposed change
===============

Incorporation of bash completion feature.
This feature uses the linux script called bash_completion.d to 
request all the commands and parameters to Glance through 
bash_completion command. After obtaining them, they are filtered 
and shown. 

Example of use:

glance <tab><tab> ---> shows all the commands

glance image- <tab><tab> ---> shows all the commands starting with the
word ‘image’: image-list, image-show, image-create… 

If there is only one, it will be completed.

glance image-create <tab><tab> ---> shows all optional arguments

To complete this feature, it is needed to modify devstack and the packaging
tool in order to include this script in the installer (deb, rpm).


Alternatives
------------

None

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

None

Other deployer impact
---------------------

This change needs copying of the glance.bash_completion to specific
system path:

* This will affect devstack

* This will affect specific packaging (deb, rpm)

Developer impact
----------------

Commands and Parameters are extracted directly from argparse.
Developers won't need to maintain a separate list when they add new
commands or parameters.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  <juan-m-olle>

Work Items
----------

This feature needs:

* To add glance.bash_completion script

* To add bash_completion command to glance client. This new command
  returns all available commands the client has and it is used by
  glance.bash_completion.

Dependencies
============

None

Testing
=======

Unit test will check new shell command functionality.

Documentation Impact
====================

New feature needs to be mentioned.

References
==========

None
