-- Admin-only staff profile administration.
-- Auth identities are still created through Supabase Auth (or a trusted Edge Function).
-- This RPC only assigns application role and active status to an existing Auth user.
create or replace function public.admin_set_staff_access(
  target_user_id uuid,
  new_display_name text,
  new_role text,
  new_is_active boolean
)
returns table(user_id uuid, display_name text, role text, is_active boolean, updated_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null
     or public.current_staff_role() <> 'admin' then
    raise exception 'Administrator permission required' using errcode = '42501';
  end if;

  if target_user_id = (select auth.uid()) then
    raise exception 'Use a separate administrator to change your own access' using errcode = '42501';
  end if;

  if new_role not in ('pending','admin','floor_incharge','service_advisor','technician','final_inspector') then
    raise exception 'Invalid staff role' using errcode = '22023';
  end if;

  return query
  update public.staff_profiles p
  set display_name = coalesce(nullif(btrim(new_display_name), ''), p.display_name),
      role = new_role,
      is_active = new_is_active,
      updated_at = now()
  where p.user_id = target_user_id
  returning p.user_id, p.display_name, p.role, p.is_active, p.updated_at;

  if not found then
    raise exception 'Staff profile not found. Create the Auth user first.' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.admin_set_staff_access(uuid,text,text,boolean) from public, anon;
grant execute on function public.admin_set_staff_access(uuid,text,text,boolean) to authenticated;
