-- Add building_name and is_vacant to properties
alter table public.properties
  add column if not exists building_name text,
  add column if not exists is_vacant boolean not null default false;

-- Create utility_bills table
create table if not exists public.utility_bills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  utility_type text not null check (utility_type in ('Water', 'Electricity', 'Internet', 'Gas', 'Trash / Service', 'Other')),
  previous_reading numeric(12, 2),
  current_reading numeric(12, 2),
  rate_per_unit numeric(12, 2),
  total_amount numeric(12, 2) not null,
  bill_month date not null,
  status text not null default 'unpaid' check (status in ('unpaid', 'paid')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists utility_bills_user_month_idx
  on public.utility_bills (user_id, bill_month desc);

create index if not exists utility_bills_property_idx
  on public.utility_bills (property_id);

alter table public.utility_bills enable row level security;

-- Owner policy for utility bills
drop policy if exists utility_bills_owner_access on public.utility_bills;
create policy utility_bills_owner_access
  on public.utility_bills
  for all
  to authenticated
  using (
    user_id = auth.uid()
    and exists (
      select 1
      from public.properties as property
      where property.id = utility_bills.property_id
        and property.user_id = auth.uid()
    )
  )
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.properties as property
      where property.id = utility_bills.property_id
        and property.user_id = auth.uid()
    )
  );

-- Tenant read policy for utility bills
drop policy if exists tenant_select_linked_property_utility_bills on public.utility_bills;
create policy tenant_select_linked_property_utility_bills
  on public.utility_bills
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.properties as tenant_property
      where tenant_property.id = utility_bills.property_id
        and tenant_property.user_id = utility_bills.user_id
        and lower(btrim(tenant_property.tenant_email)) =
          lower(btrim((select auth.jwt()) ->> 'email'))
    )
  );

grant select, insert, update, delete on public.utility_bills to authenticated;

-- Tenant maintenance request permissions (submit and view for linked properties)
drop policy if exists tenant_select_linked_property_maintenance on public.maintenance_requests;
create policy tenant_select_linked_property_maintenance
  on public.maintenance_requests
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.properties as tenant_property
      where tenant_property.id = maintenance_requests.property_id
        and tenant_property.user_id = maintenance_requests.user_id
        and lower(btrim(tenant_property.tenant_email)) =
          lower(btrim((select auth.jwt()) ->> 'email'))
    )
  );

drop policy if exists tenant_insert_linked_property_maintenance on public.maintenance_requests;
create policy tenant_insert_linked_property_maintenance
  on public.maintenance_requests
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.properties as tenant_property
      where tenant_property.id = maintenance_requests.property_id
        and tenant_property.user_id = maintenance_requests.user_id
        and lower(btrim(tenant_property.tenant_email)) =
          lower(btrim((select auth.jwt()) ->> 'email'))
    )
  );

-- Tenant property document viewing
drop policy if exists tenant_select_linked_property_documents on public.property_documents;
create policy tenant_select_linked_property_documents
  on public.property_documents
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.properties as tenant_property
      where tenant_property.id = property_documents.property_id
        and tenant_property.user_id = property_documents.user_id
        and lower(btrim(tenant_property.tenant_email)) =
          lower(btrim((select auth.jwt()) ->> 'email'))
    )
  );

-- Tenant payment proof submission (pending status)
drop policy if exists tenant_insert_pending_payment on public.payments;
create policy tenant_insert_pending_payment
  on public.payments
  for insert
  to authenticated
  with check (
    status = 'pending'
    and exists (
      select 1
      from public.properties as tenant_property
      where tenant_property.id = payments.property_id
        and tenant_property.user_id = payments.user_id
        and lower(btrim(tenant_property.tenant_email)) =
          lower(btrim((select auth.jwt()) ->> 'email'))
    )
  );
