import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const appOrigin = Deno.env.get("APP_ORIGIN");
const corsHeaders = {
  ...(appOrigin ? { "Access-Control-Allow-Origin": appOrigin } : {}),
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    if (!appOrigin || req.headers.get("Origin") !== appOrigin) return new Response("Forbidden", { status: 403 });
    return new Response("ok", { headers: corsHeaders });
  }
  if (!appOrigin || req.headers.get("Origin") !== appOrigin) return json({ error: "Origin not allowed" }, 403);
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return json({ error: "Authentication required" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json({ error: "Server authentication is not configured" }, 500);
  }

  try {
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: userError } = await callerClient.auth.getUser();
    if (userError || !user) return json({ error: "Invalid or expired session" }, 401);

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: profile, error: profileError } = await adminClient
      .from("staff_profiles")
      .select("role,is_active")
      .eq("user_id", user.id)
      .maybeSingle();

    if (profileError) return json({ error: "Could not verify administrator access" }, 500);
    if (profile?.role !== "admin" || profile?.is_active !== true) {
      return json({ error: "Active administrator permission required" }, 403);
    }

    const body = await req.json();
    const email = String(body?.email ?? "").trim().toLowerCase();
    const displayName = String(body?.displayName ?? "").trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return json({ error: "Enter a valid staff email address" }, 400);
    }
    if (displayName.length < 2 || displayName.length > 100) {
      return json({ error: "Staff name must be between 2 and 100 characters" }, 400);
    }

    const redirectTo = Deno.env.get("APP_REDIRECT_URL");
    const { data, error } = await adminClient.auth.admin.inviteUserByEmail(email, {
      data: { full_name: displayName },
      ...(redirectTo ? { redirectTo } : {}),
    });
    if (error) return json({ error: error.message }, 400);

    return json({
      invited: true,
      userId: data.user?.id,
      email: data.user?.email,
      message: "Invitation sent. The new staff profile remains pending and inactive until an administrator assigns a role.",
    }, 201);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unexpected server error" }, 500);
  }
});
