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

Ideally, any image download request that is received, regardless
of cache state, would both encounter the same interface and
execute the same code path to retrieve the image. We currently
adhere to the former (i.e. consistent interface), but not the
latter (i.e. we return different iterators based on cache state).
This introduces unnecessary complexity into the system.

The proposed solution is to remove this complexity by, one,
refactoring the middleware to fully encapsulate the work to
retrieve the image from the store and write it to the cache, and
two, serve the download requests from the cache irrespective of
whether the image was already cached when the request was
received.  While the exact mechanism for achieving this might
vary, one example of how this can be achieved follows:

.. code-block:: none

    if the cache file does not exist:
        create it
        spawn a worker
    return waiting iterator(the cache file)

    def worker():
        request image download information via API request
        download image to cache

    def waiting_iterator(the cache file):
        with open(the cache file) as fp:
            while True:
                chunk = read in the next chunk
                if chunk:
                    yield chunk
                elif the cache file is still being cached
                    wait a bit
                else:
                    We done!
                    break

A few notes regarding implementation:

#. The worker could be one or more processes or threads.
#. The data returned to the clients should be consistent and
   correct regardless of the cache state or how the data is
   downloaded and stored in the cache.
#. Download time can vary based on the current cache state.
#. The implementation must be resilient. Multiple requests can
   fail if the cache fails. Intelligent retries must be
   implemented.

This change helps enforce separation between the code that serves
the data to the client and the cache middleware implementation.
The cache middleware is a caching proxy and is responsible for
downloading data to the cache in a resilient manner and reliably
returning data requested from the cache. Any implementation that
would leverage the cache, need not worry about the interactions
between the backend store and the cache. More specifically, with
the logic to download the images moved out of the iterators and
behind the proxy, requests are no longer dependent upon each
other. While the first request to the cache for a particular image
might trigger a cache miss (worker spawned to download the image),
the success of that request is not tied to the success of the
image being cached or the success of any future request for the
image.

One additional consideration, out of scope for this change, is
that some requests might prefer to download directly from the
store rather than the cache. For the purposes of this change, if
the caching middleware is enabled, all requests will be downloaded
from the cache.

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

2. Update the cache middleware response handler to return a
   waiting iterator (see below) if the image is cached or caching.
   This ensures only the first request to reach the response
   handler results in the data being downloaded from the object
   store. All other requests will stream from the cache.

   Update the cache middleware request handler to return a waiting
   iterator (see below) if the image is cached or caching. This is
   an optimization to prevent requests unnecessarily reaching the
   root app and generating a new download iterator likely
   resulting in a new connection being established when the cache
   has already initiated or completed.

   The iterator will allow download from the cache as data becomes
   available. The iterator will read until the image is fully
   cached and all data is read. If the cache of the image fails,
   the cached image will be cleaned up, and each request
   downloading from the cache will fail requiring a retry by the
   client.

   In both the case where eliminate_duplicate_downloads is enabled
   (new behavior) or eliminate_duplicate_downloads is disabled
   (current behavior) up to n requests, where n is the number of
   requests made, will result in a cache miss in the cache
   middleware request handler and reach the root app, returning a
   download iterator back to the cache middleware response
   handler. In both cases, the first response arriving back to the
   cache middleware will result in a download from the object
   store streamed to the client and stored in the cache.

   When eliminate_duplicate_downloads is disabled (current behavior),
   all responses reaching the cache middleware from the root app
   will return the download iterator from the root app, resulting
   in a download from the backend store for each request arriving
   before the image is fully cached. When eliminate_duplicate_downloads
   is enabled (new behavior), only the first response will result
   in a download from the backend store.  All other requests will
   stream from the cache using a waiting iterator.

   Enabling the eliminate_duplicate_downloads configuration reduces
   failures and improves performance when a large number of image
   download requests are made. It comes at the cost of all
   downloads occurring while an image is being cached depending on
   that single cache to be successful. This means a cache failure
   could result in more clients needing to retry, potentially
   after waiting for nearly the entire image to download.

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

Primary assignee: unassigned

Reviewers
---------

Core reviewer(s): unassigned


Work Items
----------

1. Add tests
2. Update the cache methods in the drivers
3. Add multi-process / thread safe cache worker(s) to middleware
4. Update the cache request handler
5. Update the cache response handler
6. Update the docs


Dependencies
============

None


Testing
=======

SEE Problem Description for scenarios to be tested.


Documentation Impact
====================

Document any new configuration options, if any.


References
==========

None
