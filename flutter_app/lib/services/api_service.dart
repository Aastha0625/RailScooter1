import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle.dart';
import '../models/department.dart';
import '../models/user.dart';
import '../models/alert_rule.dart';
import '../models/vehicle_alert.dart';
import '../models/geofence.dart';
import '../models/vehicle_location.dart';


class ApiService {
  static final SupabaseClient _db = Supabase.instance.client;

  // -------- VEHICLES --------

  static Future<List<Vehicle>> fetchVehicles({String? status, String? search}) async {
    var query = _db.from('vehicles').select('''
      *,
      vehicle_assignments(
        id, is_active, assigned_at,
        departments(id, name, code),
        app_users!vehicle_assignments_assigned_user_id_fkey(id, full_name, employee_id)
      )
    ''');

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    final response = await query.order('created_at', ascending: false);
    final List<dynamic> data = response as List<dynamic>;
    return data.map((j) => Vehicle.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> fetchVehicleDetail(String id) async {
    final response = await _db.from('vehicles').select('''
      *,
      vehicle_assignments(
        id, is_active, assigned_at, notes,
        departments(id, name, code, location),
        app_users!vehicle_assignments_assigned_user_id_fkey(id, full_name, employee_id, role, phone)
      )
    ''').eq('id', id).maybeSingle();
    return response ?? {};
  }

  static Future<Vehicle> createVehicle(Map<String, dynamic> data) async {
    final response = await _db.from('vehicles').insert(data).select().single();
    return Vehicle.fromJson(response);
  }

  static Future<Vehicle> updateVehicle(String id, Map<String, dynamic> data) async {
    final response = await _db
        .from('vehicles')
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return Vehicle.fromJson(response);
  }

  static Future<void> deleteVehicle(String id) async {
    await _db.from('vehicles').delete().eq('id', id);
  }

  // -------- DEPARTMENTS --------

  static Future<List<Department>> fetchDepartments() async {
    final response = await _db.from('departments').select().order('name');
    return (response as List).map((j) => Department.fromJson(j)).toList();
  }

  static Future<Department> createDepartment(Map<String, dynamic> data) async {
    final response = await _db.from('departments').insert(data).select().single();
    return Department.fromJson(response);
  }

  static Future<Department> updateDepartment(String id, Map<String, dynamic> data) async {
    final response = await _db
        .from('departments')
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return Department.fromJson(response);
  }

  static Future<void> deleteDepartment(String id) async {
    await _db.from('departments').delete().eq('id', id);
  }

  // -------- USERS --------

  static Future<List<AppUser>> fetchUsers() async {
    final response = await _db
        .from('app_users')
        .select('*, departments(id, name, code)')
        .order('full_name');
    return (response as List).map((j) => AppUser.fromJson(j)).toList();
  }

  // -------- ASSIGNMENTS --------

  static Future<List<Map<String, dynamic>>> fetchAssignments() async {
    final response = await _db.from('vehicle_assignments').select('''
      *,
      vehicles(id, vehicle_id, variant, status),
      departments(id, name, code),
      app_users!vehicle_assignments_assigned_user_id_fkey(id, full_name, employee_id)
    ''').eq('is_active', true).order('assigned_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }

  static Future<void> createAssignment({
    required String vehicleId,
    String? departmentId,
    String? assignedUserId,
    String? notes,
  }) async {
    // Deactivate previous assignments
    await _db
        .from('vehicle_assignments')
        .update({'is_active': false, 'unassigned_at': DateTime.now().toIso8601String()})
        .eq('vehicle_id', vehicleId)
        .eq('is_active', true);

    await _db.from('vehicle_assignments').insert({
      'vehicle_id': vehicleId,
      'department_id': departmentId,
      'assigned_user_id': assignedUserId,
      'notes': notes ?? '',
      'is_active': true,
    });
  }

  static Future<void> removeAssignment(String assignmentId) async {
    await _db.from('vehicle_assignments').update({
      'is_active': false,
      'unassigned_at': DateTime.now().toIso8601String(),
    }).eq('id', assignmentId);
  }

  // -------- ALERT RULES --------

  static Future<List<AlertRule>> fetchAlertRules() async {
    final response = await _db.from('alert_rules').select().order('created_at', ascending: false);
    return (response as List).map((j) => AlertRule.fromJson(j)).toList();
  }

  static Future<AlertRule> createAlertRule(Map<String, dynamic> data) async {
    final response = await _db.from('alert_rules').insert(data).select().single();
    return AlertRule.fromJson(response);
  }

  static Future<AlertRule> updateAlertRule(String id, Map<String, dynamic> data) async {
    final response = await _db
        .from('alert_rules')
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return AlertRule.fromJson(response);
  }

  static Future<void> deleteAlertRule(String id) async {
    await _db.from('alert_rules').delete().eq('id', id);
  }

  static Future<List<VehicleAlert>> fetchAlertEvents({bool? unacknowledged}) async {
    var query = _db.from('vehicle_alerts').select('''
      *,
      vehicles(id, vehicle_id, variant),
      alert_rules(id, name, rule_type)
    ''');

    if (unacknowledged == true) {
      query = query.eq('is_acknowledged', false);
    }

    final response = await query.order('created_at', ascending: false).limit(100);
    return (response as List).map((j) => VehicleAlert.fromJson(j)).toList();
  }

  static Future<void> acknowledgeAlert(String alertId) async {
    await _db.from('vehicle_alerts').update({
      'is_acknowledged': true,
      'acknowledged_at': DateTime.now().toIso8601String(),
    }).eq('id', alertId);
  }

  // -------- GEOFENCES --------

  static Future<List<Geofence>> fetchGeofences() async {
    final response = await _db
        .from('geofences')
        .select('*, departments(id, name, code)')
        .order('created_at', ascending: false);
    return (response as List).map((j) => Geofence.fromJson(j)).toList();
  }

  static Future<Geofence> createGeofence(Map<String, dynamic> data) async {
    final response = await _db.from('geofences').insert(data).select().single();
    return Geofence.fromJson(response);
  }

  static Future<void> deleteGeofence(String id) async {
    await _db.from('geofences').delete().eq('id', id);
  }

  // -------- TRACKING --------

  static Future<List<VehicleLocation>> fetchLiveTracking() async {
    final response = await _db
        .from('vehicle_tracking')
        .select('*, vehicles(id, vehicle_id, variant, status)')
        .order('recorded_at', ascending: false)
        .limit(200);

    final List<VehicleLocation> result = [];
    final Set<String> seen = {};
    for (final row in response as List) {
      final vid = row['vehicle_id'] as String;
      if (!seen.contains(vid)) {
        seen.add(vid);
        result.add(VehicleLocation.fromJson(row));
      }
    }
    return result;
  }

  // -------- DASHBOARD STATS --------

  static Future<Map<String, int>> fetchDashboardStats() async {
    final results = await Future.wait([
      _db.from('vehicles').select('status'),
      _db.from('departments').select('id').eq('is_active', true),
      _db.from('app_users').select('id').eq('is_active', true),
      _db.from('vehicle_alerts').select('id').eq('is_acknowledged', false),
    ]);

    final vehicles = results[0] as List;
    final statusCounts = <String, int>{};
    for (final v in vehicles) {
      final s = v['status'] as String;
      statusCounts[s] = (statusCounts[s] ?? 0) + 1;
    }

    return {
      'total_vehicles': vehicles.length,
      'active_vehicles': statusCounts['active'] ?? 0,
      'idle_vehicles': statusCounts['idle'] ?? 0,
      'maintenance_vehicles': statusCounts['maintenance'] ?? 0,
      'offline_vehicles': statusCounts['offline'] ?? 0,
      'total_departments': (results[1] as List).length,
      'total_users': (results[2] as List).length,
      'unacknowledged_alerts': (results[3] as List).length,
    };
  }
}
