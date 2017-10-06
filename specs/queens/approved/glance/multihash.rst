..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=============================
Secure Hash Algorithm Support
=============================

https://blueprints.launchpad.net/glance/+spec/multihash

This spec provides a future-proof mechanism for providing a
secure SHA512 hash for each image.

Problem description
===================

The hash of an image can be obtained from the ``checksum`` field in the
image metadata. Currently, this checksum field holds a md5 hexdigest
value. While md5 can still be used to verify data integrity against
unintentional corruption, it should not be used to verify data integrity
against tampering. A more collision-resistant hashing algorithm should
be used for broader data integrity coverage.

Proposed change
===============

This spec proposes adding two new fields to the image metadata. The
proposed keys for this change would be ``os_hash_algo`` and ``os_hash_value``.
The proposed value is a hash value that is formatted as a sha512 hexdigest.
The hexdigest will be obtained using the current python hashlib library.
``os_hash_algo`` will be sha3_512 and ``os_hash_value`` will be the hex. At this
point in time, the config will default to sha3_512, but this change
will allow us to alter allowed hashing algorithms at any time. The ``os_hash_algo``
field will also allow for users to dynamically pass this value to their python code.
We will leave MD5 calculations and checksums for backwards compatibility.

Adding a new image will set all of ``checksum``, ``os_hash_algo`` and ``os_hash_value``
fields.

Requesting the image metadata of an image without the ``os_hash_algo/os_hash_value``
value set, will result in a null for the ``os_hash_algo/os_hash_value`` field in the
metadata response.

Alternatives
------------

1. Update the value of the ``checksum`` field with the hexdigest of a
   different hashing algorithm. This will likely break client-side
   checksum verification code.

2. Add only the new ``os_hash_value`` field. While it is a simpler change, it
   is a less future proof approach because it ties the sha512 algorithm to the
   ``os_hash_value`` property in the same way that the md5 algorithm is tied to the
   current ``checksum`` property. When a sha512 collision is produced, there will
   have to be a new spec in to add yet another checksum field.

   The approach described in this spec of using an additional ``os_hash_algo`` field
   will allow changing the hash algorithm without adding a new field or breaking
   the API contract. All we'll have to do is update the algorithm used and put
   its name in the ``os_hash_algo`` property, and then any image consumer will know
   how to interpret what's in the ``os_hash_value`` property.

   It is worth noting that the Glance implementation of image signature validation
   gives us a precedent for having a value in one property (``img_signature``) and
   the name of the algorithm used in another property
   (``img_signature_hash_method``) [1]_. Thus the proposal in this spec is
   completely consistent with a related Glance workflow.

3. Use the hexdigest of a different algorithm. Tests using hashlib's
   sha256 and sha512 algorithms consistently yielded faster times for
   sha512 (SEE: Performance impact). The implementation of the sha512
   algorithm within hashlib demonstrates reasonable performance and
   should be considered collision-resistant for many years.

4. Implement a single ``multihash`` field in the image metadata in which we calculate
   the SHA512 value. The single field will contain the coded algorithm name and hash [0]_.
   The advantage is that it is only one field being added to the data model and schema.
   However, having only one field would make it difficult to use the hash quickly as
   the end user would be required to decode what algorithm is being used before verifying
   the hash.

Data model impact
-----------------

* Triggers: None
* Expand: Two new columns (``os_hash_algo`` & ``os_hash_value``) with type string/varchar
  (defaulting to null) will be added to the images table. We will create an
  index similar to the one on ``checksum`` as well.
* Migrate: None
* Contract: None
* Conflicts: None

REST API impact
---------------

Two new fields (``os_hash_algo`` & ``os_hash_value``) will exist in requests for the image
metadata.

Security impact
---------------

A new more collision-resistant hash will be returned in addition to the
current checksum.

Notification impact
-------------------

None

Other end user impact
---------------------

None

Performance impact
------------------

New image uploads (and the first download of previously uploaded images)
will take an additional amount of time to calculate the sha512 checksum:

5G binary blob of random data:
* md5: ~9s
* sha256: ~22s
* sha512: ~14s
* 1Gbps line speed upload: 42s

1.5G Ubuntu 16.04 cloud image:
* md5: ~2.9s
* sha256: ~7.2s
* sha512: ~4.6s
* 1Gbps line speed upload: 12s

555M Debian 8 cloud image:
* md5: ~1.0
* sha256: ~2.5
* sha512: ~1.6
* 1Gbps line speed upload: 4.5s

* Note: SHA512 has been selected and should have minimal impact on overall upload time
  with regards to the entire process.

Test Code:

.. code:: python

    #!/usr/bin/env python3

    import hashlib
    import time


    def runtime(f):
        def wrapper(*args, **kwargs):
            start = time.time()
            f(*args, **kwargs)
            print("Time elapsed: %s" % (time.time() - start))
        return wrapper


    @runtime
    def checksum(filename, algorithm):
        algorithms = {"md5": hashlib.md5,
                      "256": hashlib.sha256,
                      "512": hashlib.sha512,
                      }
        with open(filename, "rb") as f:
            m = algorithms[algorithm]()
            for chunk in iter(lambda: f.read(65536), ''):
                m.update(chunk)
        print("%s: %s" % (algorithm, m.hexdigest()))

    checksum("fake.img", "512")
    checksum("fake.img", "256")
    checksum("fake.img", "md5")
    checksum("fake.img", "256")
    checksum("fake.img", "md5")
    checksum("fake.img", "512")


Developer impact
----------------

Any future checksum verification code should use the ``os_hash_algo`` & ``os_hash_value`` fields.
Fallback to the ``checksum`` field if not properly populated.


Implementation
==============

Assignee(s)
-----------

Primary assignee: Scott McClymont


Other contributors:

Work Items
----------

* Add tests

* Update the db to add ``os_hash_algo`` & ``os_hash_value`` columns to the images table (including
  expand, migrate, contract, and monolith code)

* Update the sections of code that calculate the ``checksum`` to also
  calculate ``os_hash_algo`` & ``os_hash_value`` (includes calculation on upload)

* Discuss updating on download ``os_hash_algo`` & ``os_hash_value`` when value is null

* Update internal checksum verification code to use the ``os_hash_value``
  field and fallback to ``checksum`` field when not present

* Update glance client

* Update docs

* Add the os_hash_algo value to the discovery API if the API is ready

Dependencies
============

None

Testing
=======

Update the tests to verify proper population of image properties


References
==========

.. [0] http://multiformats.io/multihash/
.. [1] https://docs.openstack.org/glance/latest/user/signature.html
