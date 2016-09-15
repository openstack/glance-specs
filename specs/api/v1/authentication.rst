Authentication
--------------

.. include:: deprecation-note.inc

You can optionally integrate Glance with the OpenStack Identity Service
project. Setting this up is relatively straightforward: the Identity
Service distribution at http://github.com/openstack/keystone includes
the requisite middleware and examples of appropriately modified
glance-api.conf and glance-registry.conf configuration files in the
examples/paste directory. Once you have installed Keystone and edited
your configuration files, newly created images will have their owner
attribute set to the tenant of the authenticated users, and the
is\_public attribute will cause access to those images for which it is
false to be restricted to only the owner.

The exception is those images for which owner is set to null, which may
only be done by those users having the Admin role. These images may
still be accessed by the public, but will not appear in the list of
public images. This allows the Glance Registry owner to publish images
for beta testing without allowing those images to show up in lists,
potentially confusing users.

It is possible to allow a private image to be shared with one or more
alternate tenants. This is done through image memberships, which are
available via the members resource of images. (For more details, see the
next chapter.) Essentially, a membership is an association between an
image and a tenant which has permission to access that image. These
membership associations may also have a can\_share attribute, which, if
set to true, delegates the authority to share an image to the named
tenant.

