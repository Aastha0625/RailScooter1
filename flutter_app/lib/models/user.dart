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
  final String approvalStatus; // 'pending' | 'approved' | 'rejected'
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.fullName,
    this.employeeId,
    required this.role,
    this.departmentId,
    this.departmentName,
    required this.phone,
    required this.isActive,
    this.approvalStatus = 'approved',
    this.createdAt,
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
    approvalStatus: json['approval_status'] ?? 'approved',
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'])
        : null,
  );

  Map<String, dynamic> toJson() => {
    'full_name': fullName,
    'employee_id': employeeId,
    'role': role,
    'department_id': departmentId,
    'phone': phone,
    'is_active': isActive,
    'approval_status': approvalStatus,
  };

  AppUser copyWith({
    String? fullName,
    String? employeeId,
    String? role,
    String? departmentId,
    String? phone,
    bool? isActive,
    String? approvalStatus,
  }) => AppUser(
    id: id,
    fullName: fullName ?? this.fullName,
    employeeId: employeeId ?? this.employeeId,
    role: role ?? this.role,
    departmentId: departmentId ?? this.departmentId,
    departmentName: departmentName,
    phone: phone ?? this.phone,
    isActive: isActive ?? this.isActive,
    approvalStatus: approvalStatus ?? this.approvalStatus,
    createdAt: createdAt,
  );
}
