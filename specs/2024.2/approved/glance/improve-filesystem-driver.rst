..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===========================================================
Improve filesystem store driver to utilize NFS capabilities
===========================================================

https://blueprints.launchpad.net/glance/+spec/improve-filesystem-driver

Problem description
===================

The filesystem backend of glance can be used to mount NFS share as local
filesystem, so it is not required to store any special configs at
glance side. Glance does not care about NFS server address or NFS share
path at all, it just assumes that each image is stored in the local
filesystem. The downside of this assumption is that glance is not
aware whether NFS server is connected/available or not, NFS share
is mounted or not and just keeps performing add/delete operations
on local filesystem directory which later might causes problem
in synchronization when NFS is back online.

Use case: In a k8s environment where OpenStack Glance is installed on
top of OpenShift and NFS share is mounted via the `Volume/VolumeMount`
interface, the Glance pod won't start if NFS share isn't ready. Whereas
if NFS share is not available after Glance pod is available then
upload operation will fail with following error::

    sh-5.1$ openstack image create --container-format bare --disk-format raw --file /tmp/cirros-0.5.2-x86_64-disk.img cirros
    ConflictException: 409: Client Error for url: https://glance-default-public-openstack.apps-crc.testing/v2/images/0ce1f894-5af7-44fa-987d-f4c47c77d0cf/file, Conflict

Even though the Glance Pod is still up, `liveness` and `readiness` probes
starts failing and as a result the Glance Pods are marked as `Unhealthy`::

    Normal   Started         12m                    kubelet            Started container glance-api
      Warning  Unhealthy       5m24s (x2 over 9m24s)  kubelet            Liveness probe failed: Get "https://10.217.0.247:9292/healthcheck": net/http: request canceled (Client.Timeout exceeded while awaiting headers)
      Warning  Unhealthy       5m24s (x3 over 9m24s)  kubelet            Liveness probe failed: Get "https://10.217.0.247:9292/healthcheck": net/http: request canceled (Client.Timeout exceeded while awaiting headers)
      Warning  Unhealthy       5m24s                  kubelet            Readiness probe failed: Get "https://10.217.0.247:9292/healthcheck": net/http: request canceled (Client.Timeout exceeded while awaiting headers)
      Warning  Unhealthy       4m54s (x2 over 9m24s)  kubelet            Readiness probe failed: Get "https://10.217.0.247:9292/healthcheck": net/http: request canceled (Client.Timeout exceeded while awaiting headers)
      Warning  Unhealthy       4m54s                  kubelet            Readiness probe failed: Get "https://10.217.0.247:9292/healthcheck": net/http: request canceled (Client.Timeout exceeded while awaiting headers)

Later in time, according to the failure threshold set for the Pod,
the kubelet marks the Pod as Failed, and we can see a failure, and
given that the policy is supposed to recreate it::

    glance-default-single-0                                         0/3     CreateContainerError   4 (3m39s ago)   28m

    $ oc describe pod glance-default-single-0 | tail
    Normal   Started    29m                    kubelet   Started container glance-api
    Warning  Unhealthy  10m (x3 over 26m)      kubelet   Readiness probe failed: Get "https://10.217.0.247:9292/healthcheck": net/http: request canceled (Client.Timeout exceeded while awaiting headers)
    Warning  Unhealthy  10m                    kubelet   Liveness probe failed: Get "https://10.217.0.247:9292/healthcheck": net/http: request canceled (Client.Timeout exceeded while awaiting headers)
    Warning  Unhealthy  10m                    kubelet   Readiness probe failed: Get "https://10.217.0.247:9292/healthcheck": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
    Warning  Unhealthy  9m30s (x4 over 26m)    kubelet   Liveness probe failed: Get "https://10.217.0.247:9292/healthcheck": net/http: request canceled (Client.Timeout exceeded while awaiting headers)
    Warning  Unhealthy  9m30s (x5 over 26m)    kubelet   Liveness probe failed: Get "https://10.217.0.247:9292/healthcheck": net/http: request canceled (Client.Timeout exceeded while awaiting headers)
    Warning  Unhealthy  9m30s (x2 over 22m)    kubelet   Readiness probe failed: Get "https://10.217.0.247:9292/healthcheck": net/http: request canceled (Client.Timeout exceeded while awaiting headers)
    Warning  Unhealthy  9m30s (x3 over 22m)    kubelet   Readiness probe failed: Get "https://10.217.0.247:9292/healthcheck": net/http: request canceled (Client.Timeout exceeded while awaiting headers)
    Warning  Unhealthy  9m30s                  kubelet   Liveness probe failed: Get "https://10.217.0.247:9292/healthcheck": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
    Warning  Failed     4m47s (x2 over 6m48s)  kubelet   Error: context deadline exceeded

Unlike other deployments (deployment != k8s) where even if NFS share is not
available the glance service keeps running and uploads or deletes the data
from local filesystem. In this case we can definitely say that NFS share is
not available, the Glance won't be able to upload any image in the
filesystem local to the container and the Pod will be marked as failed and
it fails to be recreated.

Proposed change
===============

We are planning to add new plugin `enable_by_files` to `healthcheck`
wsgi middleware in `oslo.middleware` which can be used by all openstack
components to check if desired path is not present then report
`503 <REASON>` error or `200 OK` if everything is OK.

In glance we can configure this healthcheck middleware as an application
in glance-api-paste.ini as an application:

.. code-block:: ini

  [app:healthcheck]
  paste.app_factory = oslo_middleware:Healthcheck.app_factory
  backends = enable_by_files (optional, default: empty)
  # used by the 'enable_by_files' backend
  enable_by_file_paths = /var/lib/glance/images/filename,/var/lib/glance/cache/filename (optional, default: empty)

  # Use this composite for keystone auth with caching and cache management
  [composite:glance-api-keystone+cachemanagement]
  paste.composite_factory = glance.api:root_app_factory
  /: api-keystone+cachemanagement
  /healthcheck: healthcheck

The middleware will return "200 OK" if everything is OK,
or "503 <REASON>" if not with the reason of why this API should not be used.

"backends" will the name of a stevedore extentions in the namespace
"oslo.middleware.healthcheck".

In glance, if local filesystem path is mounted on NFS share then we
propose to add one marker file named `.glance` to NFS share and then
use that file path to configure `enable_by_files` healthcheck
middleware plugin as shown below:

.. code-block:: ini

  [app:healthcheck]
  paste.app_factory = oslo_middleware:Healthcheck.app_factory
  backends = enable_by_files
  enable_by_file_paths = /var/lib/glance/images/.glance

If NFS goes down or somehow the `/healthcheck` starts reporting
`503 <REASON>` admin can take appropriate actions to make NFS
share available again.

Alternatives
------------

Introduce few configuration options for filesystem driver which will help to
detect if the NFS share is unmounted from underneath the Glance service. We
proposed to introduce below new configuration options for the same:

* `filesystem_is_nfs_configured` - boolean, verify if NFS is configured or not
* `filesystem_nfs_host` - IP address of NFS server
* `filesystem_nfs_share_path` - Mount path of NFS mapped with local filesystem
* `filesystem_nfs_mount_options` - Mount options to be passed to NFS client
* `rootwrap_config` - To run commands as root user

If `filesystem_is_nfs_configured` is set, i.e. if NFS is configured then
deployer must specify `filesystem_nfs_host` and `filesystem_nfs_share_path`
config options in glance-api.conf otherwise the respective glance store will
be disabled and will not be used for any operation.

We are planning to use existing os-brick library (already used by cinder driver
of glance_store) to create the NFS client with the help of above configuration
options and check if NFS share is available or not during service
initialization as well as before each image upload/import/delete operation. If
NFS share is not available during service initialization then add and delete
operations will be disabled but if NFS goes down afterwards we will raise
HTTP 410 (HTTP GONE) response to the user.

Glance still doesn't have capability to check whether particular NFS store has
storage capability to store any particular image beforehand. Also it does not
have capability to verify if network failure occurs during upload/import
operation.

Data model impact
-----------------

None

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

None

Other deployer impact
---------------------

Need to configure healthcheck middleware for glance.

Developer impact
----------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  abhishekk

Other contributors:
  None

Work Items
----------

* Add `enable_by_files` healthcheck backend in oslo.middleware

* Document how to configure `enable_by_files` healthcheck middleware

* Unit/Functional tests for coverage

Dependencies
============

None

Testing
=======

* Unit Tests
* Functional Tests
* Tempest Tests

Documentation Impact
====================

Need to document new behavior of filesystem driver if NFS and healthcheck
middleware is configured.

References
==========

* Oslo.Middleware Implementation - https://review.opendev.org/920055
