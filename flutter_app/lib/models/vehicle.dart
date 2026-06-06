class Vehicle {
  final String id;
  final String vehicleId;
  final String variant;
  final String batteryType;
  final String batteryCapacity;
  final DateTime? manufacturingDate;
  final String firmwareVersion;
  final DateTime? lastMaintenanceDate;
  final String status;
  final bool gpsEnabled;
  final bool trackmanEnabled;
  final bool trackmanSafetyEnabled;
  final String notes;
  final DateTime createdAt;
  final String? departmentName;
  final String? assignedUserName;

  const Vehicle({
    required this.id,
    required this.vehicleId,
    required this.variant,
    required this.batteryType,
    required this.batteryCapacity,
    this.manufacturingDate,
    required this.firmwareVersion,
    this.lastMaintenanceDate,
    required this.status,
    required this.gpsEnabled,
    required this.trackmanEnabled,
    required this.trackmanSafetyEnabled,
    required this.notes,
    required this.createdAt,
    this.departmentName,
    this.assignedUserName,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    String? deptName;
    String? userName;

    if (json['vehicle_assignments'] != null) {
      final assignments = json['vehicle_assignments'] as List;
      final active = assignments.where((a) => a['is_active'] == true).toList();
      if (active.isNotEmpty) {
        deptName = active.first['departments']?['name'];
        // When using an explicit FK hint in the query, Supabase returns the
        // nested user object under the FK alias key. Fall back to 'app_users'
        // for any queries that don't use the hint.
        final userObj = active.first['app_users!vehicle_assignments_assigned_user_id_fkey']
            ?? active.first['app_users'];
        userName = userObj?['full_name'];
      }
    }

    return Vehicle(
      id: json['id'] ?? '',
      vehicleId: json['vehicle_id'] ?? '',
      variant: json['variant'] ?? 'PiScoot',
      batteryType: json['battery_type'] ?? 'LiFe',
      batteryCapacity: json['battery_capacity'] ?? '',
      manufacturingDate: json['manufacturing_date'] != null
          ? DateTime.tryParse(json['manufacturing_date'])
          : null,
      firmwareVersion: json['firmware_version'] ?? 'v1.0.0',
      lastMaintenanceDate: json['last_maintenance_date'] != null
          ? DateTime.tryParse(json['last_maintenance_date'])
          : null,
      status: json['status'] ?? 'active',
      gpsEnabled: json['gps_enabled'] ?? true,
      trackmanEnabled: json['trackman_enabled'] ?? false,
      trackmanSafetyEnabled: json['trackman_safety_enabled'] ?? false,
      notes: json['notes'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      departmentName: deptName,
      assignedUserName: userName,
    );
  }

  Map<String, dynamic> toJson() => {
    'vehicle_id': vehicleId,
    'variant': variant,
    'battery_type': batteryType,
    'battery_capacity': batteryCapacity,
    'manufacturing_date': manufacturingDate?.toIso8601String().split('T').first,
    'firmware_version': firmwareVersion,
    'last_maintenance_date': lastMaintenanceDate?.toIso8601String().split('T').first,
    'status': status,
    'gps_enabled': gpsEnabled,
    'trackman_enabled': trackmanEnabled,
    'trackman_safety_enabled': trackmanSafetyEnabled,
    'notes': notes,
  };
}
