import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../models/department.dart';
import '../../models/vehicle.dart';
import '../../services/api_service.dart';

class UserAssignmentScreen extends StatefulWidget {
  const UserAssignmentScreen({super.key});

  @override
  State<UserAssignmentScreen> createState() => _UserAssignmentScreenState();
}

class _UserAssignmentScreenState extends State<UserAssignmentScreen> {
  List<AppUser> _users = [];
  List<Map<String, dynamic>> _assignments = [];
  List<Vehicle> _vehicles = [];
  List<Department> _departments = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.fetchUsers(),
        ApiService.fetchAssignments(),
        ApiService.fetchVehicles(),
        ApiService.fetchDepartments(),
      ]);
      if (mounted) {
        setState(() {
          _users = results[0] as List<AppUser>;
          _assignments = results[1] as List<Map<String, dynamic>>;
          _vehicles = results[2] as List<Vehicle>;
          _departments = results[3] as List<Department>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load users: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: _load),
          ),
        );
      }
    }
  }

  List<AppUser> get _filtered {
    final q = _searchQuery.toLowerCase();
    if (q.isEmpty) return _users;
    return _users.where((u) =>
      u.fullName.toLowerCase().contains(q) ||
      (u.employeeId?.toLowerCase().contains(q) ?? false) ||
      (u.departmentName?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Assignment')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAssignUserToVehicle,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search users by name, ID, department...',
                prefixIcon: Icon(Icons.search, color: AppColors.textLight, size: 20),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.accent,
                    child: _filtered.isEmpty
                        ? const Center(child: Text('No users found', style: AppTextStyles.body))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _UserCard(
                              user: _filtered[i],
                              assignments: _assignments.where((a) =>
                                a['assigned_user_id'] == _filtered[i].id).toList(),
                              onAssignVehicle: () => _showAssignVehicleToUser(_filtered[i]),
                              onRemoveAssignment: (id) => _removeAssignment(id),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showAssignVehicleToUser(AppUser user) {
    String? selectedVehicleId;
    final unassigned = _vehicles.where((v) =>
      !_assignments.any((a) => a['assigned_user_id'] == user.id && a['vehicle_id'] == v.id)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign Vehicle to ${user.fullName}', style: AppTextStyles.heading2),
              const SizedBox(height: 6),
              Text('Employee: ${user.employeeId ?? "N/A"}', style: AppTextStyles.bodySmall),
              const SizedBox(height: 20),
              const Text('Select Vehicle', style: AppTextStyles.label),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedVehicleId,
                    isExpanded: true,
                    hint: const Text('Select vehicle', style: TextStyle(fontSize: 14, color: AppColors.textLight)),
                    items: unassigned.map((v) => DropdownMenuItem(
                      value: v.id,
                      child: Text('${v.vehicleId} — ${v.variant}'),
                    )).toList(),
                    onChanged: (v) => setModal(() => selectedVehicleId = v),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedVehicleId == null ? null : () async {
                    await ApiService.createAssignment(
                      vehicleId: selectedVehicleId!,
                      assignedUserId: user.id,
                    );
                    if (mounted) { Navigator.pop(context); _load(); }
                  },
                  child: const Text('Assign Vehicle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignUserToVehicle() {
    String? selectedVehicleId;
    String? selectedUserId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create New Assignment', style: AppTextStyles.heading2),
              const SizedBox(height: 20),
              const Text('Vehicle', style: AppTextStyles.label),
              const SizedBox(height: 6),
              _dropdownField(
                value: selectedVehicleId,
                hint: 'Select vehicle',
                items: _vehicles.map((v) => DropdownMenuItem(value: v.id, child: Text(v.vehicleId))).toList(),
                onChanged: (v) => setModal(() => selectedVehicleId = v),
              ),
              const SizedBox(height: 12),
              const Text('User', style: AppTextStyles.label),
              const SizedBox(height: 6),
              _dropdownField(
                value: selectedUserId,
                hint: 'Select user',
                items: _users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.fullName))).toList(),
                onChanged: (v) => setModal(() => selectedUserId = v),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedVehicleId == null || selectedUserId == null ? null : () async {
                    await ApiService.createAssignment(
                      vehicleId: selectedVehicleId!,
                      assignedUserId: selectedUserId,
                    );
                    if (mounted) { Navigator.pop(context); _load(); }
                  },
                  child: const Text('Create Assignment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeAssignment(String id) async {
    await ApiService.removeAssignment(id);
    _load();
  }

  Widget _dropdownField({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.divider),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        hint: Text(hint, style: const TextStyle(fontSize: 14, color: AppColors.textLight)),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final List<Map<String, dynamic>> assignments;
  final VoidCallback onAssignVehicle;
  final Function(String) onRemoveAssignment;

  const _UserCard({
    required this.user,
    required this.assignments,
    required this.onAssignVehicle,
    required this.onRemoveAssignment,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.accent.withValues(alpha: 0.12),
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: AppTextStyles.heading3),
                  if (user.employeeId != null)
                    Text('ID: ${user.employeeId}', style: AppTextStyles.caption),
                  if (user.departmentName != null)
                    Text(user.departmentName!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                ],
              ),
            ),
            _RoleBadge(role: user.role),
          ],
        ),
        if (assignments.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          ...assignments.map((a) => _AssignmentChip(
            label: a['vehicles']?['vehicle_id'] ?? 'Unknown',
            onRemove: () => onRemoveAssignment(a['id']),
          )),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onAssignVehicle,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Assign Vehicle', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 32),
          ),
        ),
      ],
    ),
  );
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(role, style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
  );
}

class _AssignmentChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _AssignmentChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        const Icon(Icons.electric_scooter, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500)),
        const Spacer(),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close, size: 16, color: AppColors.severityCritical),
        ),
      ],
    ),
  );
}
