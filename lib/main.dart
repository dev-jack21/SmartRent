import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/tenant/tenant_portal_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/caretaker/caretaker_dashboard_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'services/app_navigation.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mpuvmqyuhwcbxnfssxcm.supabase.co',
    publishableKey: 'sb_publishable_Edwm0J08Q9vMtCezProfmw_-_VOxkEu',
  );

  await NotificationService.instance.initialize();

  runApp(const RentReminderApp());
}

class RentReminderApp extends StatelessWidget {
  const RentReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Rent Reminder',
          themeMode: currentThemeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.hasData
            ? snapshot.data!.session
            : Supabase.instance.client.auth.currentSession;

        if (session != null) {
          return _AuthenticatedHome(
            key: ValueKey(session.user.id),
            userId: session.user.id,
          );
        }

        return const LoginScreen();
      },
    );
  }
}

class _AuthenticatedHome extends StatefulWidget {
  final String userId;

  const _AuthenticatedHome({super.key, required this.userId});

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  late Future<bool> _isTenantFuture;

  @override
  void initState() {
    super.initState();
    _isTenantFuture = _checkIfTenant();
  }

  Future<bool> _checkIfTenant() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    final accountType = user.userMetadata?['account_type']?.toString() ??
        user.userMetadata?['account_role']?.toString();

    if (accountType == 'tenant') return true;
    if (accountType == 'owner' || accountType == 'landlord') return false;

    final email = user.email;
    if (email != null && email.isNotEmpty) {
      try {
        final match = await Supabase.instance.client
            .from('properties')
            .select('id')
            .ilike('tenant_email', email.trim())
            .limit(1)
            .maybeSingle();
        if (match != null) return true;
      } catch (_) {}
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final accountType = user?.userMetadata?['account_type']?.toString() ??
        user?.userMetadata?['account_role']?.toString();

    if (accountType == 'caretaker') {
      return const CaretakerDashboardScreen();
    }

    return FutureBuilder<bool>(
      future: _isTenantFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isTenant = snapshot.data == true;

        if (isTenant) {
          return const TenantPortalScreen();
        }

        return const DashboardScreen();
      },
    );
  }
}
