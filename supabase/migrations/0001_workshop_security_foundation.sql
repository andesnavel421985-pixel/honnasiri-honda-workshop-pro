-- Honnasiri Honda Workshop Pro: initial Supabase security foundation
-- Apply only to a NEW Supabase project after reviewing the deployment guide.
-- Never put a service_role key in browser code.

create extension if not exists pgcrypto;

create table if not exists public.staff_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  role text not null default 'pending'
    check (role in ('pending','admin','floor_incharge','service_advisor','technician','final_inspector')),
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.current_staff_role()
returns text
language sql stable security definer
set search_path = ''
as $$
  select p.role
  from public.staff_profiles p
  where p.user_id = (select auth.uid())
    and p.is_active = true
  limit 1;
$$;

create or replace function public.is_active_staff()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.staff_profiles p
    where p.user_id = (select auth.uid()) and p.is_active = true
  );
$$;

-- New identities receive no operational access until an administrator assigns a role.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  insert into public.staff_profiles(user_id, display_name, role, is_active)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.email, ''),
    'pending',
    false
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_workshop on auth.users;
create trigger on_auth_user_created_workshop
after insert on auth.users
for each row execute procedure public.handle_new_auth_user();

create table if not exists public.workshop_records (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  record_data jsonb not null default '{}'::jsonb,
  assigned_technician uuid references public.staff_profiles(user_id),
  created_by uuid not null default auth.uid() references public.staff_profiles(user_id),
  updated_by uuid default auth.uid() references public.staff_profiles(user_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists workshop_records_assigned_technician_idx
  on public.workshop_records(assigned_technician);
create index if not exists workshop_records_updated_at_idx
  on public.workshop_records(updated_at desc);

create table if not exists public.workshop_audit_log (
  id bigint generated always as identity primary key,
  record_id uuid,
  actor_user_id uuid,
  action text not null check (action in ('INSERT','UPDATE','DELETE')),
  changed_fields text[] not null default '{}',
  occurred_at timestamptz not null default now()
);

create or replace function public.set_workshop_record_metadata()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end;
$$;

drop trigger if exists set_workshop_record_metadata_trigger on public.workshop_records;
create trigger set_workshop_record_metadata_trigger
before update on public.workshop_records
for each row execute procedure public.set_workshop_record_metadata();

create or replace function public.audit_workshop_record()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  changed text[] := '{}';
  rid uuid;
begin
  if tg_op = 'INSERT' then
    rid := new.id;
    changed := array(select jsonb_object_keys(new.record_data));
  elsif tg_op = 'UPDATE' then
    rid := new.id;
    select coalesce(array_agg(k), '{}') into changed
    from (
      select key as k
      from jsonb_each(coalesce(old.record_data, '{}'::jsonb))
      union
      select key as k
      from jsonb_each(coalesce(new.record_data, '{}'::jsonb))
    ) keys
    where (old.record_data -> keys.k) is distinct from (new.record_data -> keys.k);
  else
    rid := old.id;
  end if;

  insert into public.workshop_audit_log(record_id, actor_user_id, action, changed_fields)
  values (rid, auth.uid(), tg_op, changed);

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists audit_workshop_record_trigger on public.workshop_records;
create trigger audit_workshop_record_trigger
after insert or update or delete on public.workshop_records
for each row execute procedure public.audit_workshop_record();

alter table public.staff_profiles enable row level security;
alter table public.workshop_records enable row level security;
alter table public.workshop_audit_log enable row level security;

-- Staff can read their own profile. Only active administrators can read/update all profiles.
drop policy if exists "staff read own profile" on public.staff_profiles;
create policy "staff read own profile"
on public.staff_profiles for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "admins read all profiles" on public.staff_profiles;
create policy "admins read all profiles"
on public.staff_profiles for select to authenticated
using (public.current_staff_role() = 'admin');

drop policy if exists "admins update profiles" on public.staff_profiles;
create policy "admins update profiles"
on public.staff_profiles for update to authenticated
using (public.current_staff_role() = 'admin')
with check (public.current_staff_role() = 'admin');

-- All active staff may read records needed for workshop work, but pending users cannot.
drop policy if exists "active staff read workshop records" on public.workshop_records;
create policy "active staff read workshop records"
on public.workshop_records for select to authenticated
using (
  public.current_staff_role() in ('admin','floor_incharge','service_advisor','final_inspector')
  or (
    public.current_staff_role() = 'technician'
    and assigned_technician = (select auth.uid())
  )
);

drop policy if exists "advisors and managers create records" on public.workshop_records;
create policy "advisors and managers create records"
on public.workshop_records for insert to authenticated
with check (
  public.current_staff_role() in ('admin','floor_incharge','service_advisor')
  and created_by = (select auth.uid())
);

drop policy if exists "managers and advisors update records" on public.workshop_records;
create policy "managers and advisors update records"
on public.workshop_records for update to authenticated
using (public.current_staff_role() in ('admin','floor_incharge','service_advisor'))
with check (public.current_staff_role() in ('admin','floor_incharge','service_advisor'));

-- Technician updates are restricted to assigned jobs at row level.
-- Column-level restrictions / controlled RPCs must be added before production use.
drop policy if exists "technicians update assigned records" on public.workshop_records;
create policy "technicians update assigned records"
on public.workshop_records for update to authenticated
using (
  public.current_staff_role() = 'technician'
  and assigned_technician = (select auth.uid())
)
with check (
  public.current_staff_role() = 'technician'
  and assigned_technician = (select auth.uid())
);

drop policy if exists "inspectors read records" on public.workshop_records;
create policy "inspectors read records"
on public.workshop_records for select to authenticated
using (public.current_staff_role() = 'final_inspector');

-- Audit events are read-only to administrators and floor incharges.
drop policy if exists "managers read audit log" on public.workshop_audit_log;
create policy "managers read audit log"
on public.workshop_audit_log for select to authenticated
using (public.current_staff_role() in ('admin','floor_incharge'));

revoke all on public.staff_profiles, public.workshop_records, public.workshop_audit_log from anon;
grant select, update on public.staff_profiles to authenticated;
grant select, insert, update, delete on public.workshop_records to authenticated;
grant select on public.workshop_audit_log to authenticated;

-- IMPORTANT:
-- This foundation deliberately does not grant final_inspector write access or
-- technician column-level restrictions yet. Implement those through narrow,
-- audited SECURITY DEFINER RPCs before enabling the production app.
-- Do not treat the current JSONB record table as production-ready until those
-- RPCs, validation, concurrency handling, and migration tests are completed.
