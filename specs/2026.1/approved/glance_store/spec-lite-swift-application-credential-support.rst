..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==============================================================
Spec Lite: Add Application Credential Support to Swift Backend
==============================================================

:project: glance_store

:problem: The Swift backend driver in glance_store currently uses V3Password
          authentication for trustee authentication when using service user
          credentials. This prevents Zero Downtime Password Rotation (ZDPR)
          from working for Glance deployments using Swift as the image backend.

          When the service user password is rotated during ZDPR, Swift backend
          operations fail because the driver cannot authenticate using the
          rotated password. This creates a critical gap in ZDPR functionality,
          as image uploads and downloads to/from Swift containers will fail
          during password rotation, defeating the zero-downtime goal.

          The main Glance API service already supports application credentials
          via keystonemiddleware, but backend storage operations (Swift and
          Cinder) do not support application credentials, creating an incomplete
          ZDPR implementation.

:solution: Add application credential support to the Swift backend driver by:

           1. Adding configuration options for application credentials:
              - application_credential_id (registered in both [swift] and
              [backend_defaults] groups)
              - application_credential_secret (registered in both [swift] and
              [backend_defaults] groups, marked as secret)

           2. Modifying the Swift driver's authentication logic to:
              - Use BackendGroupConfiguration to read configuration (supports
              fallback to [backend_defaults] section)
              - Check for application credential configuration first
              - Use V3ApplicationCredential authentication if AC credentials
              are available
              - Fall back to V3Password authentication if AC credentials are
              not configured (backward compatible)

           3. Update both SingleTenantStore and MultiTenantStore init_client()
              functions to support application credentials for trustee
              authentication.

           This unified approach allows Swift backend to use the same AC
           credentials from [backend_defaults] section (when same service user
           is used) or per-backend overrides (when different service users are
           configured), aligning with existing glance_store architecture.

:how:

      - Add application_credential_id and application_credential_secret options
        to Swift driver configuration options
      - Update SingleTenantStore.init_client() and MultiTenantStore.init_client()
        to check for AC credentials and use V3ApplicationCredential when
        available
      - Maintain backward compatibility by falling back to V3Password if AC
        credentials are not provided

:alternatives: None

:impacts: DocImpact, ConfigImpact

:timeline: Include in 2026.1 release (or next appropriate release cycle)

:link: None

:reviewers: croelandt, rosmaita

:assignee: abhishekk

