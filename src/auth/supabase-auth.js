// Supabase authentication and staff-profile client for Honnasiri Honda Workshop Pro.
// Production use still requires the documented migrations, Edge Function deployment,
// cloud record migration, and role-specific authorization tests.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from '../../supabase-config.js';

if (!SUPABASE_URL.startsWith('https://') || SUPABASE_URL.includes('YOUR_PROJECT_REF') || !SUPABASE_URL.endsWith('.supabase.co')) {
  throw new Error('Configure the complete Supabase project URL and publishable key before enabling authentication.');
}
if (!SUPABASE_ANON_KEY || SUPABASE_ANON_KEY.includes('YOUR_SUPABASE_') || SUPABASE_ANON_KEY.includes('REPLACE_WITH_')) {
  throw new Error('Configure the Supabase publishable/anon key before enabling authentication.');
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

/** Administrator-only staff profile management. Auth user creation remains server/dashboard-only. */
export async function listStaffProfiles() {
  const { data, error } = await supabase
    .from('staff_profiles')
    .select('user_id, display_name, role, is_active, updated_at')
    .order('display_name');
  if (error) throw error;
  return data || [];
}
export async function setStaffAccess(userId, displayName, role, isActive) {
  const { data, error } = await supabase.rpc('admin_set_staff_access', {
    target_user_id: userId,
    new_display_name: displayName,
    new_role: role,
    new_is_active: isActive
  });
  if (error) throw error;
  return data?.[0] || null;
}
