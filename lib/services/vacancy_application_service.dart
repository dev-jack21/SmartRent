import 'package:supabase_flutter/supabase_flutter.dart';

class TenantApplication {
  final String id;
  final String propertyId;
  final String propertyName;
  final String applicantName;
  final String applicantEmail;
  final String applicantPhone;
  final double annualIncome;
  final String employerName;
  final String moveInDate;
  final String notes;
  String status; // 'Submitted', 'Under Review', 'Approved', 'Rejected'
  final DateTime submittedAt;

  TenantApplication({
    required this.id,
    required this.propertyId,
    required this.propertyName,
    required this.applicantName,
    required this.applicantEmail,
    required this.applicantPhone,
    required this.annualIncome,
    required this.employerName,
    required this.moveInDate,
    required this.notes,
    this.status = 'Submitted',
    required this.submittedAt,
  });

  factory TenantApplication.fromMap(Map<String, dynamic> map) {
    return TenantApplication(
      id: map['id']?.toString() ?? '',
      propertyId: map['property_id']?.toString() ?? '',
      propertyName: map['property_name']?.toString() ?? 'Property',
      applicantName: map['applicant_name']?.toString() ?? '',
      applicantEmail: map['applicant_email']?.toString() ?? '',
      applicantPhone: map['applicant_phone']?.toString() ?? '',
      annualIncome: double.tryParse(map['annual_income']?.toString() ?? '') ?? 0.0,
      employerName: map['employer_name']?.toString() ?? '',
      moveInDate: map['move_in_date']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      status: map['status']?.toString() ?? 'Submitted',
      submittedAt: DateTime.tryParse(map['submitted_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'property_id': propertyId,
      'property_name': propertyName,
      'applicant_name': applicantName,
      'applicant_email': applicantEmail,
      'applicant_phone': applicantPhone,
      'annual_income': annualIncome,
      'employer_name': employerName,
      'move_in_date': moveInDate,
      'notes': notes,
      'status': status,
      'submitted_at': submittedAt.toIso8601String(),
    };
  }
}

class VacancyApplicationService {
  final SupabaseClient _supabase;

  VacancyApplicationService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static final VacancyApplicationService instance = VacancyApplicationService();

  Future<List<TenantApplication>> loadApplications(String propertyId) async {
    try {
      final response = await _supabase
          .from('tenant_applications')
          .select()
          .eq('property_id', propertyId)
          .order('submitted_at', ascending: false);

      return (response as List<dynamic>)
          .map((row) => TenantApplication.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> submitApplication(TenantApplication application) async {
    try {
      final payload = application.toMap();
      await _supabase.from('tenant_applications').insert(payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateStatus(String applicationId, String newStatus) async {
    try {
      await _supabase
          .from('tenant_applications')
          .update({'status': newStatus})
          .eq('id', applicationId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Approve tenant application and assign tenant details to the property record
  Future<bool> approveTenantAndAssignProperty(TenantApplication application) async {
    try {
      // 1. Update application status
      await updateStatus(application.id, 'Approved');

      // 2. Assign tenant details to the property
      await _supabase
          .from('properties')
          .update({
            'tenant_name': application.applicantName,
            'tenant_email': application.applicantEmail,
            'tenant_phone': application.applicantPhone,
          })
          .eq('id', application.propertyId);

      return true;
    } catch (_) {
      return false;
    }
  }
}
