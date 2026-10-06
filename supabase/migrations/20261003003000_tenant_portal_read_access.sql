alter table public.profiles
  add column if not exists role text;

update public.profiles
set role = 'owner'
where role is null
   or role not in ('owner', 'tenant');

alter table public.profiles
  alter column role set default 'owner',
  alter column role set not null;

update public.properties
set tenant_email = lower(btrim(tenant_email))
where tenant_email is not null
  and tenant_email is distinct from lower(btrim(tenant_email));

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_role_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_role_check check (role in ('owner', 'tenant'));
  end if;
end
$$;

create or replace function public.tenant_portal_create_profile_for_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_role text;
begin
  selected_role := case
    when new.raw_user_meta_data ->> 'account_role' = 'tenant' then 'tenant'
    else 'owner'
  end;

  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
      new.email
    ),
    selected_role
  )
  on conflict (id) do update
    set role = excluded.role;

  return new;
end;
$$;

drop trigger if exists tenant_portal_auth_user_profile on auth.users;
create trigger tenant_portal_auth_user_profile
  after insert on auth.users
  for each row execute function public.tenant_portal_create_profile_for_auth_user();

create or replace function public.prevent_client_profile_role_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is not null and new.role is distinct from old.role then
    raise exception 'Account role cannot be changed by an authenticated user'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_client_profile_role_change on public.profiles;
create trigger prevent_client_profile_role_change
  before update of role on public.profiles
  for each row execute function public.prevent_client_profile_role_change();

alter table public.properties enable row level security;
alter table public.payments enable row level security;
alter table public.rent_credit_allocations enable row level security;
alter table public.profiles enable row level security;

grant select on public.properties, public.payments, public.rent_credit_allocations,
  public.profiles to authenticated;

drop policy if exists tenant_select_linked_properties on public.properties;
create policy tenant_select_linked_properties
  on public.properties
  for select
  to authenticated
  using (
    lower(btrim(tenant_email)) = lower(btrim((select auth.jwt()) ->> 'email'))
  );

drop policy if exists tenant_select_linked_property_payments on public.payments;
create policy tenant_select_linked_property_payments
  on public.payments
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.properties as tenant_property
      where tenant_property.id = payments.property_id
        and tenant_property.user_id = payments.user_id
        and lower(btrim(tenant_property.tenant_email)) =
          lower(btrim((select auth.jwt()) ->> 'email'))
    )
  );

drop policy if exists tenant_select_linked_property_credit_allocations
  on public.rent_credit_allocations;
create policy tenant_select_linked_property_credit_allocations
  on public.rent_credit_allocations
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.properties as tenant_property
      where tenant_property.id = rent_credit_allocations.property_id
        and tenant_property.user_id = rent_credit_allocations.user_id
        and lower(btrim(tenant_property.tenant_email)) =
          lower(btrim((select auth.jwt()) ->> 'email'))
    )
  );

drop policy if exists profiles_select_own_role on public.profiles;
create policy profiles_select_own_role
  on public.profiles
  for select
  to authenticated
  using (id = auth.uid());
