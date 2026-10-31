# Honnasiri Honda Workshop Pro: Supabase security upgrade

## Branch safety

All changes in this work are committed to `security-auth-upgrade`. The live `main` branch has not been modified.

## Supabase project

- Project URL: `https://dsznwcwuypyjrndjaicw.supabase.co`
- Browser configuration: `supabase-config.js`
- The configured `sb_publishable_` key is a public client key, not a secret. Database security must be enforced by PostgreSQL RLS.
- Never place a Supabase secret key or legacy `service_role` key in browser code, GitHub, or a PWA bundle.

## Implemented on this branch

1. Initial database foundation in `supabase/migrations/0001_workshop_security_foundation.sql`.
2. Administrator-only staff role/activation RPC in `supabase/migrations/0002_admin_staff_management.sql`.
3. In-app administrator staff directory to assign roles and activate/deactivate existing Auth users.
2. Staff profiles default to `pending` and inactive when a Supabase Auth user is created.
3. RLS enabled on `staff_profiles`, `workshop_records`, and `workshop_audit_log`.
4. Supabase JS v2 browser client configured with persistent sessions, automatic token refresh, URL session detection, and PKCE.
5. Email/password sign-in and password-reset request helpers.
6. `index.html` now displays a Supabase sign-in gate. The workshop UI is hidden until Supabase confirms a signed-in user has an active staff profile. Inactive/pending users are signed out and denied access.
7. Sign-out control and visible signed-in identity/role.
8. PWA cache version updated so the new authentication code is fetched.

## Administrator bootstrap already completed

The project owner manually created the first Auth user and assigned the matching `staff_profiles` row:
- Account: owner-controlled Gmail account
- Role: `admin`
- `is_active`: `true`

The database query result was visually verified in the Supabase dashboard. Do not repeat the bootstrap update unless the account changes.

## Important current limitation: not production-ready

The sign-in gate authenticates access to the user interface, but the existing workshop record functions still use browser `localStorage` and the legacy optional Google Drive JSON sync. The app has **not yet migrated workshop records to Supabase**. Consequently:

- Existing records are still device/browser-local or in the legacy Drive JSON file.
- RLS policies on `workshop_records` do not protect records that remain in localStorage or Drive.
- The current UI does not yet enforce complete role-specific field permissions.
- The technician update policy is row-scoped but not column-scoped.
- Final-inspector write/approval needs a narrow audited RPC.
- Admin user invitation, activation/deactivation screens, concurrency-safe record writes, validation, backups, migration/reconciliation, and automated authorization tests remain to be implemented.
- The old Google Drive OAuth integration is separate and remains in the app.

Do not merge, deploy as production, or enter real customer data on this branch until cloud record storage, role-specific database permissions, migration, and staging tests are complete.

## Supabase Auth configuration

1. Apply `supabase/migrations/0002_admin_staff_management.sql` in the Supabase SQL Editor. Migration 0001 created the core tables and RLS; migration 0002 adds the admin-only role assignment RPC.
2. In Supabase Authentication settings, enable Email provider.
3. Set the app's actual HTTPS staging URL in the allowed redirect URLs.
4. Configure password reset redirect URLs for the same staging host.
5. Keep public sign-up disabled if the project is intended for invited employees only. Create each Auth identity through Supabase Authentication → Users (Send invitation or Create user), then use the in-app administrator panel to assign the role and activate it. Do not expose the service-role key in the browser.
6. Test login with the owner admin and a separate pending user. The pending user must be denied access.

## Recommended next implementation sequence

1. Build a trusted admin provisioning function for staff invitations, role assignment, activation, and deactivation.
2. Implement a versioned data migration from localStorage/Drive JSON to `workshop_records`, preserving legacy IDs and reconciling duplicates.
3. Replace synchronous local record reads/writes with a cloud-backed repository and safe loading/error states.
4. Tighten database authorization with field-specific RPCs for technicians and final inspectors, plus immutable audit handling.
5. Add automated RLS tests for every role and negative access case.
6. Test on a staging URL with backups and rollback before any production cutover.


## Staff administration panel

After migration 0002 is applied, an active admin sees a Staff access management panel after signing in. It can list existing profiles and update role/active status through the SECURITY DEFINER RPC, which checks the caller's current active admin role in the database. It intentionally prevents an admin from changing their own access. It does not create Auth identities; create/invite an Auth user in Supabase Authentication → Users first. The auth trigger creates that person's inactive pending profile.

## Not yet connected

The workshop form still reads/writes the legacy localStorage store. The cloud `workshop_records` table exists but the app has not switched to it. The current staff panel is role administration only; it does not complete the record migration or role-specific field restrictions.
