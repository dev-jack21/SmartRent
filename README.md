# rent_reminder

A new Flutter project.

## Supabase setup

Apply the SQL migrations in `supabase/migrations` to the Supabase project, in
filename order, after the project's existing `properties`, `payments`,
`reminders`, and `profiles` tables are in place. This enables lease dates,
maintenance requests, rent-month accounting, push reminders, tenant contacts
and access, property expenses, recurring expenses, and private property
documents.

The tenant portal requires the tenant to create an account with the same email
address saved in the property's tenant contact details. It is read-only and
uses row-level security to limit tenant visibility to matched properties and
their rent-payment history and current rent balance, including applied rent
credits. Tenants choose **Tenant** at signup and open the portal after they
confirm their email and sign in. Keep Supabase email confirmation enabled so an
unverified account cannot claim a tenant email address; existing tenant
accounts created before the migration must have their profile role set to
`tenant` by an administrator.

The document migration creates a private Storage bucket. Do not change it to a
public bucket: the app uses authenticated, short-lived download links.

## Automatic rent reminders

The app supports device-local reminders and scheduled browser push for the
owner. Tenant email reminders are optional and remain disabled unless both
Resend secrets are configured. To enable scheduled owner push reminders:

1. Apply `20261002002000_create_push_subscriptions.sql` and then
   `20261002003000_schedule_rent_push.sql`.
2. Generate a VAPID key pair and set the public key, private key, and subject as
   Supabase Edge Function secrets. Keep the private key secret:

   ```powershell
   $secretsPath = Join-Path $env:TEMP 'rent-reminder-push-secrets.env'
   supabase secrets set --env-file $secretsPath
   ```

3. Build the web app with the matching public key and deploy the function:

   ```powershell
   $publicLine = Get-Content $secretsPath |
     Where-Object { $_.StartsWith('VAPID_PUBLIC_KEY=') } |
     Select-Object -First 1
   $publicKey = $publicLine.Substring('VAPID_PUBLIC_KEY='.Length)
   flutter build web "--dart-define=WEB_PUSH_VAPID_PUBLIC_KEY=$publicKey"
   supabase functions deploy send-rent-reminders
   Remove-Item -LiteralPath $secretsPath -Force
   ```

4. Open **Reminder settings** for each property and save the reminder days.
   In Chrome, allow notifications and enable **Background browser reminders**
   to receive owner push notifications. The scheduled sender sends owner push
   notifications to subscribed browsers. It runs daily at 06:00 UTC (09:00
   Nairobi time); the cron migration creates its own authorization secret in
   Supabase Vault.

Tenant email reminders are skipped unless both `RESEND_API_KEY` and
`RENT_REMINDER_FROM_EMAIL` are configured. Enabling them additionally requires
a verified domain in Resend and applying
`20261003005000_add_tenant_email_reminder_deliveries.sql`.

## Backup and export

Use **Backup & export** from the owner dashboard menu to download a versioned
JSON backup of the signed-in owner's profile, property and rent-management
data, plus property-document metadata. It does not contain document file
contents or push subscription credentials. The backup is an export for
safekeeping; it does not automatically import or restore data.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
