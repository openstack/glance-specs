..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================================
Semver Utility for DB storage
==========================================

https://blueprints.launchpad.net/glance/+spec/semver-support

Working with versions of various objects is a common problem, which already has
a number of market-adopted solutions. One of these solutions is Semantic
Versioning - a system of rules and requirements for assigning version numbers
to software components and other objects. One can find the specification for
SemVer freely at `semver.org <http://semver.org>`

It is proposed to add support of the semantic versioning concept into Glance,
according to the version 2.0.0 of the specification [1], so Glance objects
(starting from Artifacts, but probably including Images in future) may be
properly versioned.

Problem description
===================

Semantic versioning provides the ability to compare two or more objects based
on the version with which they are associated. According to the specification
[1] objects are compared first by their major versions, then minor versions,
then patch versions, also there is a concept of "pre-release" versions (alphas,
betas, release candidates (RC) etc) which should always be considered "lower"
then the "released" version with the same values of numeric versions.

For example, 1.2.2 < 1.2.3-beta < 1.2.3

If we want to store versioned objects in the catalog (this may be applied to
images, artifacts and other entities), then we need to be able to execute this
kind of semantic comparison for large amounts of entities.

So, the comparison should be made not only in memory, but at the database as
well, and there is no generic datatype in modern RDBMs to store this kind of
versioning information. So, a method for storing easily-sortable version
identifiers should be introduced.


Proposed change
===============

First of all, Glance has to adopt some utility to parse strings which contain
version information, verify their compliance with the specification and
properly process the version objects in memory. There is a number of mature
libraries which have this functionality and there is no need to re-implement
them.
After some research it has been suggested to use "semantic_version" library
which is available at pypi [2]. This library is not present in openstack global
requirements, so a patchset [3] has been submitted to add it there.

To be able to sort these version objects in the database it is required to
convert them into some generic comparable data type. Due to the nature of
version information (fixed numeric components for major-minor-patch part) and
arbitrary sequences of alphanumeric strings for pre-release and metadata labels
it is suggested to store them separately as three database fields: one for the
numeric part, another for the pre-release label and the last one for build
metadata.

Three numeric components (major, minor and patch) may be converted into a
single unsigned 64-bit integer number: first 16 bits of this number
will be allocated to store major revision, next 16 bits - for minor revision,
next 16 bits - for patch revision. Remaining 16 bits will be used to store the
release type flag (to make sure that the final release had higher precedence
then pre-releases) and may be reserved for future improvement and storing
additional information which is irrelevant for semantic versioning but may have
some other meanings (see Alternatives section below for more details).

The labels of pre-release version should be stored independently from the
numeric part as a regular string, because - according to the semver spec - they
are to be compared according to regular alphanumeric comparison only if the
numeric parts of the versions are identical.

So, these two values - long number and a string - may be combined into a single
composite index in the database, which will provide efficient capabilities to
sort and filter objects with the versions assigned.

However, there is one important difference between the semver requirement and
simple comparison of alphanumeric strings: semver requires that the labels are
compared "per component" (where "component" is a dot-separated part of the
label), and the components which consists only of digits are to be treated as
integers rather then ASCII strings. For example, version "1.0.0-alpha.4.foo"
should have lower precedence then "1.0.0-alpha.10.bar", because their numeric
components are equal, and the labels have identical first component ('alpha')
but differs in the second ("4" vs "10"), and 4 is less then 10.
But the labels are compared as string database fields, the precedence will be
wrong as "alpha.4.foo" is lexically greater then "alpha.10.bar" (due to "4"
being greater then "1").

To solve this problem it is suggested to add one constraint to this semver
implementation: to limit the maximum length of numeric components in the pre-
release label to a reasonably low value (say, 6 characters) and add extra
leading zeros to these components when saving them to database.

In this case the "alpha.4.foo" label from the example above will become
"alpha.000004.foo", and "alpha.10.foo" - "alpha.000010.foo". ASCII-based
comparison of these strings will give the results which are consistent with the
requirements of semver. Later, when these values are read from the database the
leading zeros may be removed so the labels look fine again.

This applies only to the pre-release label part. Build metadata (the part which
is separated by the '+' character) does not take part in the precedence
resolution, so it neither has to be part of the database index nor has to be
pre-processed in anyway.

It is suggested to create custom composite field for SQLAlchemy which will
encapsulate the above described logic (converting from semantic version into 3
database-friendly values and back) and will be usable for building
version-aware model classes.


Alternatives
------------

Semantic Versioning is not the only specification which defines the format for
version string.
There is another standard - PEP440 - which describes a scheme for identifying
versions of Python software distributions [4]. It shares some common features
with Semantic Versioning but has different and a bit more complicated notation.

Besides slightly different syntax (it just concatenates pre-release segments to
the right of release number, while semver separates them with a dash), it puts
extra constraints on what the pre-release label may contain. In semver,
pre-release label may contain arbitrary alphanumeric characters, while in
PEP440 they may be only be 'a', 'b' or 'rc' followed by a number. This could
theoretically allow to store the pre-release component as part of the same
64-bit long database field which is used to store the release number (e.g.
the release type flag takes 2 bits, and remaining 14 bits are left for the
number of the pre-release build) - however this significantly decreases the
flexibility of the pre-release version field.

Also, PEP440 adds more additional entities: it has a concept of development
builds (being one additional special segment which goes after the pre-release
segments), Epochs (which precedes the build number), local version (which is
actually similar to build metadata of semantic versioning but has different
purpose and also takes part in precedence resolution by following about the
same rules as arbitrary pre-release label of semantic versioning) etc. Also,
unlike semantic versioning PEP440 does not have any limits on the amount of
numeric components in the build number: so, it may be anything from simple "1"
to "1.2.3.4.5.6.7.8.9.10" and beyond. This, of course, gives more flexibility
and power, but may not be easily mapped to efficient database storage.

Which is more important, PEP440 is a standard which is native to Python world,
but is not known outside, while the purpose of Glance Artifacts is to be as
generic as possible in terms of the nature of its objects. This means that the
users of the artifacts are not restricted to be Python developers only: they
may not be the developers at all. So, following easier and more generic
standard seems preferable.

There is one more standard which stands between semver and pep440. It is
called "Linux Compatible Semantic Versioning 3.0.0", is a fork of regular
semver (its 2.0 version) and is developed within Openstack community [5]. It
tries to blend regular semver with versions of Linux Distribution packages and
uses some concepts of pep440 for it.

This notation is easier to map to the database type, however it is still local
to relatively small community of developers (Openstack developers in this
case), so more generic and widely adopted standard as semver seems more
preferrable.

However we are not limited to having only a single versioning notation. In
future we may add support for extra schemas, including some subset of pep440 or
Linux Compatible Semantic Versioning. This may be implemented as part of
further Artifact Repository roadmap or other activities. This particular spec
leaves this out of scope and focuses only on semver implementation.


Data model impact
-----------------

None: this spec does not cover any actual database changes, it just describes
the utility which will allow to operate with semver objects and convert them to
data which may be usable for DB storage - and back.

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

None

Performance Impact
------------------

The proposed change does not affect existing code in any sense.

Other deployer impact
---------------------

This spec assumes that [3] is merged, i.e. the semantic_version library is
added to the global requirements.

Developer impact
----------------

The usage of the lib should be documented for developers, so they may
efficiently use it in their code.

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  ativelkov


Reviewers
---------

Core reviewer(s):
  jokke

Other reviewer(s):
  ivasilevskaya
  mfedosin
  travis-tripp
  icordasc

Work Items
----------

Initial implementation of the feature may be done in a single changeset.
However it seems preferable to add this support to semantic_version library [2]
and remove it from glance codebase aftwerwards.
If the maintainer of the library does not accept this functionality (or if we
decide to add support for more versioning notations later) then this code may
be transferred to some common openstack library, such as Oslo.

After this feature is implemented we should continue the work to add support
for other versioning schemas, such as pep440, Linux Compatible Semantic
Versioning and others. These should be added as independent features covered by
separate specs.


Dependencies
============

None


Testing
=======

A unit test should be added demonstrating the data structure usage, comparison,
string parsing and conversion operation to DB type (long)


Documentation Impact
====================

Developers' guide has to be updated to hint the developers on how to properly
use the library in their code.


References
==========

[1] http://semver.org
[2] https://pypi.python.org/pypi/semantic_version/
[3] https://review.openstack.org/#/c/151466/
[4] https://www.python.org/dev/peps/pep-0440/
