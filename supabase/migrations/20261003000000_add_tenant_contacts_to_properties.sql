alter table public.properties
  add column if not exists tenant_name text,
  add column if not exists tenant_email text,
  add column if not exists tenant_phone text;
