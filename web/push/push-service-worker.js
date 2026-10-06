self.addEventListener('push', (event) => {
  const payload = event.data ? event.data.json() : {};
  const title = payload.title || 'Rent Reminder';
  const options = {
    body: payload.body || 'You have an upcoming rent reminder.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: { url: payload.url || '/' },
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = new URL(event.notification.data?.url || '/', self.location.origin);

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clients) => {
      for (const client of clients) {
        if (new URL(client.url).origin === targetUrl.origin) {
          return client.focus();
        }
      }
      return self.clients.openWindow(targetUrl.href);
    }),
  );
});