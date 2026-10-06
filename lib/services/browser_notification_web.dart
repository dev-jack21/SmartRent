import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';

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
    return await html.Notification.requestPermission() == 'granted';
  } catch (_) {
    return false;
  }
}

bool get isPermissionGranted => html.Notification.permission == 'granted';

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
  html.Notification(title, body: body);
}
