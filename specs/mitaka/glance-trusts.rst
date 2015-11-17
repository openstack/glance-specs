..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===========================
Implement trusts for Glance
===========================

https://blueprints.launchpad.net/glance/+spec/trust-authentication

This change proposal introduces a way for Glance to use Keystone trust
authorization.

Problem description
===================

Keystone tokens have some restricted lifetime. After the user token has
expired, any request initiated by Glance which needs a valid user token will
fail. This causes the original user's request to also fail, even though the
token was originally valid when passed to Glance.

This this spec intends to address the specific case where a token expires
during image upload causing the call to the registry to set the image
state 'active' to fail:

1. User requests image-upload.
2. Keystone Middleware accepts the request and passes the request to Glance.
3. Glance passes all required data to glance_store.
4. glance_store uploads an image but it takes a lot of time (more than token expiration time)
5. Glance sends a request to registry to change image status.
6. Keystone Middleware rejects the request because user token has expired.

As a result the image never transitions to 'active' status and so isn't usable.

Increasing the token expiration time doesn't seem to be a good long-term solution.

.. note::

   This implementation of trusts in glance_store is out of scope for this
   specification. The current spec is related to Glance and it defines trusts
   implementation for communication with Glance Registry.

.. note::

   Nova snapshots also suffer from a token expiration issue. Nova first creates
   a queued image before saving the instance state to local disk. Then the
   image bytes are uploaded. Potentially the token can expire while the instance
   state is being saved to disk. This spec will not address this case.

Proposed change
===============

The proposal changes the Glance behavior when uploading images in Glance v2 api with enabled
Registry server, i.e. when data_api = glance.db.registry.api.

Step 1. Glance received request for image-upload.

Step 2. Before upload begins Glance tries to create a trust with the following parameters:

* token: user token
* project: user project
* roles: all user roles
* trustee_user: system user that specified in CONF.keystone_authtoken configuration group
* trustor_user: user who initiated the request.

Glance keeps trust_id until request processing is finished. If trust cannot be
created because of some reason then Glance uses user token for further steps.

Step 3. Glance initiates and completes the image upload (this part is executed
by glance_store).

Before starting step 4 Glance has an image uploaded to store and it needs
to update the image record in database. That requires the user token to be valid for V2
API if data_api is Glance Registry.

Step 4. If authentication is required (see the text above) then Glance requests
the new token using the trust_id (see Step 2). Glance updates the request
context with the new token.

Step 5. Glance updates image record in database. If Registry is used then
it receives the new token.

Alternatives
------------

At least one workaround for the whole functionality is available: extend token
expiration time to allow Glance upload the image. This solution affects all
services and it does not look like long term solution.

There has been some discussion around updating how the keystone middleware
interprets a combination of a valid service token and expired user token -- but
this is in the discussion/pre-design stage and is not guaranteed to be
implemented. Therefore we cannot currently base our solution on it, and it's
recommended to use trusts. In the future this may be superseded by the use
of service tokens but it'll have to be discussed when that time comes.

Earlier there was a config option, called 'use_user_token'. If it's disabled glance
extracted user token from the context and changed it to admin's. Unfortunately,
this option was considered as harmful and not acceptable for real deployments,
because it allowed to perform any operation in registry with admin rights. That's
why this behaviour was deprecated in Mitaka.

Data model impact
-----------------

None.

REST API impact
---------------

None.

Security impact
---------------

None.

Notifications impact
--------------------

None.

Other end user impact
---------------------

Keystone V3 should be supported to properly use trusts mechanism.

Performance Impact
------------------

None.

Other deployer impact
---------------------

To deploy Glance with trusts the following config should be defined:
* trustee user grants should be specified in CONF.keystone_authtoken group:
username, password, auth_uri, ssl options.

In devstack all parameters are defined by default.

Developer impact
----------------

None.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  mfedosin

Other contributors:
  kkushaev

Reviewers
---------

flaper87
stuart-mclaren

Work Items
----------

* Add trust authorization module to Glance.
* Implement trust authorization between Glance and Glance registry for V2 API.

Dependencies
============

* To use trusts Glance needs to support Keystone V3. If V3 is not supported, Glance
  will use old user token to finish upload operation.

Testing
=======

The unit test and functional tests should be implemented.

Manual testing on devstack:

0. Preparation: Use 'file' as 'default_store' for glance-api, set 'expiration'
   option in keystone.conf to '40' (seconds), set 'token_cache_time'
   in glance-registry.conf to '-1' to disable it, set 'data_api' in
   glance-api.conf to 'registry'.

1. Try to upload big image with v2 API (when upload takes at least 1 minute).
   Make sure that upload fails with Unauthorized error.

2. Apply trusts patches.

3. Try to upload image again. Make sure that upload was finished successfully.

Documentation Impact
====================

None

References
==========

- `Trusts wiki
  <https://wiki.openstack.org/wiki/Keystone/Trusts>`_

- `Service tokens
  <https://github.com/openstack/keystone-specs/blob/
  master/specs/keystonemiddleware/implemented/service-tokens.rst>`_
