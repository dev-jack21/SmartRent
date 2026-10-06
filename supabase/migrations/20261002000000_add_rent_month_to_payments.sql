alter table public.payments
  add column if not exists rent_month date;

update public.payments
set rent_month = date_trunc('month', payment_date::timestamp)::date
where rent_month is null
  and payment_date is not null;

alter table public.payments
  alter column rent_month
  set default (date_trunc('month', current_date)::date);

create index if not exists payments_user_rent_month_idx
  on public.payments (user_id, rent_month);