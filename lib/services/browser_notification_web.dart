import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('rentReminderHasPushSubscription')
external JSBoolean _rentReminderHasPushSubscription();

@JS('rentReminderSubscribeToPush')
external JSPromise<JSString> _rentReminderSubscribeToPush(
  JSString applicationServerKey,
);

@JS('rentReminderMarkPushSubscriptionSaved')
external void _rentReminderMarkPushSubscriptionSaved();

Future<bool> requestPermission() async {
  try {
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

bool get isPermissionGranted => web.Notification.permission == 'granted';

bool get hasPushSubscription => _rentReminderHasPushSubscription().toDart;

Future<Map<String, dynamic>> subscribeToPush(
  String applicationServerKey,
) async {
  final json = await _rentReminderSubscribeToPush(applicationServerKey.toJS)
      .toDart;
  return jsonDecode(json.toDart) as Map<String, dynamic>;
}

void markPushSubscriptionSaved() {
  _rentReminderMarkPushSubscriptionSaved();
}

Future<void> show(String title, String body) async {
  if (!isPermissionGranted) return;
  web.Notification(title, web.NotificationOptions(body: body));
}
