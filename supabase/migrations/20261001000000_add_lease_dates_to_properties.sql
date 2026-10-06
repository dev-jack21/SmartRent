alter table public.properties
  add column if not exists lease_start_date date,
  add column if not exists lease_end_date date;
