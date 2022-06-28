..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

================================================
Eliminate Redundant Downloads of Uncached Images
================================================

Include the URL of your launchpad blueprint:

https://blueprints.launchpad.net/glance/+spec/duplicate-downloads

Multiple requests for an image that is not yet cached on the Glance
API node handling the request currently results in multiple
download requests for the same image from the backend store. For
example, 1000 concurrent build requests based off an uncached image
can result in 1000 download requests from the backend store.


Problem description
===================

.. code:: cucumber

    Feature: Elasticity

        In order to briefly leverage the power of the Cloud to do some work,
        As an OpenStack Powered Cloud customer leveraging Glance caching
        I want to quickly provision a large number of servers, perform some
        work, and then destroy them.

        Scenario Outline: Concurrent Requests for Uncached Image
            Given a single Glance API node
            And the requested image exists in the backend store
            And the requested image is uncached on the Glance API node
            When <n> concurrent request(s) for the image is/are made
            Then the image will be downloaded from the backend store <m> times
            And the image will be cached on the Glance API node
            And every request for the image will succeed

            Examples: Concurrent Requests
                | n | m |
                | 1 | 1 |
                | 2 | 1 |

        Scenario: Concurrent Requests for Uncached Image Fails
            Given a single Glance API node
            And the requested image exists in the backend store
            And the requested image is uncached on the Glance API node
            When 2 concurrent requests for the image are made
            And mid-download the client closes the first connection
            Then only the first download request will fail
            And the image will be cached on the Glance API node

        Scenario: Stream to all requests while caching
            Given a Glance API node (1) with this feature deployed
            And a Glance API node (2) without this feature deployed
            And the requested image exists in the backend store
            And the requested image is uncached on Glance API node 1
            And the requested image is uncached on Glance API node 2
            When 2 concurrent requests are made to API node 1
            And 2 concurrent requests are made to API node 2
            Then the 2 requests to API node 1 will succeed
            And the 2 requests to API node 2 will succeed
            And the image will be cached on Glance API node 1
            And the image will be cached on Glance API node 2
            And the request completion time between the 2 requests to node 1
                will be statistically less than or equal to
                the request completion time between the 2 requests to node 2

Proposed change
===============

Currently, the Glance caching middleware returns an iterator that
downloads from the cache only if the image is already cached. If
the image is uncached, the request is passed onto the API to
obtain an iterator that will download directly from the store. The
response from the API containing this direct iterator is returned
back through the caching middleware. If the image is completely
uncached when the middleware processes the response, it will wrap
the direct download iterator from the API in an another iterator
that will tee to the cache (i.e. read from the store and write to
both the client and the cache via a split pipe).

Therefore, depending on the state of the cache, one of three
iterators can be returned: an iterator to the cache (if the image
is completely cached), an iterator to the store (if the image is
partially cached), or a teeing iterator that streams from the
store and writes to the cache (if the image is completely
uncached). This approach is racey and can result in many responses
downloading directly from the store and a subset of those teeing
data to the same location on the filesystem.

The proposed solution is for the first download request to instead of writing
the whole file to the cache, we write the file to cache in chunks. Then, the
subsequent download requests read from the chunks that have been written. Once
the subsequent request finishes reading all the available chunks in the cache,
it will wait for the next available chunk written to the cache by the first
request. It will keep doing this until the first request finishes all the
chunks.

For the first request:

.. code-block:: none

    if the cache entry does not exist:
        mark the image "caching"
        create a new folder in the cache directory with the image id
        take the iterator from the download (like we are doing now)
        write the data in 1GB chunks to cache
        upon finish, mark the image "cached"

For the subsequent request:

.. code-block:: none

    if the image is marked "caching" or "cached":
        read the chunk from the cache until we get all the expected chunks
        if a chunk is not available:
        wait for it to be written by the first request

.. note::
   Note: The hit count of cached image should not be increased for each chunk read,
   instead it should be increased once per actual request to read the image from cache.

Alternatives
------------

1. Add a configuration option, ``eliminate_duplicate_downloads``,
   to enable this feature. The addition of a configuration option
   to control how the caching middleware behaves puts unnecessary
   burden on the operator. The caching middleware should meet the
   expected behaviors as outlined in the problem description
   without introducing a new configuration option. The only value
   of such option is to allow a phased roll-out of the feature. If
   the consensus is to introduce such an option, being defaulted
   to disabled, it should then be deprecated and defaulted to
   enabled in the next release.

2. To avoid streaming partial image to multiple clients in case
   of the initial caching request failing we could block all the
   subsequent requests until the image is fully in cache and serve
   those only from cache.

   This approach would cause significant delay serving the rest of
   the clients with a benefit of saved bandwidth in those rare cases
   where the caching gets interrupted by the image or store going
   unavailable. Due to possible very long delays on large images this
   would complicate the download process as some kind of keepalive for
   the client connection would be needed to avoid timeouts.

3. Create a lock within the middleware request handler: This
   prevents requests from reaching the root app and establishing a
   download iterator in a race to be the first to initiate the
   download in the cache middleware response handler. However, it
   comes at a reliability and complexity cost. Logic would have to
   be implemented in the request handler to recover from failures
   between the request and response. That's a lot of squeeze for
   not a lot of juice.

4. Move the cache out of the middleware into the root app and
   provide a locking mechanism around caching and downloading.
   There are architectural benefits to this. However, it is a
   serious undertaking, and I believe that any conversations
   around this should be had completely outside the context of
   this change.

5. Move cache out of Glance API: This requires client side logic
   and new / external caching code.

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

See Other deployer impact

Performance Impact
------------------

1. Image request time for concurrent requests will decrease.
2. Bandwidth consumed between Glance API nodes and backend store
   will decrease.

Other deployer impact
---------------------

Every request being served from the cache will impact the
reliability and performance profile. The bottleneck between the
backend store and Glance will be removed for the thundering herd
problem.  However, there could still be a bottleneck between the
hypervisors and the Glance API nodes.

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee: Mridula Joshi

Reviewers
---------

Core reviewer(s): Erno Kuvaja


Work Items
----------

1. Add tests
2. Update the cache methods in the drivers
3. Update the cache request handler
4. Update the cache response handler
5. Update the docs

Dependencies
============

None


Testing
=======

* Unit Tests
* Functional Tests


Documentation Impact
====================

Document any new configuration options, if any.


References
==========

https://review.opendev.org/c/openstack/glance-specs/+/206120
