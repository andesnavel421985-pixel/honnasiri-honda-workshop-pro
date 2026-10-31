-- Honnasiri Honda Workshop Pro: close direct staff-profile mutation path.
-- Apply after 0002. Role and activation changes must go through the
-- SECURITY DEFINER admin_set_staff_access RPC, which blocks self-modification.

begin;

revoke insert, update, delete on table public.staff_profiles from anon, authenticated;
grant select on table public.staff_profiles to authenticated;

revoke all on function public.admin_set_staff_access(uuid,text,text,boolean) from public, anon;
grant execute on function public.admin_set_staff_access(uuid,text,text,boolean) to authenticated;

commit;
