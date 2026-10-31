# Honnasiri Honda Workshop Pro: security upgrade foundation

## Safety boundary

This work is on the `security-auth-upgrade` branch. The existing `main` branch and live app are unchanged.

This branch contains an initial Supabase authentication/database foundation. It is **not yet a completed or production-enabled login upgrade**. The helper module is intentionally not wired into `index.html`, because doing so before a real Supabase project, redirect URLs, role assignment, and RLS validation exist could lock out staff or give a false sense of security.

## Target design

- Supabase Auth for individual staff identities (Google OAuth and/or email/password).
- A `staff_profiles` table with administrator-assigned roles.
- New users default to `pending` and `is_active = false`.
- PostgreSQL Row Level Security (RLS) is the enforcement boundary. Hiding UI controls is not authorization.
- Workshop records stored centrally, with assigned-technician scoping.
- Audit events record actor, action, record ID, and changed field names, not full customer payloads.
- Supabase Auth manages short-lived access tokens and refresh tokens. The browser SDK handles refresh; no service-role secret belongs in browser code.

## Files added

- `supabase/migrations/0001_workshop_security_foundation.sql`: starter schema, profile bootstrap, RLS, and audit trigger.
- `supabase-config.example.js`: browser-safe configuration template.
- `src/auth/supabase-auth.js`: auth helper scaffold using PKCE and session refresh.

## Required setup before app integration

1. Supabase project created: `honnasiri-honda-workshop` (`https://dsznwcwuypyjrndjaicw.supabase.co`). The browser-safe publishable key is configured in the branch file `supabase-config.js`.
2. Configure Authentication providers. If using Google, configure Google OAuth credentials in Supabase and set the exact authorized redirect URL shown by Supabase. Do not reuse the current direct-to-Google Drive OAuth client as a substitute for Supabase provider configuration.
3. Apply the migration in the Supabase SQL editor or CLI.
4. Create the first administrator through a controlled bootstrap procedure. Do not let a public sign-up choose its own role. The trigger deliberately creates all new accounts as inactive `pending`.
5. Configure the app's exact HTTPS URL in Supabase redirect allowlists.
6. Copy `supabase-config.example.js` to `supabase-config.js`, then supply the project URL and publishable/anon key. Keep this key public only with RLS enabled and tested. Never add a service_role/secret key.
7. Test each role using separate accounts and verify unauthorized reads/writes are rejected by PostgreSQL, not merely hidden in the interface.

## Important incomplete items

The initial RLS migration is a foundation, not final authorization. In particular:
- Technician updates currently have row-level assignment checks but still need column-level enforcement through narrow database RPCs.
- Final-inspector approval/write access needs a dedicated RPC with allowed QC fields and audit logging.
- Admin bootstrap, account invitation/deactivation, password reset, login UI, route/app gating, and session timeout policy must be implemented and tested.
- Existing localStorage and Google Drive JSON records need a validated one-time migration and reconciliation process before switching storage.
- Concurrency-safe updates, record schema validation, backup/restore, and security tests are required before production.
- The current app's existing Google Drive token flow must remain separate until its replacement or continued use is deliberately decided.

## Do not deploy as production yet

Do not merge this branch or point the live app at it until the incomplete items above are completed, tested on a staging URL, and a backup/rollback plan is verified.
