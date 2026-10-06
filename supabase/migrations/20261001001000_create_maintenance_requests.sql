create table if not exists public.maintenance_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  title text not null check (length(btrim(title)) > 0),
  description text not null default '',
  priority text not null default 'Medium'
    check (priority in ('Low', 'Medium', 'High')),
  status text not null default 'Open'
    check (status in ('Open', 'In Progress', 'Completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists maintenance_requests_user_created_idx
  on public.maintenance_requests (user_id, created_at desc);

alter table public.maintenance_requests enable row level security;

drop policy if exists maintenance_requests_owner_access
  on public.maintenance_requests;

create policy maintenance_requests_owner_access
  on public.maintenance_requests
  for all
  to authenticated
  using (
    user_id = auth.uid()
    and exists (
      select 1
      from public.properties as property
      where property.id = maintenance_requests.property_id
        and property.user_id = auth.uid()
    )
  )
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.properties as property
      where property.id = maintenance_requests.property_id
        and property.user_id = auth.uid()
    )
  );

grant select, insert, update, delete
  on public.maintenance_requests to authenticated;
