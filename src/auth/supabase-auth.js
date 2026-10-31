// Authentication helper scaffold for the Honnasiri workshop app.
// Requires supabase-js v2 and supabase-config.js. This module is not wired into
// index.html yet; do not enable production login until the migration and role
// assignment workflow have been deployed and tested.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './supabase-config.js';

if (!SUPABASE_URL.startsWith('https://') || SUPABASE_URL.includes('YOUR_PROJECT_REF')) {
  throw new Error('Configure Supabase URL and publishable key before enabling authentication.');
}

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    flowType: 'pkce'
  }
});

export async function signInWithGoogle() {
  return supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: window.location.origin + window.location.pathname }
  });
}

export async function signInWithPassword(email, password) {
  return supabase.auth.signInWithPassword({ email, password });
}

export async function signOut() {
  return supabase.auth.signOut();
}

export async function getCurrentStaffProfile() {
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError) throw userError;
  if (!user) return { user: null, profile: null, allowed: false };

  const { data: profile, error } = await supabase
    .from('staff_profiles')
    .select('user_id, display_name, role, is_active')
    .eq('user_id', user.id)
    .maybeSingle();

  if (error) throw error;
  return {
    user,
    profile,
    allowed: Boolean(profile?.is_active && profile.role !== 'pending')
  };
}

export function watchAuthState(callback) {
  return supabase.auth.onAuthStateChange((event, session) => callback(event, session));
}
