..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

======================
Allowed upload formats
======================

https://blueprints.launchpad.net/glance/+spec/allowed-upload-formats

Today operators who use image conversion want users to declare the real
disk format of the file they have, then import it, and Glance converts
it to the format preferred on the backend. At the same time they may
want to stop users from using traditional upload (PUT /file) for some
formats, or for all formats. This spec adds a new config option so
operators can control which disk formats are allowed for traditional
upload, separate from which formats are allowed when creating an image.


Problem description
===================

After the fix for CVE-2024-32498, the image conversion plugin uses the
disk_format set on the image as the source format. The content must
match that disk_format. This is good for safety and for API users,
because disk_format means what the file really is.

But operators also want different rules for:

* what formats a user can set when creating an image (for import)
* what formats a user can send with traditional PUT /v2/images/{id}/file
* what format is stored after conversion (output_format)

Today there is only disk_formats. It controls the create schema. It
does not specially restrict PUT /file. So if the operator allows qcow2
in disk_formats (so import + conversion can work), users can also
upload qcow2 with PUT /file, and that path does not run conversion.

Use cases:

1. End User has a qcow2 file. Deployer wants only raw stored on the
   backend, and wants conversion on import. End User should create
   image with disk_format=qcow2 and use import. End User should not
   use PUT /file for that qcow2 image if deployer does not want
   qcow2 uploaded that way.

2. Deployer wants only qcow2 files on disk (output_format=qcow2).
   End User has a raw file. End User should create with disk_format=raw
   and import. Conversion changes it to qcow2. End User should not
   need to lie and create a qcow2 image then upload raw data into it.

3. Deployer does not want to support vmdk at all. Then vmdk is not
   in disk_formats. Users cannot create that format.

4. Deployer wants to disable traditional upload completely and force
   interoperable image import.

   Today this is mostly done with the ``upload_image`` policy in
   ``policy.yaml``. That policy is checked only for
   ``PUT /v2/images/{id}/file``. By default it is unrestricted (any
   authenticated user can upload). Import (stage + import) uses other
   policies, so restricting ``upload_image`` does not block import.

   Example from Glance docs -- allow only admin or service users to
   call traditional upload::

      "upload_image": "role:admin or (service_user_id:<uuid of nova user>) or
         (service_roles:<service user role>)"

   Then normal end users get 403 on PUT /file and must use import.

   Limits of policy alone:

   * It controls *who* may call PUT /file, not *which disk_format*
     is allowed.
   * If a user is still allowed (admin, service), they can upload any
     format that was allowed at create time.
   * To also limit formats for users who may still upload, set
     ``allowed_upload_formats`` (for example to ``raw``). To disable
     traditional upload for everyone, keep using ``upload_image``
     policy.


Proposed change
===============

Add a new config option under [image_format]:

  allowed_upload_formats

This option only affects traditional image upload::

  PUT /v2/images/{id}/file

It is checked against the image disk_format before upload starts.

Semantics:

* If the option is not set, or is set to an empty list (default): no
  change from today. PUT /file works like now for any disk_format
  allowed at create time.

* If the option is set to a non-empty list (for example raw): PUT /file
  is allowed only when image.disk_format is in that list. Otherwise
  return an error.

disk_formats stays as today: it controls which disk_format values are
allowed when creating or updating an image.

Image conversion plugin is not changed. User still declares the real
format. Content must match. Conversion uses declared format as source
and converts to output_format, then updates disk_format on the image.

These three settings work independent:

* disk_formats -- what user may declare at create
* allowed_upload_formats -- what is allowed for PUT /file
* [image_conversion] output_format -- what is stored after convert

Example -- raw backend, allow import of qcow2::

  [image_format]
  disk_formats = raw,qcow2
  allowed_upload_formats = raw

  [image_conversion]
  output_format = raw

* Create disk_format=raw, PUT /file: allowed
* Create disk_format=qcow2, PUT /file: rejected
* Create disk_format=qcow2, import with conversion: allowed, ends as raw

Example -- prefer qcow2 on disk::

  [image_format]
  disk_formats = qcow2,raw,vmdk
  allowed_upload_formats = qcow2

  [image_conversion]
  output_format = qcow2

* User with raw creates disk_format=raw and imports; conversion makes
  qcow2
* User with qcow2 can PUT /file if wanted
* If deployer does not want vmdk, remove it from disk_formats

Example -- allow PUT for qcow2 and vmdk, convert imports to qcow2::

  [image_format]
  disk_formats = qcow2,vmdk
  allowed_upload_formats = qcow2,vmdk

  [image_conversion]
  output_format = qcow2

Simple flow::

  +------------------+
  | Create image     |
  | disk_format in   |
  | disk_formats     |
  +--------+---------+
           |
           v
     +-----+------+
     | How data?  |
     +--+--+---+--+
        |      |
        |      +--> stage + import --> conversion (no change)
        v
   PUT /file
        |
        v
  allowed_upload_formats
  non-empty?
    |-- no (unset or empty) --> upload as today
    |-- yes --> allow only if disk_format in list


Alternatives
------------

1. Put a similar option under [image_conversion] as import_disk_formats
   that widens create for import only, and keep disk_formats strict for
   upload.

   We do not choose this. It makes create schema depend on conversion
   config, and glance-api must load import config for schema. Also it
   is less clear for API users.

2. Change conversion to use detected format when image.disk_format
   equals output_format (treat disk_format as target, not source).

   We do not choose this. It gives disk_format two meanings. API users
   may create raw and upload qcow2. That is confusing and against the
   idea that disk_format matches content.

3. Only use upload_image policy to force import.

   Policy is still the way to disable traditional upload for normal
   users (or for everyone except admin/service). This option does not
   replace that. It only limits which disk_format values may use PUT
   /file when the list is non-empty. Policy and this option can be
   used together.

4. Do nothing and tell operators to keep qcow2 out of disk_formats.

   Then import + conversion for qcow2 does not work in a clean way,
   because user cannot declare qcow2 at create.


Data model impact
-----------------

None


REST API impact
---------------

No new API resource. No change to create image schema.

Method: PUT /v2/images/{image_id}/file

When allowed_upload_formats is set to a non-empty list and the image
disk_format is not in that list, the upload is rejected before data is
stored.

Normal response codes: same as today when upload is allowed.

Expected error:

* 400 Bad Request -- traditional upload is not allowed for this
  image disk_format.

  Error message should be clear so the user knows to use import, or
  to use an allowed format.

Policy: no required policy change. Deployers may still restrict
upload_image to control who can call PUT /file. This option only
limits formats when configured with a non-empty list.

APIImpact: yes, because semantics of PUT /file change when the new
option is configured.


Security impact
---------------

This change does not weaken security. It adds a restriction on
traditional upload.

Conversion plugin behavior stays the same as after CVE-2024-32498:
declared disk_format must match content; unsafe qcow2/vmdk checks
stay.

Users are not encouraged to put wrong disk_format. They should declare
the real format.


Notifications impact
--------------------

None


Other end user impact
---------------------

Users who try PUT /file with a disk_format not in
allowed_upload_formats will get an error. They should use interoperable
image import instead when conversion is enabled.

python-glanceclient: no required change. Same API error will show to
the user. Optional later: nicer message in client.


Performance Impact
------------------

Very small. One list check at the start of upload. No extra database
work in the hot path for successful uploads beyond what exists today.


Other deployer impact
---------------------

New optional config:

  [image_format]
  allowed_upload_formats = <list>

Default: empty / not set -- no behavior change after upgrade. Unset and
empty list are treated the same (no extra PUT restriction).

Deployers who want the new behavior must set a non-empty list on
purpose.

No deprecation of existing options.

disk_formats and output_format keep their current meaning.


Developer impact
----------------

None


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  <launchpad-id or None>

Other contributors:
  None


Work Items
----------

* Add allowed_upload_formats to [image_format] in glance config.
  Default empty; empty and unset mean no extra restriction.

* In upload path (PUT /file), if the list is non-empty, reject when
  image.disk_format is not in the list, with a clear error.

* Unit tests for: empty/unset, list with raw, allowed format, rejected
  format.

* Functional test: create qcow2 image, PUT /file rejected when only
  raw is allowed; import + conversion still works.

* Documentation and releasenote.


Dependencies
============

None

Related: CVE-2024-32498 / bug 2059809 (conversion uses declared
disk_format). This spec does not change that fix; it helps operators
configure upload vs import cleanly with that model.


Testing
=======

Unit tests for the new config check in the upload API.

Functional tests for reject PUT /file and successful import with
conversion.

Tempest: not required for first version. Behavior is config based and
covered by Glance functional tests. We can add Tempest later if needed.


Documentation Impact
====================

Update admin docs for interoperable image import and image format
config. Show examples for raw backend and qcow2 preferred backend.
Note that forcing import for users is still done with upload_image
policy; this option only limits formats when the list is non-empty.


References
==========

* Bug / discussion about conversion and disk_formats after
  CVE-2024-32498 (bug 2059809 related)

* Glance admin guide: interoperable image import, image conversion
  plugin

* Current conversion code uses action.image_disk_format as source
  format and requires content to match
