================
Glance Spec Lite
================

Please keep this template section in place and add your own copy of it between the markers.
Please fill only one Spec Lite per commit.

<Title of your Spec Lite>
-------------------------

:problem: <What is the driver to make the change.>

:solution: <High level description what needs to get done. For example: "We need to
           add client function X.Y.Z to interact with new server functionality Z".>

:impacts: <All possible \*Impact flags (same as in commit messages) or 'None'.>

Optionals (please remove this line and fill or remove the rest until End of Template):
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

:how: <More technical details than the high level overview of `solution` if needed.>

:alternatives: <Any alternative approaches that might be worth of bringing to discussion.>

:timeline: <Estimation of the time needed to complete the work.>

:link: <Link to the change in gerrit that already would provide the `solution`.
       After commiting the Spec Lite depend the change to the Spec Lite commit.>

:reviewers: <If reviewers has been agreed for the functionality, list them here.>

:assignee: <If known, list who is going to work on the feature implementation here>

End of Template
+++++++++++++++

Return 409 if removing/replacing the location of an image that's not ``active``
-------------------------------------------------------------------------------

:problem: When ``show_multiple_locations`` is set to ``True``, users currently
          can remove or replace locations of an image irrespective of the image
          status. This can result in bad experiences for the users:- 1) If one
          tries to change or remove the location for an image while it is in
          ``saving`` state, Glance would be trying to write data to a previously
          saved location while the user updates the custom location. This results
          in a race condition. 2) For images that are in ``queued`` state and no
          image data has been uploaded yet, there is no need for an image
          location to be removed and permitting users to remove the image
          location can result in a bad experience. However users can be allowed
          to replace the image location to maintain backward compatibility and
          also because replacing could mean replacing an empty location by a
          non-empty image location. 3) For images in ``deactivated`` state, it
          is essential that image locations are not updated as it does not abide
          with the purpose of the image state being set to ``deactivated`` and
          may cause security concerns.

:solution: 1) Return Conflict Error (409 response code) if an attempt to remove
           the image location is made when the status of the image
           is anything but ``active``. 2) Return Conflict Error (409 response
           code) if an attempt to replace the image location is made when the
           status of the image is anything but ``active`` or ``queued``.

:impacts: A Conflict Error will be thrown preventing users from removing an
          image location when the image status is not ``active`` and replacing
          an image location when the image status is not ``active`` or ``queued``.

:timeline: Expected to be merged within the ocata-1 time frame.

:link: https://review.openstack.org/#/c/366995/

:assignee: Nikhil Komawar, Dharini Chandrasekar

Return 409 if removing/replacing the location of an image that's not ``active``
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Expand hypervisor_type metadata with Virtuozzo hypervisor
---------------------------------------------------------

:problem: Currently it is not possible to require Virtuozzo hypervisor
          by specifying hypervisor_type metadata, though Nova has had
          Virtuozzo support since the Kilo release.

:solution: We need to expand etc/metadefs/compute-hypervisor.json
           hypervisor_type property with the appropriate identifier, 'vz',
           as defined in
           http://git.openstack.org/cgit/openstack/nova/tree/nova/compute/hv_type.py.

:impacts: This will have documentation impact. Release note should
          be added to notify interested parties about this addition.

:timeline: Expected to be merged within the O-2 time frame.

:link: https://review.openstack.org/#/c/341623/

:assignee: Maxim Netratov

End of Expand hypervisor_type metadata with Virtuozzo hypervisor
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Add `ploop` to the list of supported disk formats
-------------------------------------------------

:problem: Currently 'ploop' format is not among supported by default disk
          formats, even though it's been supported by Nova since the Kilo release.

:solution: `disk_formats` configuration option needs to be updated to add
           'ploop' as one of the supported format.

:impacts: This will have documentation impact. Release note should
          be added to notify interested parties about this addition.

:timeline: Expected to be merged within the O-2 time frame.

:link: https://review.openstack.org/#/c/341633/

:assignee: Maxim Netratov

End of Add `ploop` to list of supported disk formats
++++++++++++++++++++++++++++++++++++++++++++++++++++

Use ``Range`` HTTP header instead of ``Content-Range`` for parsing requests
---------------------------------------------------------------------------

:problem: When a HTTP request for a partial image download is sent, currently
          the ``Content-Range`` header is parsed to get the byte range from the
          request. Per RFC 7233 specification, the desired byte range
          should be specified in HTTP requests using the ``Range`` header
          rather than the ``Content-Range`` header. The latter is reserved for
          responses to such requests. Current implementation requires users to
          send requests that are not compatible with this specification.
          For example, a user has to give "bytes 12-30/32" instead of
          "bytes=12-32".

:solution: Parse the ``Range`` header from HTTP requests and send a
           ``Content-Range`` entity header with the server response.
           Deprecate and retain the current support for ``Content-Range``
           header requests for backward compatibility reasons.

:impacts: Users will be able to send partial download requests using the
          ``Range`` header in the requests with the appropriate value formats.
          For developers, the ``Range`` webob parser does not have a length
          attribute. We will have to pass the image size explicitly and perform
          checks to identify an unsatisfiable byte range request from the
          parsed ``Range`` header. This change will also require an API
          version bump.

:timeline: Expected to be merged within the Ocata time frame.

:link: https://review.openstack.org/#/c/367528/

:assignee: Dharini Chandrasekar

Use ``Range`` HTTP header instead of ``Content-Range`` for parsing requests
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Add your Spec Lite before this line
===================================
