import webpush from 'npm:web-push@3.6.7';
import { createClient } from 'npm:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const vapidPublicKey = Deno.env.get('VAPID_PUBLIC_KEY')!;
const vapidPrivateKey = Deno.env.get('VAPID_PRIVATE_KEY')!;
const vapidSubject = Deno.env.get('VAPID_SUBJECT')!;
const resendApiKey = Deno.env.get('RESEND_API_KEY');
const reminderFromEmail = Deno.env.get('RENT_REMINDER_FROM_EMAIL');

const supabase = createClient(supabaseUrl, serviceRoleKey);
webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);

async function sendTenantRentEmail({
  userId,
  propertyId,
  propertyName,
  tenantName,
  tenantEmail,
  currency,
  amountDue,
  dueDate,
  dueMonth,
  daysBefore,
  dueLabel,
}: {
  userId: string;
  propertyId: string;
  propertyName: string;
  tenantName: string | null;
  tenantEmail: string;
  currency: string;
  amountDue: number;
  dueDate: string;
  dueMonth: string;
  daysBefore: number;
  dueLabel: string;
}): Promise<{ sent: boolean; error?: string }> {
  if (!resendApiKey || !reminderFromEmail) {
    if (!resendApiKey && !reminderFromEmail) return { sent: false };
    return {
      sent: false,
      error: 'Set RESEND_API_KEY and RENT_REMINDER_FROM_EMAIL secrets.',
    };
  }

  const { data: existingDelivery, error: lookupError } = await supabase
    .from('tenant_email_reminder_deliveries')
    .select('id')
    .eq('property_id', propertyId)
    .eq('due_month', dueMonth)
    .eq('days_before', daysBefore)
    .maybeSingle();
  if (lookupError) {
    return {
      sent: false,
      error: `Could not check tenant email delivery: ${lookupError.message}`,
    };
  }
  if (existingDelivery) return { sent: false };

  const greeting = tenantName?.trim() ? `Hello ${tenantName.trim()},` : 'Hello,';
  const subject = `Rent reminder: ${propertyName} is ${dueLabel}`;
  const text = [
    greeting,
    '',
    `This is a reminder that rent for ${propertyName} is ${dueLabel} (${dueDate}).`,
    `Outstanding rent: ${currency} ${amountDue.toFixed(2)}.`,
    '',
    'If you have already paid, please disregard this reminder or contact your property manager.',
  ].join('\n');
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: ['Bearer', resendApiKey].join(' '),
      'Content-Type': 'application/json',
      'Idempotency-Key': `rent-reminder-${propertyId}-${dueMonth}-${daysBefore}`,
    },
    body: JSON.stringify({
      from: reminderFromEmail,
      to: [tenantEmail],
      subject,
      text,
    }),
  });

  if (!response.ok) {
    return {
      sent: false,
      error: `Tenant email provider returned ${response.status}: ${await response.text()}`,
    };
  }

  const { error: deliveryError } = await supabase
    .from('tenant_email_reminder_deliveries')
    .insert({
      user_id: userId,
      property_id: propertyId,
      due_month: dueMonth,
      days_before: daysBefore,
    });
  if (deliveryError && deliveryError.code !== '23505') {
    return {
      sent: false,
      error: `Tenant email was sent but its delivery record could not be saved: ${deliveryError.message}`,
    };
  }

  return { sent: true };
}

function nairobiToday(): { year: number; month: number; day: number } {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Nairobi',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date());
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
  };
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }
  const cronSecret = request.headers.get('x-cron-secret');
  const { data: authorized, error: authorizationError } = await supabase.rpc(
    'verify_rent_reminder_cron_secret',
    { candidate_secret: cronSecret },
  );
  if (authorizationError || authorized !== true) {
    return new Response('Unauthorized', { status: 401 });
  }

  const today = nairobiToday();
  const todayOrdinal = Date.UTC(today.year, today.month - 1, today.day);
  const { data: reminders, error: reminderError } = await supabase
    .from('reminders')
    .select('user_id, property_id, days_before, properties!inner(name, tenant_name, tenant_email, monthly_rent, currency, due_day)')
    .eq('enabled', true);

  if (reminderError) {
    return Response.json({ error: reminderError.message }, { status: 500 });
  }

  const sentKeys = new Set<string>();
  let sentCount = 0;
  let tenantEmailsSent = 0;
  const processingErrors: string[] = [];
  const tenantEmailsEnabled = Boolean(resendApiKey && reminderFromEmail);

  for (const reminder of reminders ?? []) {
    const property = reminder.properties as {
      name: string;
      tenant_name: string | null;
      tenant_email: string | null;
      monthly_rent: number | string;
      currency: string | null;
      due_day: number | string;
    };
    const daysBefore = Number(reminder.days_before);
    const dueDay = Number(property.due_day);
    if (!Number.isInteger(daysBefore) || daysBefore < 0 || !Number.isFinite(dueDay)) {
      continue;
    }

    let matchingDueMonth: string | null = null;
    let matchingDueDate: string | null = null;
    for (let offset = 0; offset <= 1; offset++) {
      const rawMonth = today.month + offset;
      const year = today.year + Math.floor((rawMonth - 1) / 12);
      const month = ((rawMonth - 1) % 12) + 1;
      const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
      const actualDueDay = Math.min(dueDay, daysInMonth);
      const dueDate = Date.UTC(year, month - 1, actualDueDay);
      const difference = Math.round((dueDate - todayOrdinal) / 86_400_000);
      if (difference === daysBefore) {
        matchingDueMonth = `${year}-${String(month).padStart(2, '0')}-01`;
        matchingDueDate = `${year}-${String(month).padStart(2, '0')}-${String(actualDueDay).padStart(2, '0')}`;
        break;
      }
    }
    if (!matchingDueMonth || !matchingDueDate) continue;

    const { data: paidPayments, error: paymentError } = await supabase
      .from('payments')
      .select('amount')
      .eq('property_id', reminder.property_id)
      .eq('rent_month', matchingDueMonth)
      .eq('status', 'paid');
    const { data: creditAllocations, error: allocationError } = await supabase
      .from('rent_credit_allocations')
      .select('amount')
      .eq('property_id', reminder.property_id)
      .eq('target_month', matchingDueMonth);
    if (paymentError || allocationError) {
      processingErrors.push(
        `Could not calculate unpaid rent for property ${reminder.property_id}: ${paymentError?.message ?? allocationError?.message}`,
      );
      continue;
    }

    const paidTotal = (paidPayments ?? []).reduce(
      (total, payment) => total + Number(payment.amount),
      0,
    );
    const creditTotal = (creditAllocations ?? []).reduce(
      (total, allocation) => total + Number(allocation.amount),
      0,
    );
    if (paidTotal + creditTotal >= Number(property.monthly_rent)) continue;
    const amountDue = Number(property.monthly_rent) - paidTotal - creditTotal;

    const deliveryKey = `${reminder.property_id}:${matchingDueMonth}:${daysBefore}`;
    if (sentKeys.has(deliveryKey)) continue;
    sentKeys.add(deliveryKey);

    const dueLabel = daysBefore === 0
      ? 'due today'
      : daysBefore === 1
      ? 'due tomorrow'
      : `due in ${daysBefore} days`;
    const tenantEmail = property.tenant_email?.trim();
    if (tenantEmail) {
      try {
        const emailResult = await sendTenantRentEmail({
          userId: reminder.user_id,
          propertyId: reminder.property_id,
          propertyName: property.name,
          tenantName: property.tenant_name,
          tenantEmail,
          currency: property.currency ?? 'KES',
          amountDue,
          dueDate: matchingDueDate,
          dueMonth: matchingDueMonth,
          daysBefore,
          dueLabel,
        });
        if (emailResult.error) {
          processingErrors.push(
            `Could not send tenant reminder for property ${reminder.property_id}: ${emailResult.error}`,
          );
        } else if (emailResult.sent) {
          tenantEmailsSent++;
        }
      } catch (error) {
        processingErrors.push(
          `Could not send tenant reminder for property ${reminder.property_id}: ${error}`,
        );
      }
    }

    const { data: existingDelivery, error: deliveryLookupError } =
      await supabase
        .from('push_reminder_deliveries')
        .select('id')
        .eq('property_id', reminder.property_id)
        .eq('due_month', matchingDueMonth)
        .eq('days_before', daysBefore)
        .maybeSingle();
    if (deliveryLookupError) {
      processingErrors.push(
        `Could not check push reminder delivery for property ${reminder.property_id}: ${deliveryLookupError.message}`,
      );
      continue;
    }
    if (existingDelivery) continue;

    const { data: subscriptions, error: subscriptionError } = await supabase
      .from('push_subscriptions')
      .select('endpoint, p256dh, auth')
      .eq('user_id', reminder.user_id);
    if (subscriptionError) {
      processingErrors.push(
        `Could not load push subscriptions for user ${reminder.user_id}: ${subscriptionError.message}`,
      );
      continue;
    }
    if (!subscriptions?.length) continue;

    const payload = JSON.stringify({
      title: `Rent ${dueLabel}`,
      body: `${property.name} has ${property.currency ?? 'KES'} ${amountDue.toFixed(2)} rent remaining ${dueLabel}.`,
      url: '/',
    });

    let delivered = false;
    for (const subscription of subscriptions) {
      try {
        await webpush.sendNotification({
          endpoint: subscription.endpoint,
          keys: { p256dh: subscription.p256dh, auth: subscription.auth },
        }, payload, { TTL: 3600 });
        delivered = true;
      } catch (error) {
        const statusCode = (error as { statusCode?: number }).statusCode;
        if (statusCode === 404 || statusCode === 410) {
          const { error: deleteError } = await supabase
            .from('push_subscriptions')
            .delete()
            .eq('endpoint', subscription.endpoint);
          if (deleteError) {
            processingErrors.push(
              `Could not remove expired push subscription: ${deleteError.message}`,
            );
          }
        } else {
          processingErrors.push(
            `Push delivery failed for property ${reminder.property_id}: ${error}`,
          );
        }
      }
    }

    if (delivered) {
      const { error: deliveryError } = await supabase
        .from('push_reminder_deliveries')
        .insert({
          user_id: reminder.user_id,
          property_id: reminder.property_id,
          due_month: matchingDueMonth,
          days_before: daysBefore,
        });
      if (deliveryError && deliveryError.code !== '23505') {
        processingErrors.push(
          `Push was sent but its delivery record could not be saved: ${deliveryError.message}`,
        );
      } else {
        sentCount++;
      }
    }
  }

  return Response.json(
    {
      sent: sentCount,
      tenantEmailsSent,
      tenantEmailsEnabled,
      errors: processingErrors,
    },
    { status: processingErrors.length > 0 ? 500 : 200 },
  );
});