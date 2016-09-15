========================================
Replacing a Membership List for an Image
========================================

.. include:: deprecation-note.inc

The full membership list for a given image may be replaced. We issue a
``PUT`` request to ``http://glance.example.com/images/1/members`` with a
body of the following form:

.. code::

    {'memberships': [
     {'member_id': 'tenant1',
      'can_share': false}
     ...]}

All existing memberships which are not named in the replacement body are
removed, and those which are named have their \`can\_share\` settings
changed as specified. (The \`can\_share\` setting may be omitted, which
will cause that setting to remain unchanged in the existing
memberships.) All new memberships will be created, with \`can\_share\`
defaulting to \`false\` if it is not specified.

