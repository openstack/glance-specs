================================================================
Restrict users from downloading image based on custom properties
================================================================

https://blueprints.launchpad.net/glance/+spec/restrict-downloading-images-protected-properties

The goal of this blueprint is to restrict normal users from downloading
the images on the basis of core or custom properties by using
download_image policy.


Problem description
===================

Presently images shared publicly with the users can download these images
freely which could lead to piracy. Today, you can stop users from downloading
images by configuring download_image policy with role constraint, but it will
restrict all users having that particular role from downloading all of the
images, this is not good. So what I want is to restrict users from downloading
images on the basis of specific core or custom property is present in the
image and users having certain specific roles.


Proposed change
===============

We can achieve this by adding new rule in policy.json and apply that rule to
'download_image' policy.

For example:
Add new rule in policy.json mentioned as below

'restricted': 'not (ntt_3251:%(x_billing_code_ntt)s and role:member)'
'download_image': 'role:admin or rule:restricted'

So if 'download_image' policy is enforced then in above case only admin or
user who satisfies rule 'restricted' will able to download image. Other users
will not be able to download the image and will get 403 Forbidden response.

To avoid implementation of dict inspection via dot syntax and enforce the
policy on v1 and v2 api's in the same way, we can create a dictionary-like
mashup of the image core and custom properties, in both v1
and v2 api and pass it directly as target to _enforce() method. In case if
core and custom property is same for the image, then the core property value
will be overwritten on the custom property.

For example:
self._enforce(req, 'download_image', target=image_meta_mashup)


Alternatives
------------

Instead of passing dictionary-like mashup of the image core and custom
properties directly to target, we can pass image itself and can implement
dict inspection via dot syntax. In this case the new rule in policy.json
need to configured as follows,

'restricted': 'not (ntt_3251:%(target.x_billing_code_ntt)s and role:member)'
'download_image': 'role:admin or rule:restricted'

Data model impact
-----------------

None

REST API impact
---------------

* GET:/v2/images/{image_id}/file

      * Description: Downloads binary image data.
      * Method: GET
      * Normal response code(s): 200, 204

      * Expected error http response code(s): 403
          * When image having protected properties downloaded by user
            who doesn't satisfy 'download_image' policy

      * URL for the resource: /v2/images/{image_id}/file
      * Parameters which can be passed via the url
        {image_id}, String, The ID for the image.

* GET:/v1/images/{image_id}

      * Description: Returns the image details as headers and the image binary
                     in the body of the response.
      * Method: GET
      * Normal response code(s): 200
      * Expected error http response code(s): 403

          * When image having protected properties downloaded by user
            who doesn't satisfy 'download_image' policy

      * URL for the resource: /v1/images/{image_id}
      * Parameters which can be passed via the url
        {image_id}, String, The ID for the image.

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

None

Other deployer impact
---------------------

Need to add new rule in policy.json for restricting downloading of image.

"restricted": "not (ntt_3251:%(x_billing_code_ntt)s and role:member)"
"download_image": "role:admin or rule:restricted"

Where ntt_3251 will be the value of property 'x_billing_code_ntt'.

In our case it is necessary to ensure that normal users should not be able
to delete the property ('x_billing_code_ntt') added to the image.
If normal user is able to delete the property of the image then
he can easily download the image as the rule 'restricted' will not work
in this case.

So we need to restrict normal users from deleting the property
using property protections.

Need to modify following options in glance-api.conf file to enable
property-protections:

property_protection_file = property-protections-roles.conf
property_protection_rule_format = roles

Changes in property-protections-roles.conf

[^x_billing_code_.*]
create = admin,member
read = admin,member,_member_
update = admin,member
delete = admin,member

Need to ensure that to use this download restrictions feature,
show_image_direct_url and show_multiple_locations parameter is not set
to True in glance-api.conf file.
If these options are True then, using this download restriction is
potentially an inconsistent policy as user might be able to download the
image using image location(direct url).

In order to deploy the above policy, service provider will need to deploy 2
sets of glance api services. One glance api service will be exposed to the
external nova services(nova-compute) and other to the users. The one which is
exposed to the users should enforce the download_image policy with the above
"restricted" rule and the glance-api which used by nova need to be
isolated/protected, e.g. separated by network, in order to avoid
glance-client/end user connect it by standard API.

Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  abhishek-kekane

Other contributors:
  None

Work Items
----------

- Add new rule in policy.json to restrict download of image.
- Add method to create dictionary-like mashup of image properties
- Modify v1 and v2 api to restrict download
- Modify logic of caching to restrict download for v1 and v2 api
- Sync openstack.common.policy of oslo-inc with Glance when the
  change of oslo-inc get merged.


Dependencies
============

None


Testing
=======

Need to add tempest test to cover download operation.


Documentation Impact
====================

Please refer Other deployer impact.


References
==========

None
