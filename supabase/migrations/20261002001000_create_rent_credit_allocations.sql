create table if not exists public.rent_credit_allocations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  source_month date not null,
  target_month date not null,
  amount numeric(12, 2) not null check (amount > 0),
  created_at timestamptz not null default now(),
  check (source_month = date_trunc('month', source_month::timestamp)::date),
  check (target_month = date_trunc('month', target_month::timestamp)::date),
  check (target_month > source_month)
);

create index if not exists rent_credit_allocations_user_property_idx
  on public.rent_credit_allocations (user_id, property_id, source_month);

alter table public.rent_credit_allocations enable row level security;

drop policy if exists rent_credit_allocations_owner_access
  on public.rent_credit_allocations;

create policy rent_credit_allocations_owner_access
  on public.rent_credit_allocations
  for all
  to authenticated
  using (
    user_id = auth.uid()
    and exists (
      select 1
      from public.properties as property
      where property.id = rent_credit_allocations.property_id
        and property.user_id = auth.uid()
    )
  )
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.properties as property
      where property.id = rent_credit_allocations.property_id
        and property.user_id = auth.uid()
    )
  );

grant select, insert, update, delete
  on public.rent_credit_allocations to authenticated;