alter table public.property_expenses
  add column if not exists status text not null default 'paid',
  add column if not exists paid_date date,
  add column if not exists recurring_rule_id uuid,
  add column if not exists recurrence_date date;

update public.property_expenses
set paid_date = expense_date
where status = 'paid' and paid_date is null;

alter table public.property_expenses
  drop constraint if exists property_expenses_status_check;

alter table public.property_expenses
  add constraint property_expenses_status_check
  check (status in ('planned', 'paid'));

alter table public.property_expenses
  drop constraint if exists property_expenses_recurring_rule_id_fkey;

create table if not exists public.recurring_expense_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  amount numeric(12, 2) not null check (amount > 0),
  category text not null default 'Other'
    check (category in ('Repairs', 'Insurance', 'Taxes', 'Utilities', 'Management', 'Other')),
  frequency text not null check (frequency in ('monthly', 'yearly')),
  next_due_date date not null,
  anchor_month smallint not null check (anchor_month between 1 and 12),
  anchor_day smallint not null check (anchor_day between 1 and 31),
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.property_expenses
  add constraint property_expenses_recurring_rule_id_fkey
  foreign key (recurring_rule_id)
  references public.recurring_expense_rules(id)
  on delete set null;

create unique index if not exists property_expenses_recurring_occurrence_idx
  on public.property_expenses (recurring_rule_id, recurrence_date);

create index if not exists recurring_expense_rules_user_due_idx
  on public.recurring_expense_rules (user_id, next_due_date)
  where is_active;

alter table public.recurring_expense_rules enable row level security;

drop policy if exists recurring_expense_rules_owner_access
  on public.recurring_expense_rules;

create policy recurring_expense_rules_owner_access
  on public.recurring_expense_rules
  for all
  to authenticated
  using (
    user_id = auth.uid()
    and exists (
      select 1
      from public.properties as property
      where property.id = recurring_expense_rules.property_id
        and property.user_id = auth.uid()
    )
  )
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.properties as property
      where property.id = recurring_expense_rules.property_id
        and property.user_id = auth.uid()
    )
  );

grant select, insert, update, delete
  on public.recurring_expense_rules to authenticated;
