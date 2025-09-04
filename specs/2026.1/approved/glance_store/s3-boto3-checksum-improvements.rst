..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==============================================
S3 Store Boto3 Checksum Behavior Configuration
==============================================

https://blueprints.launchpad.net/glance-store/+spec/s3-boto3-checksum-improvements

Add config options to control boto3 S3 checksum behavior. This fix problems 
with S3-compatible storage that came with boto3 1.36.x. Operators can now keep 
using old S3-compatible storage and also use new AWS S3 data integrity features.

Problem description
===================

Boto3 1.36.0 added new S3 "data integrity" protections that run by default. 
This means boto3 now calculates checksums for requests and validates checksums 
in responses. This is good for data integrity but many S3-compatible storage 
systems do not support this yet. For example, Ceph RGW does not work with 
these new features.

This breaks Glance image uploads to S3-compatible storage. Users see errors 
like this:

::

   botocore.exceptions.ClientError: An error occurred (MissingContentLength) 
   when calling the PutObject operation: The internal error code is -2011

This problem is in Launchpad bug #2121144. Users who upgrade from Dalmatian 
to Epoxy see this problem because boto3 upgraded from 1.35.x to 1.36.x.

Current workaround is to set environment variables:

::

   export AWS_REQUEST_CHECKSUM_CALCULATION=WHEN_REQUIRED
   export AWS_RESPONSE_CHECKSUM_VALIDATION=WHEN_REQUIRED

But this is not good because it affects all boto3 usage in the system, not 
only Glance. This is not good for production with different storage backends.

Proposed change
===============

Add three new config options to S3 store driver to control boto3 checksum 
behavior:

1. s3_store_enable_data_integrity_protection (boolean, default: false)
   - Turn on/off boto3 data integrity features
   - When false: Use 'when_required' behavior for compatibility
   - When true: Use the configured checksum settings

2. s3_store_request_checksum_calculation (string, default: 'when_required')
   - Control when boto3 calculates request checksums
   - Options: 'when_required', 'always', 'never'

3. s3_store_response_checksum_validation (string, default: 'when_required')
   - Control when boto3 validates response checksums
   - Options: 'when_required', 'always', 'never'

We will change the _create_s3_client method in S3 store driver to use these 
config options when creating boto3 S3 client.

Alternatives
------------

1. Environment Variables: Current workaround with environment variables is 
   not good for production because it affects all boto3 usage globally.

2. Boto3 Version Pinning: Downgrade boto3 version will lose other improvements 
   and security fixes in newer versions.

3. Storage Backend Detection: Automatically detect S3-compatible vs AWS S3 
   is not reliable and has many errors.

Config-based approach gives most flexibility and control. It also keeps 
backward compatibility.

Data model impact
-----------------

None

REST API impact
---------------

None

Security impact
---------------

This change is good for security. Operators can enable better data integrity 
protection for AWS S3 deployments. At same time, they can keep compatibility 
with S3-compatible storage backends. Default behavior keeps current security 
for existing deployments.

Notifications impact
--------------------

None

Other end user impact
---------------------

None

Performance Impact
------------------

Change has very small performance impact:

* When data integrity protection is disabled (default), performance is same 
  as current behavior
* When enabled, there is small overhead from checksum calculation and 
  validation, but this gives better data integrity

Other deployer impact
---------------------

This change works immediately after merge. For existing deployments:

* No changes required - Default behavior works with existing S3-compatible 
  storage backends
* For AWS S3 deployments wanting better data integrity: Set 
  s3_store_enable_data_integrity_protection = true and configure checksum 
  behavior
* For mixed environments: Use different backends with different configs

Developer impact
----------------

This change adds new config options to S3 store driver and changes client 
creation logic. Other developers working on Glance store drivers should know 
about this new config pattern for handling boto3 compatibility problems.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  abhishekk

Other contributors:
  None

Work Items
----------

1. Add new config options to S3 store driver and use them in client creation 
   logic
2. Add unit tests for all configuration scenarios
3. Add multistore tests for different backend configurations
4. Update s3 documentation

Dependencies
============

* This change needs boto3 1.36.x or later for the new checksum config options
* No new library dependencies needed

Testing
=======

Add unit and tempest tests to cover all configuration scenarios.

Documentation Impact
====================

Update configuration reference documentation to explain the new S3 store 
config options. Add configuration examples and migration guidance to help 
operators understand how to configure these options for their use cases.

References
==========

* Launchpad Bug #2121144: Image uploads to S3-compatible storage fail with 
  Epoxy version
* boto3 Issue #4392: S3 data integrity protections enabled by default
* boto3 Issue #4398: Guidance on checksum behavior configuration
