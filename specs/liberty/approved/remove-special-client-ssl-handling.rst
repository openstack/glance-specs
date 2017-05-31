..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=================================
Remove custom client SSL handling
=================================

https://blueprints.launchpad.net/python-glanceclient/+spec/remove-custom-client-ssl-handling

The Glance client currently supports disabling SSL compression via
the --no-ssl-compression argument. This spec proposes deprecating this
special handling of SSL.

Note: This is transport layer compression, not application layer (http)
compression.


Problem description
===================

Custom SSL handling was introduced because disabling SSL layer compression
provided an approximately five fold performance increase in some
cases. Without SSL layer compression disabled the image transfer would be
CPU bound -- with the CPU performing the DEFLATE algorithm.  This would
typically limit image transfers to < 20 MB/s. When --no-ssl-compression
was specified the client would not negotiate any compression algorithm
during the SSL handshake with the server which would remove the CPU
bottleneck and transfers could approach wire speed.

In order to support '--no-ssl-compression' two totally separate code
paths exist depending on whether this is True or False.  When SSL
compression is disabled, rather than using the standard 'requests'
library, we enter some custom code based on pyopenssl and httplib in
order to disable compression.

This spec proposes removing the custom code because:

* It is a burden to maintain

 Eg adding new code such as keystone session support is more complicated

* It can introduce additional failure modes

 We have seen some bugs related to the 'custom' certificate checking

* Newer Operating Systems disable SSL for us.

 Eg. While Debian 7 defaulted to compression 'on', Debian 8 has compression
 'off'. This makes both servers and client less likely to have compression
 enabled.

* Newer combinations of 'requests' and 'python' do this for us

 Requests disables compression when backed by a version of python which
 supports it (>= 2.7.9). This makes clients more likely to disable
 compression out-of-the-box.

* It is (in principle) possible to do this on older versions too

 If pyopenssl, ndg-httpsclient and pyasn1 are installed on older
 operating system/python combinations, the requests library should
 disable SSL compression on the client side.


Proposed change
===============

Deprecate the '--no-ssl-compression' option. Remove the custom http
handling code and print a warning when '--no-ssl-compression' is
specified.


Alternatives
------------

* Do not deprecate

The cost/benefit of not deprecating would mean that custom code paths
would have to be maintained for a small number of corner cases (that
can be addressed by other means).

* Add dependencies on ndg-httpsclient and pyasn1.

This is a possibility for legacy installations, but this should not
be needed for the vast majority of cases.


Data model impact
-----------------

None


REST API impact
---------------

None


Security impact
---------------

Certificate checking will no longer be done by custom glance client code,
but by the 'requests' library. I verified that for older python installs
(2.7) certificate checking is performed correctly by the requests library.

Systems that have SSL compression enabled may be vulnerable to the CRIME
(https://web.nvd.nist.gov/view/vuln/detail?vulnId=CVE-2012-4929) attack.
Installations which are security conscious should be running the Glance
server with SSL disabled.


Notifications impact
--------------------

None


Other end user impact
---------------------

SSL potentially not being disabled.
A new deprecation warning.


Performance Impact
------------------

If SSL is not disabled user's will experience a performance hit -- until
they use one of the alternative methods to disable it.


Other deployer impact
---------------------

Deprecation warnings.
Will need to use an alternative method to disable SSL if appropriate.


Developer impact
----------------

Should simplify things.


Implementation
==============

Assignee(s)
-----------

Stuart McLaren


Reviewers
---------

Ian Cordasco


Work Items
----------

* Client change
* (small) nova/cinder changes

Dependencies
============

None


Testing
=======

There is limited https testing in the gate by default.
Some manual functional testing will be done, and devstack will be
spun up with https enabled.


Documentation Impact
====================

The cli help will be updated. Any relevant .rst docs will be updated also.


References
==========

Previous effort:

https://review.openstack.org/#/c/23424

