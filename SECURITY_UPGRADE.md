# Honnasiri Honda Workshop Pro: Supabase security upgrade

## Branch safety

All work is committed to `security-auth-upgrade`. The live `main` branch has not been modified. The changes are in draft PR #1 and have not been merged.

## Supabase project

- Project URL: `https://lxrcivgjkvzasjgqvhxh.supabase.co`
- Browser config: `supabase-config.js`
- The staging browser key is intentionally a placeholder until the staging project's publishable key is copied from its API Keys settings. Do not reuse the production project's key. PostgreSQL RLS must enforce data access.
- Never put a Supabase secret key or legacy `service_role` key in browser code, GitHub, or a PWA bundle.

## Implemented in this branch

1. Supabase JS v2 browser client with persistent sessions, automatic refresh, URL session detection, and PKCE.
2. Email/password sign-in and password-reset request.
3. A login gate that hides the workshop interface until Supabase confirms the signed-in user has an active staff profile.
4. Sign-out and signed-in identity/role display.
5. Admin-only staff directory to assign role and active status to existing Auth users.
6. Migration `0002_admin_staff_management.sql` with a SECURITY DEFINER RPC that checks the caller's active admin role and prevents self-lockout.
7. Edge Function `admin-invite-staff` to invite employees server-side after verifying the caller is an active administrator. The service-role key is never sent to the browser.
8. PWA cache version updated for the authentication modules.

## Administrator bootstrap

The first Auth user and matching `staff_profiles` row were created in Supabase. The dashboard query result supplied in this conversation showed the owner's profile with role `admin` and `is_active = true`. Do not repeat the bootstrap update unless account identity changes.

## Required Supabase setup before testing

1. Apply `supabase/migrations/0002_admin_staff_management.sql` in the Supabase SQL Editor. The initial schema/RLS migration 0001 has already been run on the project, as shown in the dashboard screenshots.
2. Enable the Email provider under Supabase Authentication.
3. Add the exact HTTPS staging URL to Authentication → URL Configuration → Redirect URLs. Include the redirect used for password reset and invitation acceptance.
4. Deploy the invitation Edge Function from a trusted computer with the Supabase CLI linked to this project:

   ```sh
   supabase functions deploy admin-invite-staff
   supabase secrets set APP_ORIGIN=https://YOUR-STAGING-HOST APP_REDIRECT_URL=https://YOUR-STAGING-HOST
   ```

   Replace the placeholder with the actual staging host. Set the same origin exactly. Supabase supplies project URL, anon key, and service-role key to Edge Functions as server environment variables. Never paste the service-role key into the frontend or GitHub. If any default variable is not available in the project, configure it only as a server-side Edge Function secret.

5. Configure working email delivery/SMTP and review the invitation template.
6. Keep public sign-up disabled if staff access is invitation-only. The admin panel sends invitations through the Edge Function. Newly invited users are created with a `pending`, inactive profile. The admin must then select the correct role and activate the account in the panel.

## Current app behavior and limitations

The sign-in gate and staff administration UI are committed but cannot be fully exercised until migration 0002 and the Edge Function are deployed. The security branch is isolated to the staging project URL. Its publishable key remains a placeholder, so the browser app will fail closed until the staging key is configured.

**Workshop records have not yet been migrated to Supabase.** The service form still reads/writes localStorage and the optional legacy Google Drive JSON file. The `workshop_records` table exists, but the app is not yet using it. Therefore, RLS does not protect records still stored locally or in Drive.

Remaining production work:
- Migrate and reconcile records from each device and the Drive JSON file, preserving legacy IDs and backups.
- Replace synchronous local record access with a tested cloud repository.
- Enforce least-privilege, role-specific write operations. Current technician row policy is not column-restricted; do not rely on it as final authorization.
- Implement final-inspector approval through a narrow audited RPC.
- Add concurrency control, validation, audit review, backup/restore, and automated RLS tests for all roles.
- Test pending-user denial, invitation acceptance, password reset, role assignment, deactivation, sign-out, and unauthorized reads/writes on staging.

Do not merge this branch, connect the live app to it, or enter live customer data until the remaining record migration and authorization work is complete and verified.

## Deployment files

- `supabase/migrations/0001_workshop_security_foundation.sql`: initial schema, triggers, and RLS.
- `supabase/migrations/0002_admin_staff_management.sql`: admin-only staff role/activation RPC.
- `supabase/functions/admin-invite-staff/index.ts`: server-side employee invitation.
- `src/auth/supabase-auth.js`: browser auth client and staff profile operations.
- `index.html`: login gate and admin staff panel.


## Staging isolation correction (2026-10-31)

The security branch browser configuration now points to the staging project ref `lxrcivgjkvzasjgqvhxh`, not the production project. The publishable key is deliberately a placeholder. This prevents accidental authentication against production while staging is being completed. Replace it only with the staging project's publishable key.

The successful Edge Function deployment does not deploy the frontend, apply migrations, configure Auth email delivery, or migrate localStorage/Google Drive workshop records. Do not use this branch as the live workshop app until those tasks and the role-based RLS tests are complete.
