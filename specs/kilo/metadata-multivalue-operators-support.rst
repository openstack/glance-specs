..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

====================================================
Support for multivalue operators in metadata catalog
====================================================
https://blueprints.launchpad.net/glance/+spec/metadata-multivalue-operators-support

The metadata catalog provides data that user can pin to resources,
e.g., flavors extra specs. These are used by scheduler to choose a host that
satisfies the requirements provided in extra specs. Nova scheduler implements
operators to combine multiple values under one key in extra specs: ``<or>``
and ``<all-in>``. Unfortunately, the catalog does not provide which operator
is suitable for a given property.

This blueprint aims at this problem by extending current jsons with suitable
operators for each property.


Problem description
===================
There is work being done in Horizon to provide support for multiple values
for a single key in extra specs, however, Glance currently does not provide
information about which operators are suitable for a given property.
In ``compute-host-capabilities.json`` there is a property called
``cpu_info:features``. Both operators - ``<all-in>`` and ``<or>`` can be used
for this property. There are also properties like ``cpu_info:model``
where ``<or>`` is the only operator that should work.


Proposed change
===============
To make end-user (e.g. Horizon) aware which operator can be used for a given
property, this blueprint extends existing properties (and also properties
inside objects) with a new section under key - "operators":

Currently an example property would be structured like this::

    "cpu_info:features": {
        "title": "Features",
        "description": "Specifies CPU flags/features.",
        "type": "array",
        "items": {
            "type": "string",
            "enum": [
                "aes",
                "vme",
                "de"
            ]
        }
    }

And after extension::

    "cpu_info:features": {
        "title": "Features",
        "description": "Specifies CPU flags/features.",
        "operators": [
            "<or>",
            "<all-in>"
        ],
        "type": "array",
        "items": {
            "type": "string",
            "enum": [
                "aes",
                "vme",
                "de"
            ]
        }
    }

The added section is::

    "operators": [
        "<or>",
        "<all-in>"
    ]

This section will be optional, e.g., property that is integer does
not need operator.

Also glance will not do any check on "operators" field. API consumer
needs to take care to provide valid operators for nova scheduler. Currently
there are three operators that are valid for nova scheduler and are usable
with metadata definitions: ``<or>``, ``<in>`` and ``<all-in>``

Alternatives
------------
None

Data model impact
-----------------
This will not impact data model, because "operators" will be part
of the blob stored in the ``json_schema`` column in the database table.

REST API impact
---------------
Example extended GET object body::

    {
        "objects": [
            {
                "name": "object1",
                "namespace": "my-namespace",
                "description": "my-description",
                "properties": {
                    "prop1": {
                        "title": "My Property",
                        "description": "More info here",
                        "operators": ["<all-in>"],
                        "type": "string",
                        "readonly": true
                    }
                }
            }
        ],
        "first": "/v2/metadefs/objects?limit=1",
        "next": "/v2/metadefs/objects?marker=object1&limit=1",
        "schema": "/v2/schema/metadefs/objects"
    }

Example POST/PUT body on objects::

    {
        "name": "StorageQOS",
        "description": "Our available storage QOS.",
        "required": [
            "MyProperty"
        ],
        "properties": {
            "MyProperty": {
                "type": "string",
                "readonly": false,
                "description": "The My Property",
                "operators": ["<or>"],
                "enum": ["type1", "type2"]
            }
        }
    }

Because "operators" field is optional API consumer needs to handle default
value as it may be missing.

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
Upgrade of jsons or database in existing OpenStack installation will not
be needed. "operators" section will not be mandatory so the installation
can keep running without upgrade.

Also there is possibility that property/object will be missing operators even
when the value has been added in the latest built-in metadata definition json
templates, the upgrade process does not update existing database. Deployer
needs to manually upgrade metadata definitions to the newest set.

Developer impact
----------------
None


Implementation
==============

Assignee(s)
-----------
Primary assignee:
  pawel-koniszewski

Other contributors:
  None

Reviewers
---------
Core reviewer(s):
  lzy-dev

Work Items
----------
* Extend existing metadata jsons with operators section.
* Extend API json schema with new option


Dependencies
============
Horizon blueprint that depends on this blueprint:
https://blueprints.launchpad.net/horizon/+spec/metadata-widget-multivalue-selection

Nova blueprint that this blueprint depends on:
https://blueprints.launchpad.net/nova/+spec/add-all-in-list-operator-to-extra-spec-ops


Testing
=======
Current unit tests and functional tests will be extended to make sure
that the new section is returned and that it is correct. Tests will also
ensure that the operators part is optional.


Documentation Impact
====================
The new attribute needs to be documented.


References
==========
None

