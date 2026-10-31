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

1. In Supabase Authentication settings, enable Email provider.
2. Set the app's actual HTTPS staging URL in the allowed redirect URLs.
3. Configure password reset redirect URLs for the same staging host.
4. Keep public sign-up disabled if the project is intended for invited employees only. Admin provisioning must be implemented through a trusted server/Edge Function; never expose the service-role key in the browser.
5. Test login with the owner admin and a separate pending user. The pending user must be denied access.

## Recommended next implementation sequence

1. Build a trusted admin provisioning function for staff invitations, role assignment, activation, and deactivation.
2. Implement a versioned data migration from localStorage/Drive JSON to `workshop_records`, preserving legacy IDs and reconciling duplicates.
3. Replace synchronous local record reads/writes with a cloud-backed repository and safe loading/error states.
4. Tighten database authorization with field-specific RPCs for technicians and final inspectors, plus immutable audit handling.
5. Add automated RLS tests for every role and negative access case.
6. Test on a staging URL with backups and rollback before any production cutover.
