Future<bool> requestPermission() async => false;

bool get isPermissionGranted => false;

Future<void> show(String title, String body) async {}

bool get hasPushSubscription => false;

Future<Map<String, dynamic>> subscribeToPush(String applicationServerKey) {
  throw UnsupportedError(
    'Browser push notifications are only available on web.',
  );
}

void markPushSubscriptionSaved() {}
