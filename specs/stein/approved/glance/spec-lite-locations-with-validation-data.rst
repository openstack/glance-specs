..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=====================================================
Spec Lite: Embed validation data with image locations
=====================================================

:project: glance

:problem: A new image using the HTTP store may have its ``locations``
          initialised using the ``add`` or ``replace`` operation in an HTTP
          PATCH request, but there is currently no way to provide values for
          accompanying checksum and multihash values.

:solution: Allow embedding of values for ``checksum``, ``os_hash_algo``
           and ``os_hash_value`` in a new write-only JSON object named
           ``validation_data``, along with the ``url`` and ``metadata`` for an
           image location. These values will be used to populate the
           corresponding image properties.

           New values for any of these items will only be accepted if the image
           status is ``queued`` and the corresponding image property is not
           already populated. To allow idempotency, this object may be included
           when adding or replacing locations for an image which is in
           ``active`` status or/and already has the corresponding properties
           populated, but the supplied values must exactly match the existing
           ones.

           The object may be included in one or more of the items in
           a ``locations`` list, but values must be consistent across all
           instances.

           Although the ``validation_data`` object will be optional,
           if it is present, the ``os_hash_algo`` and ``os_hash_value`` items
           will be required, to force adoption of multihash. Since multihash
           will be the default mechanism for clients in the Stein release,
           ``checksum`` will be optional, but included to accommodate legacy
           consumers that have not yet implemented multihash. The consumer
           is expected know to to populate ``checksum`` only if their
           deployment requires it.

           ``os_hash_algo`` must match the Glance server's
           ``DEFAULT.hashing_algorithm`` configuration option.  Whilst it seems
           redundant to require an input with only one acceptable value, this
           is required to ensure that the user knows which algorithm is
           required. The ``checksum`` and ``os_hash_value`` cannot be verified
           (since the Glance server does not have a copy of the image data),
           but they will be validated as hexadecimal values of the correct size
           for the respective algorithms.

           Any violations of the above rules will result in a ``HTTPConflict``
           exception (HTTP status 409).

           The following will be added to the properties for ``locations``
           items in the ``images`` schema::

             'validation_data': {
                 'description': _(
                     'Values to be used to populate the corresponding '
                     'image properties. If the image status is not '
                     '"queued" or/and the image properties are already '
                     'populated, any supplied values must exactly match '
                     'existing ones.'
                 ),
                 'type': 'object',
                 'writeOnly': True,
                 'properties': {
                     'checksum': {
                         'type': 'string',
                         'minLength': 32,
                         'maxLength': 32,
                     },
                     'os_hash_algo': {
                         'type': 'string',
                         'maxLength': 64,
                     },
                     'os_hash_value': {
                         'type': 'string',
                         'maxLength': 128,
                     },
                 },
                 'required': [
                     'os_hash_algo',
                     'os_hash_value',
                 ],
             },

           Support will also be added to the ``add_location()`` method and the
           ``location-add`` shell command in python-glanceclient.

:alternatives: Implement an import method to directly register images for use
               with the HTTP store (without requiring use of HTTP PATCH).

:timeline: Include in Stein release. Need approval ASAP, so I can proceed with
           a private backport for my Rocky upgrades (v1 API removed).

:link: https://review.openstack.org/597368

:assignee: imacdonn
