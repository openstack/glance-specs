..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=======================================================================
Provision to append the new metadef-tags with the existing metadef-tags
=======================================================================

https://blueprints.launchpad.net/glance/+spec/append-tags

In the Glance API we are not having the provision to append the new metadef-tags
with the existing metadef-tags. Introducing a new optional parameter would help
the user to select whether to append the tags or to go with current behaviour i.e.
overwrite the existing tags.

Problem description
===================

Our md-tag-create-multiple (POST /v2/metadefs/namespaces/{namespace_name}/tags) API
overwrites existing tags for specified namespace rather than creating new one in
addition to the existing tags. Whereas if you try to create different tags using
md-tag-create (POST /v2/metadefs/namespaces/{namespace_name}/tags/{tag_name}) it is
adding new tag in addition to existing ones.
So we should have consistency between the two APIs i.e. the ability to append
the tags in md-tag-create-multiple API.

Proposed change
===============

At the moment the glance API only overwrites the existing tags with the
newly created tags i.e. the original/default behaviour. The new behaviour suggests
to append the new tags with the existing ones.
The goal is to provide an optional header ``X-Openstack-Append`` that takes boolean
values, which will default to the original behaviour. If not present, the behavior is
the same as passing ``X-Openstack-Append: False``.

If header is present then we are going to append new tags else keep the old behavior.

In addition to this we will add an optional parameter at glanceclient side
which will default to the original behaviour and if the user wants to append the
new tags it can be by changing the value of parameter to True.

Alternatives
------------

None

Data model impact
-----------------

None

REST API impact
---------------

We are going to change the API and will be adding a ``X-Openstack-Append`` in the header.
The rest API look like this:

.. code-block:: console

  POST /v2/metadefs/namespaces/{namespace_name}/tags

Header fields::

  X-Openstack-Append

* The <boolean> 'X-Openstack-Append' is an optional header, refers to appending the tags
  to the existing tags.
  It takes boolean values if True then it will append the tags ,if False it will
  overwrite the tags, default value is False.

Example curl usage::

   curl -i -X POST -H "X-Auth-Token: $token" -H "X-Openstack-Append: False"
   -H "Content-Type: application/json"
   -d '{"tags": [{"name": "sample1"}, {"name": "sample2"}]}'
    $image_url/v2/metadefs/namespaces/{namespace_name}/tags

Security impact
---------------

None

Notifications impact
--------------------

None

Other end user impact
---------------------

We will add an optional parameter ``--append`` to the glanceclient command
md-tag-create-multiple to provide the facility of appending the tags.
If the parameter is present then it will the append the tags to existing ones
else will overwrite the existing tags.

* Create multiple tags: ``glance md-tag-create-multiple <NAMESPACE> --names <NAMES> [--delim <DELIM>] --append``

Performance Impact
------------------

None

Other deployer impact
---------------------

None

Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  mrjoshi

Other contributors:
  None

Work Items
----------

* Add a boolean parameter in the header and change API
  functionality as per parameter's value
* Add an optional parameter ``--append`` at the client side
* Add unit test coverage for checking the functionality.
* Add tempest test

Dependencies
============

None

Testing
=======

We will provide unit tests coverage for testing the
functionality based on the header.

Documentation Impact
====================

The documentation needs to be updated with the new API behaviour.

References
==========

https://bugs.launchpad.net/glance/+bug/1939169

https://review.opendev.org/c/openstack/glance/+/804966
https://review.opendev.org/c/openstack/python-glanceclient/+/813591
