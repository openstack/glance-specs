..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=========================================
Add 'protected' filter to image-list call
=========================================

https://blueprints.launchpad.net/glance/+spec/add-protected-filter

Images contain a boolean 'protected' field.  Filtering on this field in the
image-list request is not currently supported.  Operators and users who make
use of the 'protected' field to prevent accidental deletion of images, however,
would find such filtering useful.  Not supporting filtering on this field is
counterintuitive as Glance supports filtering on all other image fields.


Problem description
===================

Use cases:

* An End User wants to list protected images that are accessible to that end
  user.

* An End User wants to list non-protected images that are accessible to that
  end user.


Proposed change
===============

Add code so that when 'protected=<value>' is included in a query string on the
image-list call, the value is converted to a boolean, making it suitable
for database filtering (the 'protected' field is a boolean in the database
backend).

For a user experience consistent with the image-create and image-update calls,
the only accepted values for this parameter will be 'true' or 'false' in that
exact case combination.  Any other value for this parameter should return a 400
to indicate a bad request.

To summarize:

1. Introduce a new query parameter to the ``GET v2/images`` call, namely,
   ``protected``.

2. The parameter will act as a filter on the 'protected' field of an Image.

3. The set of values for the parameter will be strict, that is, the call will
   accept only those strings that satisfy the JSON boolean data type (in other
   words, only 'true' or 'false' in that exact case combination).

4. Unrecognized values will result in a 400 (Bad Request) response with an
   appropriate message.

5. When the ``protected`` query parameter is not present, no filtering will be
   done on the 'protected' field of Images.  (In other words, there's no
   default value.)

Alternatives
------------

1. Do nothing.  This isn't really an option, because even though 'protected' is
   not currently supported as a filter, image-list calls passing a value for
   'protected' in the query string are accepted and do have an effect (the
   API behaves as if ``protected=False`` has been specified).  This behavior
   appears weird to end users.

2. Implement the filter, but accept a liberal set of values, recognizing, for
   example, 'true' or 'false' in any case combination; 'yes' or 'no' in any
   case combination; and 1 or 0.  This can be accomplished by using the oslo
   string utilities, which contains a function ``bool_from_string`` that
   converts strings to an appropriate boolean value [APF-1]_.  Using the oslo
   library has an additional bonus in that the usage will be consistent across
   other OpenStack projects.

   The downside to this alternative is that it is inconsistent with the
   image-create and image-update calls in the Images v2 API.  The latter calls
   are governed by the Image json-schema, which clearly specifies a JSON
   boolean type as the value of the ``protected`` field, and hence only 'true'
   or 'false' in that exact case combination is what these calls accept.  Thus,
   liberal acceptance of commonly regarded boolean values in the query string
   may cause API users to be surprised when these liberal values don't work for
   image-create or image-update, leading to user dissatisfaction.

3. Implement the filter, but be extremely lax, that is, any value that isn't
   mapped to the boolean value True by the oslo ``bool_from_string`` function
   would be considered False.  This actually isn't very user friendly.  For
   example, a French language speaker applying the query filter 'protected=oui'
   will receive the complement of what was requested.

Data model impact
-----------------

None

REST API impact
---------------

This is a very minor modification to the ``GET v2/images`` call.  The
only changes are:

  * Parameters which can be passed via the URL now include ``protected``.

Security impact
---------------

None.

Notifications impact
--------------------

None.

Other end user impact
---------------------

The only impact on python-glanceclient is that the command

``glance image-list --property protected=true``

will now work correctly.

Performance Impact
------------------

None.

Other deployer impact
---------------------

None.

Developer impact
----------------

None.

Implementation
==============

Assignee(s)
-----------

Primary assignee:

- fengzhr

Other contributors:

- rosmaita
- dharinic

Work Items
----------

* Implement the change roughly along the lines of
  https://review.openstack.org/#/c/449108/

* Update the api-ref

* Write a release note

Dependencies
============

None.


Testing
=======

Functional tests consistent with the current image-list filtering tests.

Documentation Impact
====================

Small addition to the v2 image-list documentation in the api-ref.

References
==========

.. [APF-1] http://git.openstack.org/cgit/openstack/oslo.utils/tree/oslo_utils/strutils.py
