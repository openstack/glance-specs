..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=============================================================================
Add new import method to support downloading image from another glance/region
=============================================================================

https://blueprints.launchpad.net/glance/+spec/glance-download-import

This spec describe a new import method called glance-download that implements a
glance to glance download in a multi-region cloud with a federated Keystone.


Problem description
===================

When dealing with a multi-region cloud it often appears that operators or
customers need to copy images from a region to another, for example:

* Copy all your public images between your regions (operator)

* Copy instance snapshot in another region to have a backup (user)

* Build your base application image from a factory in one region, then
  propagate it to multiple regions (user)

We can't rely on the "copy-image" import method to copy an image from a
backend to another because it requires the same glance endpoint in the same
region which is not our use-case here.

The only way we have to do it now is to locally download the image data and
upload it elsewhere, which requires some orchestration, and is a huge disk
space and bandwidth loss.

Proposed change
===============

Implement an internal plugin called glance-download based on the existing
internal plugin web-download that will import an image stored on a remote
glance. The web-download workflow will remain unchanged, the only difference
is to retrieve the downloadable data from an other glance endpoint instead of
from an arbitrary URL.

We should note several things:

* To authenticate on the remote glance we propose to use the context token
  of the call, so it will require a federated Keystone environment between
  the two Glance.

* The creation of the image must be handled by the end user as for the
  web-download plugin meaning that it is the responsibility of the user to
  take care of disk format, container format and metadata of the newly
  created image.
  If necessary, the plugin will update the container_format and disk_format
  to match what is set on source glance.

* The plugin will come with an extra task in the taskflow that will be in
  charge of setting the container_format and disk_format to be the same as it
  is on the source glance. It will also copy some extra properties defined in
  the extra_properties_prefixes option of glance_download_properties section.
  The default extra_properties_prefixes values are 'hw\_', 'trait:', 'os_distro',
  'os_secure_boot' and 'os_type' which are needed to ensure an instance can boot
  on the image. An operator will be able to remove or add other extra
  properties by modifying this configuration variable.
  This extra_properties_prefixes is a list of prefixes, meaning that all the
  metadata that are starting with a prefix belonging to that list will be
  copied.

.. code-block:: ini

  [glance_download_properties]
  extra_properties_prefixes = [
    'hw_',
    'trait:',
    'os_distro',
    'os_secure_boot',
    'os_type'
  ]
..

* If metadata injection is configured on the target glance it will override
  the metadata as the injection is run after the import.


Alternatives
------------

We could imagine a take out alternative where the owner of the image in the
source cloud generates a limited-use tokenized URL that allows access to the
image without any keystone auth. Such solution is more risky as we do not
have any authentication mechanism to access the remote image. It will also
require rewriting the code as there is no existing source.

This would also require developing a mechanism to manage creation and
expiration of the temporary urls which would result in a more complex solution
that requires more time to develop, document and test.

Data model impact
-----------------

None


REST API impact
---------------

Modification of existing API resource

* Resource **/v2/images/<image id>/import**

* Method: **POST**

* Common response code:
    * *201*: import job queued
    * *400*: bad request with details
    * *401*: Unauthorized
    * *403*: Forbidden


* JSON body definition

.. code-block:: javascript

    "method": {
        "name": {
            "description": "Name of the method used, here is glance-download",
            "type": "string"
        },
        "glance_image_id": {
            "description": "The image id to download on remote glance",
            "type": "string"
        },
        "glance_region": {
            "description": "The region name of remote glance",
            "type": "string"
        },
        "glance_service_interface": {
            "decription": "The interface of remote glance, default to 'public'",
            "type": "string"
        }
    }
..

Example:

.. code-block:: javascript

     "method": {
         "name": "glance-download",
         "glance_image_id": "02ea04ba-72b3-4687-810d-8ba10c991a97",
         "glance_region": "REGION1",
         "glance_service_interface": "admin"
    }
..


Security impact
---------------

We use the token of the request to authenticate on remote glance. As we are in
multi-region context with a federated keystone, there is no security impact.

Notifications impact
--------------------

None


Other end user impact
---------------------

Users will have a new import mechanism open to them, after updating their
client


Performance Impact
------------------

None


Other deployer impact
---------------------

None


Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  pslestang

Other contributors:
  alistarle

Work Items
----------

* glance:

    * Create a base download class that will be inherited by web-download and
      glance-download

    * Patch the web-download class to inherit from base download class

    * Write the glance-download class

    * Patch the api image import to support the glance-download method

    * Add in task flow a class in charge of:

        * setting the correct container_format and disk_format

        * copying the metadatas defined in extra_properties option of the
          glance_download_properties section. Default list must be
          ['hw\_', 'trait:', 'os_distro', 'os_secure_boot', 'os_type']

    * The class has to be added to taskflow as a normal task to be reusable if
      needed. We only have to check for input parameters to know if it can be
      run or not.

    * Add the glance-download internal plugin in setup

    * write unit/functional tests

    * update documentation

    * glance and openstack client

        * add support for glance-download method

    * update documentation


Dependencies
============

None

Testing
=======

* Unit and functional tests in Glance

* Tempest tests. Testing glance-download plugin with the g-api-r separate
  endpoint looks good even if it shares the same database to validate the
  workflow.


Documentation Impact
====================

The documentation needs to be updated to identify this new import method


References
==========

* https://review.opendev.org/c/openstack/glance/+/840318

