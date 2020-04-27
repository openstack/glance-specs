..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=========================================
Spec Lite: Deprecate Checksum Computation
=========================================

..
  Mandatory sections

:project: glance

:problem: The glance 'checksum' image property contains an MD5 hash of image
          data.  MD5 has not been considered secure for some time, and in
          order to comply with various security standards, an implementation
          of the MD5 algorithm may not be available on glance nodes.

:solution: Announce that Glance will no longer populate the 'checksum' on new
           images beginning with the Victoria release.  Instead, operators
           should rely on the secure "multihash" feature that was introduced
           in Rocky.  The 'checksum' property will remain on legacy images.

:impacts: None.

..
  Optional sections -- delete any that don't apply to this spec lite

:how: In Ussuri: release note.  In Victoria: Remove the code that uses MD5.
      (This will affect primarily the glance_store drivers.)

:alternatives: We could check to see if the algorithm is available, and if it
               is, compute the MD5.  But this seems pointless as the secure
               multihash is already being computed for all new images.

               We could remove the 'checksum' entirely, but this would require
               a migration to the multihash.  For at least some backends, this
               would mean downloading the image data for each legacy image to
               do the computation, which could take a very long time.

:timeline: Deprecation and release note in Ussuri; removal in Victoria.
