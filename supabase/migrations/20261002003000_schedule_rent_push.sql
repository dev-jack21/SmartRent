create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

do $$
begin
  if not exists (
    select 1
    from vault.secrets
    where name = 'rent_reminder_cron_secret'
  ) then
    perform vault.create_secret(
      encode(gen_random_bytes(32), 'hex'),
      'rent_reminder_cron_secret',
      'Authentication for the scheduled rent reminder function'
    );
  end if;
end;
$$;

create or replace function public.verify_rent_reminder_cron_secret(
  candidate_secret text
)
returns boolean
language sql
stable
security definer
set search_path = vault, public
as $$
  select exists (
    select 1
    from decrypted_secrets
    where name = 'rent_reminder_cron_secret'
      and decrypted_secret = candidate_secret
  );
$$;

revoke all on function public.verify_rent_reminder_cron_secret(text)
  from public, anon, authenticated;
grant execute on function public.verify_rent_reminder_cron_secret(text)
  to service_role;

select cron.unschedule(jobid)
from cron.job
where jobname = 'rent-reminder-push-daily';

select cron.schedule(
  'rent-reminder-push-daily',
  '0 6 * * *',
  $$
    select net.http_post(
      url := 'https://mpuvmqyuhwcbxnfssxcm.supabase.co/functions/v1/super-responder',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'rent_reminder_cron_secret'
        )
      ),
      body := '{}'::jsonb
    );
  $$
);