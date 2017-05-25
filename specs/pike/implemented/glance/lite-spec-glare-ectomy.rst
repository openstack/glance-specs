Lite Spec: Remove Glare code from the Glance repository
-------------------------------------------------------

:problem: Glare became a separate project with its own code repository during
          Newton. The code was copied out of the Glance tree, but remained in
          the Glance repository. It is no longer being maintained within
          Glance, and that has begun to cause some problems, for example,
          blocking a recent stevedore upper constraints change; see Change-Id:
          `I141b17f9dd2acebe2b23f8fc93206e23bc70b568
          <https://review.openstack.org/#q,I141b17f9dd2acebe2b23f8fc93206e23bc70b568,n,z>`_.

:solution: Remove all Glare code from the Glance repository and drop all
           artifacts tables from the Glance database.

:impacts: No API Impact as the Glare API was EXPERIMENTAL in both versions
          that ran on the code being removed ('/v3' on the Glance endpoint in
          Liberty, '/v0.1' on its own endpoint in Mitaka).

          As a courtesy to projects/packagers/deployers that may have consumed
          Glare from the Glance code repository, an `openstack-dev announcement
          <http://lists.openstack.org/pipermail/openstack-dev/2017-February/112427.html>`_
          and an `openstack-operators announcement
          <http://lists.openstack.org/pipermail/openstack-operators/2017-February/012689.html>`_
          were sent out on 16 February 2017.  There has been no response so
          far.

          A detailed release note will be included in the patch.

:timeline: Pike-1

:link: Change-Id: `I3026ca6287a65ab5287bf3843f2a9d756ce15139
       <https://review.openstack.org/#q,I3026ca6287a65ab5287bf3843f2a9d756ce15139,n,z>`_

:assignee: rosmaita
