import 'package:supabase_flutter/supabase_flutter.dart';

class InspectionItem {
  final String category; // e.g., 'Walls & Paint', 'Plumbing', 'Electrical'
  final String itemName; // e.g., 'Living Room Walls', 'Kitchen Sink'
  String condition; // 'Good', 'Fair', 'Needs Repair', 'Damaged'
  double repairCost;
  String notes;

  InspectionItem({
    required this.category,
    required this.itemName,
    this.condition = 'Good',
    this.repairCost = 0.0,
    this.notes = '',
  });

  factory InspectionItem.fromMap(Map<String, dynamic> map) {
    return InspectionItem(
      category: map['category']?.toString() ?? 'General',
      itemName: map['item_name']?.toString() ?? 'Item',
      condition: map['condition']?.toString() ?? 'Good',
      repairCost: double.tryParse(map['repair_cost']?.toString() ?? '') ?? 0.0,
      notes: map['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'item_name': itemName,
      'condition': condition,
      'repair_cost': repairCost,
      'notes': notes,
    };
  }
}

class PropertyInspection {
  final String id;
  final String propertyId;
  final String inspectionType; // 'Move-In' or 'Move-Out'
  final DateTime inspectionDate;
  final double initialSecurityDeposit;
  final List<InspectionItem> items;
  final String inspectorNotes;

  const PropertyInspection({
    required this.id,
    required this.propertyId,
    required this.inspectionType,
    required this.inspectionDate,
    required this.initialSecurityDeposit,
    required this.items,
    this.inspectorNotes = '',
  });

  double get totalDeductions {
    return items.fold(0.0, (sum, item) => sum + item.repairCost);
  }

  double get netRefundAmount {
    final net = initialSecurityDeposit - totalDeductions;
    return net < 0 ? 0 : net;
  }

  factory PropertyInspection.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    return PropertyInspection(
      id: map['id']?.toString() ?? '',
      propertyId: map['property_id']?.toString() ?? '',
      inspectionType: map['inspection_type']?.toString() ?? 'Move-In',
      inspectionDate: DateTime.tryParse(map['inspection_date']?.toString() ?? '') ?? DateTime.now(),
      initialSecurityDeposit: double.tryParse(map['initial_deposit']?.toString() ?? '') ?? 0.0,
      items: rawItems.map((i) => InspectionItem.fromMap(Map<String, dynamic>.from(i))).toList(),
      inspectorNotes: map['inspector_notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'property_id': propertyId,
      'inspection_type': inspectionType,
      'inspection_date': inspectionDate.toIso8601String(),
      'initial_deposit': initialSecurityDeposit,
      'items': items.map((i) => i.toMap()).toList(),
      'inspector_notes': inspectorNotes,
    };
  }
}

class InspectionService {
  final SupabaseClient _supabase;

  InspectionService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static final InspectionService instance = InspectionService();

  static List<InspectionItem> defaultChecklist() {
    return [
      InspectionItem(category: 'Walls & Ceiling', itemName: 'Living Room Walls & Paint'),
      InspectionItem(category: 'Walls & Ceiling', itemName: 'Bedroom Walls & Paint'),
      InspectionItem(category: 'Plumbing & Bath', itemName: 'Bathroom Sink & Faucet'),
      InspectionItem(category: 'Plumbing & Bath', itemName: 'Toilet & Flush Tank'),
      InspectionItem(category: 'Plumbing & Bath', itemName: 'Shower & Hot Water'),
      InspectionItem(category: 'Kitchen', itemName: 'Kitchen Sink & Countertop'),
      InspectionItem(category: 'Kitchen', itemName: 'Cabinets & Drawers'),
      InspectionItem(category: 'Electrical & Lighting', itemName: 'Light Fixtures & Switches'),
      InspectionItem(category: 'Electrical & Lighting', itemName: 'Power Outlets'),
      InspectionItem(category: 'Doors & Windows', itemName: 'Main Door Locks & Keys'),
      InspectionItem(category: 'Doors & Windows', itemName: 'Window Glasses & Latches'),
      InspectionItem(category: 'Flooring', itemName: 'Tiles / Flooring Condition'),
    ];
  }

  Future<List<PropertyInspection>> loadInspections(String propertyId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('property_inspections')
          .select()
          .eq('property_id', propertyId)
          .order('inspection_date', ascending: false);

      return (response as List<dynamic>)
          .map((row) => PropertyInspection.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveInspection(PropertyInspection inspection) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final payload = inspection.toMap();
      payload['user_id'] = user.id;

      await _supabase.from('property_inspections').insert(payload);
      return true;
    } catch (_) {
      return false;
    }
  }
}
