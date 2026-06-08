/// AppUser represents a user in the app_users table,
/// linked to Supabase Auth via their auth UID.
class AppUser {
  final String id;
  final String fullName;
  final String? employeeId;
  final String role;
  final String? departmentId;
  final String? departmentName;
  final String phone;
  final bool isActive;

  const AppUser({
    required this.id,
    required this.fullName,
    this.employeeId,
    required this.role,
    this.departmentId,
    this.departmentName,
    required this.phone,
    required this.isActive,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] ?? '',
    fullName: json['full_name'] ?? '',
    employeeId: json['employee_id'],
    role: json['role'] ?? 'trackman',
    departmentId: json['department_id'],
    departmentName: json['departments']?['name'],
    phone: json['phone'] ?? '',
    isActive: json['is_active'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'full_name': fullName,
    'employee_id': employeeId,
    'role': role,
    'department_id': departmentId,
    'phone': phone,
    'is_active': isActive,
  };
}
