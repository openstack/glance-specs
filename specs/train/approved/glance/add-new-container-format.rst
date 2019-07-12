..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===================================
Spec Lite: Add new container format
===================================

..
  Mandatory sections

:project: glance

:problem: Compression method using hardware to accelerate has already been
          implemented in cinder project. A new container format 'compressed'
          needs to be added to container format list in glance to support
          this.

:solution: A new container format 'compressed' option needs to be added to the
           default container_format configuration list.

:impacts: New container format option


..
  Optional sections -- delete any that don't apply to this spec lite

:how: If users chose to upload volume using compression method, cinder will do
      compression and then upload to glance. The uploaded image's metadata will be
      'compressed' in container_format so that it can be correctly processed after
      downloaded. Volume disk_format will not be changed by this compression
      process.

      * Glance will not handle the compression and decompression progress, which
        means glance will not check if it is a vaild compressed image. Whoever is to
        upload or download the image is responsible for compression or
        decompression.
      * Uploaded image will not be automatically compressed if simply changing the
        container_format as 'compressed'. Compression or decompression happens when
        image is uploading from volume or downloading to a volume.
      * Glance will not identify what format the compressed image really is. In
        glance's view, it is just a blob. Image consumer (such as cinder) will
        identify the real format such as gzip, rar or other format.

:other impact: Nova cannot currently handle images in a compressed container format.
               We propose patching Nova to reject such images:
               https://review.opendev.org/#/c/673407/

:timeline: Include in train release

:link: https://review.opendev.org/#/c/652275/

:assignee: ZhengMa
