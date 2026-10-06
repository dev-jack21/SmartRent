(function () {
  function decodeApplicationServerKey(encodedKey) {
    const padded = encodedKey + '='.repeat((4 - (encodedKey.length % 4)) % 4);
    const base64 = padded.replace(/-/g, '+').replace(/_/g, '/');
    const raw = atob(base64);
    return Uint8Array.from(raw, (character) => character.charCodeAt(0));
  }

  window.rentReminderHasPushSubscription = function () {
    return window.localStorage.getItem('rent_reminder_push_enabled') === 'true';
  };

  window.rentReminderSubscribeToPush = async function (applicationServerKey) {
    if (!applicationServerKey) {
      throw new Error(
        'Set WEB_PUSH_VAPID_PUBLIC_KEY when launching the web app.',
      );
    }

    const workerUrl = new URL('push/push-service-worker.js', document.baseURI);
    const workerScope = new URL('push/', document.baseURI);
    const registration = await navigator.serviceWorker.register(workerUrl, {
      scope: workerScope.pathname,
    });
    let subscription = await registration.pushManager.getSubscription();

    if (!subscription) {
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: decodeApplicationServerKey(applicationServerKey),
      });
    }

    return JSON.stringify(subscription.toJSON());
  };

  window.rentReminderMarkPushSubscriptionSaved = function () {
    window.localStorage.setItem('rent_reminder_push_enabled', 'true');
  };
})();