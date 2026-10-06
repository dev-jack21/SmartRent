create table if not exists public.property_expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  amount numeric(12, 2) not null check (amount > 0),
  category text not null default 'Other'
    check (category in ('Repairs', 'Insurance', 'Taxes', 'Utilities', 'Management', 'Other')),
  expense_date date not null default current_date,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists property_expenses_user_date_idx
  on public.property_expenses (user_id, expense_date desc);

alter table public.property_expenses enable row level security;

drop policy if exists property_expenses_owner_access
  on public.property_expenses;

create policy property_expenses_owner_access
  on public.property_expenses
  for all
  to authenticated
  using (
    user_id = auth.uid()
    and exists (
      select 1
      from public.properties as property
      where property.id = property_expenses.property_id
        and property.user_id = auth.uid()
    )
  )
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.properties as property
      where property.id = property_expenses.property_id
        and property.user_id = auth.uid()
    )
  );

grant select, insert, update, delete
  on public.property_expenses to authenticated;
