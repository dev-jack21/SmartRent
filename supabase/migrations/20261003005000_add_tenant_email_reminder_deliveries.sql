create table if not exists public.tenant_email_reminder_deliveries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  due_month date not null,
  days_before integer not null check (days_before >= 0),
  sent_at timestamptz not null default now(),
  unique (property_id, due_month, days_before)
);

create index if not exists tenant_email_reminder_deliveries_user_idx
  on public.tenant_email_reminder_deliveries (user_id, sent_at desc);

alter table public.tenant_email_reminder_deliveries enable row level security;

revoke all on public.tenant_email_reminder_deliveries
  from public, anon, authenticated;
grant select, insert on public.tenant_email_reminder_deliveries
  to service_role;
