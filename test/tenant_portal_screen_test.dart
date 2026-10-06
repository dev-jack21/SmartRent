import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rent_reminder/screens/tenant/tenant_portal_screen.dart';
import 'package:rent_reminder/services/tenant_portal_repository.dart';

class _FakeTenantPortalRepository implements TenantPortalRepository {
  String? loadedEmail;
  List<String>? loadedPropertyIds;

  @override
  Future<List<Map<String, dynamic>>> loadProperties({
    required String tenantEmail,
  }) async {
    loadedEmail = tenantEmail;
    return [
      {
        'id': 'property-1',
        'name': 'Cedar House',
        'address': '10 Oak Road',
        'unit_number': 'Unit 2',
        'monthly_rent': 1250,
        'currency': 'USD',
        'due_day': 1,
        'lease_start_date': '2020-01-01',
        'lease_end_date': '2030-12-31',
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> loadPayments({
    required List<String> propertyIds,
  }) async {
    loadedPropertyIds = propertyIds;
    final now = DateTime.now();
    return [
      {
        'id': 'payment-1',
        'property_id': 'property-1',
        'amount': 500,
        'status': 'paid',
        'payment_date':
            '${now.year}-${now.month.toString().padLeft(2, '0')}-01',
        'rent_month': '${now.year}-${now.month.toString().padLeft(2, '0')}-01',
        'notes': 'October rent',
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> loadCreditAllocations({
    required List<String> propertyIds,
  }) async {
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1);
    return [
      {
        'property_id': 'property-1',
        'source_month':
            '${previousMonth.year}-${previousMonth.month.toString().padLeft(2, '0')}-01',
        'target_month':
            '${now.year}-${now.month.toString().padLeft(2, '0')}-01',
        'amount': 250,
      },
    ];
  }
}

void main() {
  testWidgets('shows only read-only rental and payment details', (
    tester,
  ) async {
    final repository = _FakeTenantPortalRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: TenantPortalScreen(
          repository: repository,
          tenantEmail: 'tenant@example.com',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.loadedEmail, 'tenant@example.com');
    expect(repository.loadedPropertyIds, ['property-1']);
    expect(find.text('Cedar House'), findsOneWidget);
    final now = DateTime.now();
    final currentMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    expect(find.text('Rent for $currentMonth'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('USD 500.00'), findsOneWidget);
    expect(find.text('Current rent balance: USD 500.00'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('shows an empty linked-property state', (tester) async {
    final repository = _EmptyTenantPortalRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: TenantPortalScreen(
          repository: repository,
          tenantEmail: 'tenant@example.com',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No rental properties are linked'),
      findsOneWidget,
    );
    expect(repository.paymentsRequested, isFalse);
  });
}

class _EmptyTenantPortalRepository implements TenantPortalRepository {
  bool paymentsRequested = false;

  @override
  Future<List<Map<String, dynamic>>> loadProperties({
    required String tenantEmail,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> loadPayments({
    required List<String> propertyIds,
  }) async {
    paymentsRequested = true;
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> loadCreditAllocations({
    required List<String> propertyIds,
  }) async => [];
}
