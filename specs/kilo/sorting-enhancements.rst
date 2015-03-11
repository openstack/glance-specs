..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

Glance sorting enhancements
===========================

https://blueprints.launchpad.net/glance/+spec/glance-sorting-enhancements

Currently, the sorting support for Glance allows the caller to specify
multiple sort keys and one sort direction. This blueprint enhances the
sorting support for the /images and /images/detail APIs so that
multiple sort keys and sort directions can be supplied on the request.


Problem description
~~~~~~~~~~~~~~~~~~~

There is no support for retrieving image data based on multiple sort
directions; multiple sort keys and one direction are currently
supported, and they're defaulted to descending sort order by the
"created_at" key.

In order to retrieve data in any sort order and direction, the REST
APIs need to accept multiple sort keys and directions.

Use Case: A UI that displays a table with only the page of data that it
has retrieved from the server. The items in this table need to be sorted
by status first and by display name second. In order to retrieve data in
this order, the APIs must accept multiple sort keys/directions.


Proposed change
~~~~~~~~~~~~~~~~~~~

The /images and /images/detail APIs will align with the API working group
guidelines [1]_ for sorting and support the following parameter on the
request:

* sort: Comma-separated list of sort keys, each key is optionally appended
  with <:dir>, where 'dir' is the direction for the corresponding sort key
  (supported values are 'asc' for ascending and 'desc' for descending).

For example::

  /images?sort=status:asc,name:asc,created_at:desc

Note: The "created_at" and "id" sort keys are always appended at the end of
the key list if they are not already specified in the request.

The database layer already supports multiple sort keys and directions. This
blueprint will update the API layer to retrieve the sort information from
the API request and pass that information down to the database layer.

All sorting is handled in the glance.db.sqlalchemy.api._paginate_query
function. This function accepts an ORM model class as an argument and the
only valid sort keys are attributes on the given model class. Therefore,
the valid sort keys are: 'name', 'status', 'container_format', 'disk_format',
'size', 'id', 'created_at', 'updated_at'.

Alternatives
------------

Multiple sort keys and directions could be passed using repeated 'sort_key'
and 'sort_dir' query parameters. For example::

  /images?sort_key=status&sort_dir=asc&sort_key=name&sort_dir=asc&
  sort_key=created_at&sort_dir=desc

To provide users with the ability to use the classic familiar syntax and to
ensure a smoother transition to the new one, classic syntax should be
implemented too.

Data model impact
-----------------

None

REST API impact
---------------

The following existing v2 GET APIs will support the new sorting parameters:

* /v2/images
* /v2/images/detail

Note that the design described in this blueprint could be applied to other GET
REST APIs, but this blueprint is scoped to only those listed above. Once this
design is finalized, then the same approach could be applied to other APIs.

The existing API documentation needs to be updated to include the following
new Request Parameters:

+-----------+-------+--------+------------------------------------------------+
| Parameter | Style | Type   | Description                                    |
+===========+=======+========+================================================+
| sort      | query | string | Comma-separated list of sort keys and optional |
|           |       |        | sort directions in the form of key<:dir>,      |
|           |       |        | where 'dir' is either 'asc' for ascending      |
|           |       |        | order or 'desc' for descending order. Defaults |
|           |       |        | to the 'created_at' and 'id' keys in           |
|           |       |        | descending order.                              |
+-----------+-------+--------+------------------------------------------------+

Currently, the images query supports the 'sort_key' and 'sort_dir' parameters;
these will be deprecated. The API will raise a "BadRequest" error response
(code 400) if both the new 'sort' parameter and a deprecated 'sort_key' or
'sort_dir' parameter is specified.

Neither the API response format nor the return codes will be modified, only
the order of the images that are returned.

In the event that an invalid sort key or sort direction is specified, then a
"BadRequest" error response (code 400) will be returned with a message like
"Invalid input received: Invalid sort key" or "Invalid input received: Invalid
sort dir" respectively.

Security impact
---------------

None

Notifications impact
--------------------

None

Other end user impact
---------------------

The python-glanceclient should be updated to accept sort keys and
sort directions, using the 'sort' parameter being proposed in the
cross-project spec [2]_.

Performance Impact
------------------

None

Other deployer impact
---------------------

The choice of sort keys has no impact on data retrieval performance.
Therefore, the user should be allowed to retrieve data in whatever
order they need to for creating their views (see use case in the
Problem Description).

Developer impact
----------------

None


Implementation
~~~~~~~~~~~~~~

Assignee(s)
-----------

Primary assignee:
  mfedosin

Other contributors:
  None

Reviewers
---------

ativelkov

icordasc

nikhil-komawar

Work Items
----------

Ideally the logic for processing the sort parameters would be common to all
components and would be done in oslo; a similar blueprint is also being
proposed in nova:
https://blueprints.launchpad.net/nova/+spec/nova-pagination

Therefore, I see the following work items:

* Update the existing API to retrieve the sort information and pass down to
  the DB layer (https://review.openstack.org/#/c/148326/);
* Extend API with new syntax to support multiple sorting keys and directions
  (https://review.openstack.org/#/c/148512/);
* Update the python-glanceclient to accept and process multiple sort keys and
  sort directions with classic and new sorting syntax
  (https://review.openstack.org/#/c/120777/,
  https://review.openstack.org/#/c/148688/,
  https://review.openstack.org/#/c/148981/);
* Implement the full test coverage for the new changes.


Dependencies
~~~~~~~~~~~~

* CLI Sorting Argument Guidelines cross project spec [2]_;

* Related (but independent) change being proposed in nova [3]_.


Testing
~~~~~~~

Both unit and Tempest tests need to be created to ensure that the data is
retrieved in the specified sort order. Tests should also verify that the
default sort keys ("created_at" and "id") are always appended to the user
supplied keys (if the user did not already specify them).


Documentation Impact
~~~~~~~~~~~~~~~~~~~~

The /images and /images/detail API documentation will need to be updated
to:

- reflect the new sorting parameters and explain that these parameters will
  affect the order in which the data is returned.
- explain how the default sort keys will always be added at the end of the
  sort key list.


References
~~~~~~~~~~

.. [1]

  `API Working group sorting guidelines <https://github.com/openstack/
  api-wg/blob/master/guidelines/pagination_filter_sort.rst>`_

.. [2]

  `CLI Sorting Argument Guidelines <http://specs.openstack.org/openstack/
  openstack-specs/specs/cli-sorting-args.html>`_

.. [3]

  `Related change being proposed in nova <https://blueprints.launchpad.net/
  nova/+spec/nova-pagination>`_
