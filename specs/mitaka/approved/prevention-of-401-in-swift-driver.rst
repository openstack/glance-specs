..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

========================================================================
Prevention of Unauthorized errors during upload/download in Swift driver
========================================================================

https://blueprints.launchpad.net/glance/+spec/prevention-of-401-in-swift-driver

This change proposal introduces a new mechanism for uploading/downloading
chunked files to Swift store, that prevents possible 401 errors if user
token expires during the image upload/download. It helps to improve the
reliability of image uploads and downloads by providing the ability to
re-authenticate the user during the process, thereby enhancing the stability of
the entire system.

Problem description
===================

There are several shortcomings in the current Swift driver implementation:

1. In case of upload. If an uploading into Swift file exceeds user-set size
limit, then the file is split into chunks and each chunk is uploaded with
single PUT request as an independent object. These requests require authorization
and, unfortunately, it may happen that user token expires in interim chunk,
which will lead to an Unauthorized error and fail of upload.

2. In case of download. Because Swift driver supports "retrying" mechanism,
it may happen, that in case of unsuccessful operation there will be another
attempt to download the file. However, if the token has expired after the
previous attempt, the new one will fail, too, with Unauthorized error.

These issues are typical for both, SingleTenant and MultiTenant implementations,
although the decisions in both cases will be different.

Proposed change
===============

It's proposed to change workflows of uploading and downloading files into Swift
in the following manner:

0. Prerequisites:

New optional dependency from python_keystoneclient has been added for Swift
backend in glance_store. The additional layer (later 'ConnectionManager')
between swift store and swiftclient connections will be added.
ConnectionManager will be responsible for initializing keystone client and
requesting swift client connections (if needed). ConnectionManager executes
re-authentication if connection token is going to expire soon and
re-authentication has been enabled. If re-authentication is not enabled
ConnectionManager always returns the same connection (no connection refresh).
If re-authentication is enabled, ConnectionManager requests all pre-requisites
that allow to request the new token:

- for single-tenant store: glance service user credentials (auth_url,
  domain, username, password, project). All required credentials stored in
  StoreLocation object that passed to the Store so there is no need for the
  new parameters or config options.

- for multi-tenant store: trust id, glance service user credentials (
  username, project, password). Service user credentials will be extracted
  from swift_store_config_file or (swift_store_user, swift_store_key) config
  options. So there is no need for new configuration options. trust_id will be
  created as a result of the following steps:

    1) initialize keystone client scoped to user token
    2) request user roles using keystone client from 1)
    3) initialize keystone client scoped to glance service user project (use
       username and password to create Password auth plugin) and request user_id
       of the service user.
    4) create trust using the client from 1), user roles from 2) and user_id
       from 3). Store trust_id in ConnectionManager.

After that ConnectionManager initializes and stores keystone client.
Keystone client provides a method to request new valid token from Identity
service. ConnectionManager can use that token to build a new Swift Connection.

*Note* If client cannot be created because of some reason then glance_store
raises an exception (for single-tenant) or uses token from user context(for
multi-tenant).

Additionally the method called 'init_client' need to be added to store and it
will be responsible for initializing of keystone client.

1. Upload case.

    *Note* All these changes will apply only to the chunked upload. If the
    upload is performed as a single request, it will use the old workflow.

    In general, the following scenario is proposed:

    1. Before the upload glance_store identifies if image need to be chunked.
    In case of chunked image glance_store initializes ConnectionManager that
    support re-authentication.

    2. Before uploading each chunk, ConnectionManager checks if
    re-authentication is enabled and the token will expire soon (it uses
    'will_expire_soon' method of authentication plugin and
    swift_store_expire_soon_interval value to define when the token needs to
    be requested).
    If the previous condition is true then ConnectionManager requests new token
    and creates new swiftclient connection. That connection will be used for
    uploading the chunk.
    *Note* 'will_expire_soon' used because glance_store might lose the data if
    request to swiftclient fail with Unauthorized error. Unfortunately,
    requests library starts reading the data before checking the token so we
    cannot retry the requests after failure. More specifically, the requests
    library doesn't support 100-continue.

2. Download case.

    In general, the following scenario is proposed:

    1. Before the download, glance_store identifies if swift_retry_get_count is
    positive. It the option value is positive glance_store initializes
    ConnectionManager that allows to re-authenticate and initialize a new
    connection. Otherwise, ConnectionManager always returns the same swift
    connection.

    2. In the case of unsuccessful download of the file, before the retry,
    ConnectionManager checks if re-authentication is enabled and connection
    token is going to expire soon. If the previous condition is true
    ConnectionManager requests new token and returns new connection.

    3. Glance executes download retry normally.

Alternatives
------------

At least one workaround for the whole functionality is available: extend token
expiration time to allow Glance upload the image. This solution affects all
services and it does not look like long term solution.

Also there are several workarounds of this issue, but they work for SingleTenant
implementation only, because for MultiTenant case valid user token is required:

1. Introduce a wrapper around image data, in the shape of a reader class
called	BufferedReader, that supports 'seek' and 'tell' operations, which
buffers the image segment by tee-ing image data to a temporary file as it's
being uploaded to Swift. It's stated as optional resource-consuming solution
that is used when connection between Glance and Swift is unstable, because it
helps not only Unauthorized errors.

2. An alternative is to use memory buffering instead of disk buffering.
With memory buffering, there'll be a substantial increase in the memory
footprint, which may degrade the API performance. Also, disk is a cheaper
resource than memory but not necessarily faster.

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

Keystone V3 should be supported to properly use trusts mechanism.

Performance Impact
------------------

If image file is too big then glance_store need to create trust and initialize
client for every upload to multi-tenant store. The same needs to be done if
swift_retry_get_count is positive and user is downloading an image from
swift store in multi-tenant mode.

Other deployer impact
---------------------

None

Developer impact
----------------

The following blueprint defines buffered reader for swift driver:
https://blueprints.launchpad.net/glance/+spec/buffered-reader-for-swift-driver.
It describes buffered reader that allows to retry image upload in case of
failure. It may seem that this blueprint overlaps with Upload case in this
specification but it is different. The goal of this specification is to
provide a swiftclient connection with valid token to the user. Buffered reader
is responsible for retrying the upload with the original user token.


Implementation
==============

Assignee(s)
-----------

mfedosin
kkushaev
dshakhray

Reviewers
---------

flaper87
stuart-mclaren

Work Items
----------

- Implement ConnectionManager class
- Use ConnectionManager to request connections in 'add' and 'get' method
  of Swift store

Dependencies
============

None.


Testing
=======

None.


Documentation Impact
====================

One configuration option: will_expire_soon interval needs to be described in
documentation. It defines period of time before token expiration when
ConnectionManager must request new token and initialize new connection.


References
==========

Trusts blueprint:
https://blueprints.launchpad.net/glance/+spec/trust-authentication

Buffered reader blueprint:
https://blueprints.launchpad.net/glance/+spec/buffered-reader-for-swift-driver
