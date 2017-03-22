..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=================
Multihash Support
=================

https://blueprints.launchpad.net/glance/+spec/multihash

This spec provides a future-proof mechanism for providing a
self-describing hash for each image.

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

This spec proposes adding a new field to the image metadata. The
proposed key name for this field is ``multihash``. The proposed value is
a multihash [0]_ formatted sha512 hexdigest (codec:sha2-512, code:0x13).
The hexdigest will be obtained using the current hashlib library. The
digest length and hash function type will be prepended as described in
the documentation [0]_ for the multihash format.

Adding a new image will set both the ``checksum`` and ``multihash``
fields.

Requesting the image metadata of an image without the ``multihash``
value set, will result in a null for the ``multihash`` field in the
metadata response.

Downloading an image without the ``multihash`` value set, will result in
the value being populated upon completion.

Uploading an image to an existing image location will result in the
``multihash`` value being set / updated.

Alternatives
------------

1. Update the value of the ``checksum`` field with the hexdigest of a
   different hashing algorithm. This will likely break client-side
   checksum verification code.

2. Add a new non-multihash checksum field. This is a less future proof
   approach that will likely result in a new spec in a few years to add
   yet another checksum field. Using the multihash format allows
   changing the algorithm without adding a new field or breaking the API
   contract.

3. Use the hexdigest of a different algorithm. Tests using hashlib's
   sha256 and sha512 algorithms consistently yielded faster times for
   sha512 (SEE: Performance impact). The implementation of the sha512
   algorithm within hashlib demonstrates reasonable performance and
   should be considered collision-resistant for many years.

Data model impact
-----------------

* Triggers: None
* Expand: A new column (``multihash``) with type string/varchar
  (defaulting to null) will be added to the images table along with an
  index similar to the one on ``checksum``
* Migrate: None
* Contract: None
* Conflicts: None

REST API impact
---------------

A new field (``multihash``) will exist in requests for the image
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

Any future checksum verification code should use the ``multihash`` field.


Implementation
==============

Assignee(s)
-----------

Primary assignee: unassigned


Other contributors:

Work Items
----------

* Add tests

* Update the db to add ``multihash`` column to the images table (including
  expand, migrate, contract, and monolith code)

* Update the sections of code that calculate the ``checksum`` to also
  calculate ``multihash`` (includes calculation on upload)

* Update ``multihash`` on image download when value is null

* Update internal checksum verification code to use the ``multihash``
  field and fallback to ``checksum`` field when not present

* Update glance client

* Update docs

Dependencies
============

The multihash specification [0]_

Testing
=======

Update the tests to verify multihash


References
==========

.. [0] http://multiformats.io/multihash/
