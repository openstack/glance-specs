..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

================================================
Spec Lite: Add region_name parameter to s3 store
================================================

:project: glance_store

:problem: The current s3 driver determine region_name from amazon endpoints,
          but some operators are using an s3 compatible API which is not from
          amazon.
          In such situation, the region_name parameter cannot be guessed from
          endpoints and result beeing set to None.
          When region_name=None is given to instanciate the s3 client, the
          internal boto3 code is then using a default region_name which is
          wrong (like us-west-1).

:solution: We need to add a new parameter s3_store_region_name in glance
           config so that we can use this value instead of guessing it from
           s3_store_host.

:impacts: None

:assignee: Arnaud Morin <arnaud.morin@ovhcloud.com>
