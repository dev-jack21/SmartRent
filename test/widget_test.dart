import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rent_reminder/screens/dashboard/dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        publishableKey: 'test_publishable_key',
      );
    } catch (_) {
      // Already initialized from a previous test run.
    }
  });

  testWidgets('Add Property button opens the property form', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));

    expect(find.text('Add Property'), findsOneWidget);

    await tester.tap(find.text('Add Property'));
    await tester.pumpAndSettle();

    expect(find.text('Add a rental property'), findsOneWidget);
  });
}
