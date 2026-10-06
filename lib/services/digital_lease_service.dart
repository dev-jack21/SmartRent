import 'package:supabase_flutter/supabase_flutter.dart';

class DigitalLeaseAgreement {
  final String id;
  final String propertyId;
  final String propertyName;
  final String tenantName;
  final String tenantEmail;
  final double monthlyRent;
  final double securityDeposit;
  final DateTime leaseStart;
  final DateTime leaseEnd;
  final String termsAndConditions;
  final bool isSignedByLandlord;
  final bool isSignedByTenant;
  final DateTime? landlordSignedAt;
  final DateTime? tenantSignedAt;
  final String? tenantSignatureName;

  const DigitalLeaseAgreement({
    required this.id,
    required this.propertyId,
    required this.propertyName,
    required this.tenantName,
    required this.tenantEmail,
    required this.monthlyRent,
    required this.securityDeposit,
    required this.leaseStart,
    required this.leaseEnd,
    required this.termsAndConditions,
    this.isSignedByLandlord = true,
    this.isSignedByTenant = false,
    this.landlordSignedAt,
    this.tenantSignedAt,
    this.tenantSignatureName,
  });

  bool get isFullySigned => isSignedByLandlord && isSignedByTenant;

  factory DigitalLeaseAgreement.fromMap(Map<String, dynamic> map) {
    return DigitalLeaseAgreement(
      id: map['id']?.toString() ?? '',
      propertyId: map['property_id']?.toString() ?? '',
      propertyName: map['property_name']?.toString() ?? 'Property',
      tenantName: map['tenant_name']?.toString() ?? '',
      tenantEmail: map['tenant_email']?.toString() ?? '',
      monthlyRent: double.tryParse(map['monthly_rent']?.toString() ?? '') ?? 0.0,
      securityDeposit: double.tryParse(map['security_deposit']?.toString() ?? '') ?? 0.0,
      leaseStart: DateTime.tryParse(map['lease_start']?.toString() ?? '') ?? DateTime.now(),
      leaseEnd: DateTime.tryParse(map['lease_end']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 365)),
      termsAndConditions: map['terms_and_conditions']?.toString() ?? '',
      isSignedByLandlord: map['is_signed_landlord'] == true,
      isSignedByTenant: map['is_signed_tenant'] == true,
      landlordSignedAt: DateTime.tryParse(map['landlord_signed_at']?.toString() ?? ''),
      tenantSignedAt: DateTime.tryParse(map['tenant_signed_at']?.toString() ?? ''),
      tenantSignatureName: map['tenant_signature_name']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'property_id': propertyId,
      'property_name': propertyName,
      'tenant_name': tenantName,
      'tenant_email': tenantEmail,
      'monthly_rent': monthlyRent,
      'security_deposit': securityDeposit,
      'lease_start': leaseStart.toIso8601String(),
      'lease_end': leaseEnd.toIso8601String(),
      'terms_and_conditions': termsAndConditions,
      'is_signed_landlord': isSignedByLandlord,
      'is_signed_tenant': isSignedByTenant,
      'landlord_signed_at': landlordSignedAt?.toIso8601String(),
      'tenant_signed_at': tenantSignedAt?.toIso8601String(),
      'tenant_signature_name': tenantSignatureName,
    };
  }
}

class DigitalLeaseService {
  final SupabaseClient _supabase;

  DigitalLeaseService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static final DigitalLeaseService instance = DigitalLeaseService();

  static String defaultStandardTerms({
    required String propertyName,
    required double rent,
    required double deposit,
    required String currency,
  }) {
    return '''
RENTAL LEASE AGREEMENT TERMS & CONDITIONS

1. RENT & PAYMENT TERMS
The tenant agrees to pay a monthly rent of $currency ${rent.toStringAsFixed(2)} due on or before the designated due day of each calendar month. Late payments may be subject to a late charge as specified in property rules.

2. SECURITY DEPOSIT
A security deposit of $currency ${deposit.toStringAsFixed(2)} is collected prior to occupancy and held as security against damages or unpaid dues. Deductions will be itemized upon move-out.

3. USE OF PREMISES
The property ($propertyName) shall be used exclusively as a residential living space. Subletting or unauthorized alterations without prior written consent from the landlord are strictly prohibited.

4. MAINTENANCE & REPAIRS
The tenant agrees to maintain the premises in clean condition and promptly report any required repairs or plumbing/electrical maintenance via the app.

5. TERMINATION & RENEWAL
Either party may provide 30 days notice prior to the expiration date regarding lease renewal or termination.
''';
  }

  Future<DigitalLeaseAgreement?> getLeaseForProperty(String propertyId) async {
    try {
      final response = await _supabase
          .from('digital_leases')
          .select()
          .eq('property_id', propertyId)
          .maybeSingle();

      if (response == null) return null;
      return DigitalLeaseAgreement.fromMap(response);
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveLease(DigitalLeaseAgreement lease) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final payload = lease.toMap();
      payload['user_id'] = user.id;

      await _supabase.from('digital_leases').upsert(payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> signLeaseByTenant({
    required String propertyId,
    required String signatureName,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      await _supabase.from('digital_leases').update({
        'is_signed_tenant': true,
        'tenant_signed_at': now.toIso8601String(),
        'tenant_signature_name': signatureName,
      }).eq('property_id', propertyId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
