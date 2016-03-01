..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==================================
Add filters using an 'in' operator
==================================

https://blueprints.launchpad.net/glance/+spec/in-filtering-operator

This specification introduces a feature to the Glance v2 API for filtering
images based on lists of ``id``, ``name``, ``status``, ``container_format`` or
``disk_format`` using the 'in' operator.
This feature is important because it allows Horizon to make only one request
to Glance instead of multiple single requests, which improves the system
performance and reduces the load.

Problem description
~~~~~~~~~~~~~~~~~~~

Horizon sends separate requests to get the names of the images presented in
the ID forms of the instances.
It would be better to send one request instead of a lot of separate requests.

Proposed change
~~~~~~~~~~~~~~~

I propose adding the ability to filter images by the properties ``id``,
``name``, ``status``,``container_format``, ``disk_format`` using the 'in'
operator between the values.

Alternatives
------------

Alternative is implement this type of query to the Searchlight service. But
Searchlight is an optional service, and Horizon is always required the listing
of running instances.

Also this particular functionality, the "in" operator, should still be added
for the following reasons:
* consistency with Glare, which has implemented the "in" operator;
* there's a minimum set of filters that should be allowed for effective
service-to-service communication.

Thus while try searching for UIs should be offloaded to Searchlight, this
particular functionality is basic and useful enough that it's worth including
in the API.

Data model impact
-----------------

None

REST API impact
---------------

Following the pattern of existing filters, new filters may be specified as
query parameters using the field to filter as the key and the filter criteria
as the value in the parameter.

Filtering based on the principle of full compliance with the template,
for example 'name = in:deb' does not match 'debian'.

Changes apply exclusively to the API v2 Image entity listings::

  GET /v2/images/{image\_id}

Filter by adding optional query parameters::

  id, name, status, disk_format, container_format

An example of an acceptance criteria using the 'in' operator for name::

  ?name=in:name1,name2,name3

These filters will be added using syntax that conforms to the latest
guidelines from the OpenStack API Working Group and any applicable draft
guidelines [1]_.

Example::

  GET /v2/images?name=in:name1,name2
  {
      "first": "/v2/images?name=in:name1,name2",
      "images": [
          {
              "checksum": null,
              "container_format": "bare",
              "created_at": "2015-12-18T12:02:09Z",
              "disk_format": "raw",
              "file": "/v2/images/381b6dfb-48c2-4fcd-860d-9c7b10876730/file",
              "id": "381b6dfb-48c2-4fcd-860d-9c7b10876730",
              "min_disk": 0,
              "min_ram": 0,
              "name": "name1",
              "owner": "a03febe481094927a96fe367c15c347b",
              "protected": false,
              "schema": "/v2/schemas/image",
              "self": "/v2/images/381b6dfb-48c2-4fcd-860d-9c7b10876730",
              "size": null,
              "status": "queued",
              "tags": [],
              "updated_at": "2015-12-18T12:02:09Z",
              "virtual_size": null,
              "visibility": "private"
          },
          {
              "checksum": null,
              "container_format": "bare",
              "created_at": "2015-12-18T12:02:15Z",
              "disk_format": "raw",
              "file": "/v2/images/a3b9db48-5b6f-40e5-9cc1-d586f01281cc/file",
              "id": "a3b9db48-5b6f-40e5-9cc1-d586f01281cc",
              "min_disk": 0,
              "min_ram": 0,
              "name": "name2",
              "owner": "a03febe481094927a96fe367c15c347b",
              "protected": false,
              "schema": "/v2/schemas/image",
              "self": "/v2/images/a3b9db48-5b6f-40e5-9cc1-d586f01281cc",
              "size": null,
              "status": "queued",
              "tags": [],
              "updated_at": "2015-12-18T12:02:15Z",
              "virtual_size": null,
              "visibility": "private"
          }
      ],
      "schema": "/v2/schemas/images"
  }

Max page size will still be enforced. For example if the max page size is 3
and I do request 'id=in:1,2,3,4' - I only get 3 images and a link to get
the fourth.

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

Performance tests were conducted.
We determined the time spent in obtaining the list of images, filtering and
repeating the ``image-get`` query. The results are presented in [2]_:

* Blue line - used repeating the request.
* Red line - used a filter.

Test code is presented in [3]_.

Other deployer impact
---------------------

None

Developer impact
----------------

None


Implementation
~~~~~~~~~~~~~~

Assignee(s)
-----------

Primary assignee:
  dshakhray

Other contributors:
  None

Reviewers
---------

mfedosin
jokke

Work Items
----------

None

Dependencies
~~~~~~~~~~~~

None

Testing
~~~~~~~

Unit and functional tests will be added as appropriate.

Documentation Impact
~~~~~~~~~~~~~~~~~~~~

Docs should be updated with a description of new API filters and usage, as
well as of the additional policy options.


References
~~~~~~~~~~

.. [1]

  `API Working Group filtering guidelines <http://specs.openstack.org/
  openstack/api-wg/guidelines/pagination_filter_sort.html>`_

.. [2]

  `Result of perfomance test <http://pixs.ru/showimage/yotxru1png_2430090_19659184.png>`_

.. [3]

  `Script for performance tests <http://paste.openstack.org/show/480210/>`_
