import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/department.dart';
import '../../models/vehicle.dart';
import '../../services/api_service.dart';

class DepartmentAssignmentScreen extends StatefulWidget {
  const DepartmentAssignmentScreen({super.key});

  @override
  State<DepartmentAssignmentScreen> createState() => _DepartmentAssignmentScreenState();
}

class _DepartmentAssignmentScreenState extends State<DepartmentAssignmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Department> _departments = [];
  List<Map<String, dynamic>> _assignments = [];
  List<Vehicle> _vehicles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.fetchDepartments(),
        ApiService.fetchAssignments(),
        ApiService.fetchVehicles(),
      ]);
      if (mounted) {
        setState(() {
          _departments = results[0] as List<Department>;
          _assignments = results[1] as List<Map<String, dynamic>>;
          _vehicles = results[2] as List<Vehicle>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: _load),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Department Assignment'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Departments'),
            Tab(text: 'Assignments'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _tabs.index == 0 ? _showAddDepartment() : _showAssignVehicle(),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : TabBarView(
              controller: _tabs,
              children: [
                _buildDepartmentList(),
                _buildAssignmentList(),
              ],
            ),
    );
  }

  Widget _buildDepartmentList() {
    if (_departments.isEmpty) {
      return const Center(child: Text('No departments found. Add one!', style: AppTextStyles.body));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _departments.length,
        itemBuilder: (_, i) => _DepartmentCard(
          department: _departments[i],
          assignmentCount: _assignments.where((a) => a['department_id'] == _departments[i].id).length,
          onEdit: () => _showEditDepartment(_departments[i]),
          onDelete: () => _confirmDeleteDepartment(_departments[i]),
        ),
      ),
    );
  }

  Widget _buildAssignmentList() {
    if (_assignments.isEmpty) {
      return const Center(child: Text('No active assignments.', style: AppTextStyles.body));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _assignments.length,
        itemBuilder: (_, i) {
          final a = _assignments[i];
          return _AssignmentCard(
            assignment: a,
            onRemove: () => _confirmRemoveAssignment(a['id']),
          );
        },
      ),
    );
  }

  void _showAddDepartment() => _showDepartmentForm(null);
  void _showEditDepartment(Department d) => _showDepartmentForm(d);

  void _showDepartmentForm(Department? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final headCtrl = TextEditingController(text: existing?.headName ?? '');
    final emailCtrl = TextEditingController(text: existing?.contactEmail ?? '');
    final locationCtrl = TextEditingController(text: existing?.location ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(existing == null ? 'Add Department' : 'Edit Department', style: AppTextStyles.heading2),
                  const SizedBox(height: 20),
                  _field('Department Name *', nameCtrl, validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  _field('Code *', codeCtrl, hint: 'e.g., MECH', validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  _field('Head Name', headCtrl),
                  const SizedBox(height: 12),
                  _field('Email', emailCtrl),
                  const SizedBox(height: 12),
                  _field('Location', locationCtrl),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final data = {
                          'name': nameCtrl.text.trim(),
                          'code': codeCtrl.text.trim().toUpperCase(),
                          'head_name': headCtrl.text.trim(),
                          'contact_email': emailCtrl.text.trim(),
                          'location': locationCtrl.text.trim(),
                        };
                        if (existing == null) {
                          await ApiService.createDepartment(data);
                        } else {
                          await ApiService.updateDepartment(existing.id, data);
                        }
                        if (mounted) { Navigator.pop(context); _load(); }
                      },
                      child: Text(existing == null ? 'Add Department' : 'Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAssignVehicle() {
    String? selectedVehicleId;
    String? selectedDeptId;

    final unassigned = _vehicles.where((v) =>
      !_assignments.any((a) => a['vehicle_id'] == v.id)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assign Vehicle to Department', style: AppTextStyles.heading2),
              const SizedBox(height: 20),
              const Text('Vehicle', style: AppTextStyles.label),
              const SizedBox(height: 6),
              _dropdownField(
                value: selectedVehicleId,
                hint: 'Select vehicle',
                items: unassigned.map((v) => DropdownMenuItem(value: v.id, child: Text(v.vehicleId))).toList(),
                onChanged: (v) => setModalState(() => selectedVehicleId = v),
              ),
              const SizedBox(height: 12),
              const Text('Department', style: AppTextStyles.label),
              const SizedBox(height: 6),
              _dropdownField(
                value: selectedDeptId,
                hint: 'Select department',
                items: _departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                onChanged: (v) => setModalState(() => selectedDeptId = v),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedVehicleId == null || selectedDeptId == null ? null : () async {
                    await ApiService.createAssignment(vehicleId: selectedVehicleId!, departmentId: selectedDeptId);
                    if (mounted) { Navigator.pop(context); _load(); }
                  },
                  child: const Text('Assign'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteDepartment(Department d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Department'),
        content: Text('Delete "${d.name}"? Active assignments will be unlinked.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.severityCritical),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) { await ApiService.deleteDepartment(d.id); _load(); }
  }

  Future<void> _confirmRemoveAssignment(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Assignment'),
        content: const Text('Unassign this vehicle from its department?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) { await ApiService.removeAssignment(id); _load(); }
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, String? Function(String?)? validator}) =>
    TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: validator,
    );

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

class _DepartmentCard extends StatelessWidget {
  final Department department;
  final int assignmentCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DepartmentCard({
    required this.department,
    required this.assignmentCount,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
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
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.business_outlined, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(department.name, style: AppTextStyles.heading3),
                  Text(department.code, style: AppTextStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit, color: AppColors.textSecondary),
            IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: onDelete, color: AppColors.severityCritical),
          ],
        ),
        if (department.headName.isNotEmpty || department.location.isNotEmpty) ...[
          const SizedBox(height: 10),
          if (department.headName.isNotEmpty)
            _InfoRow(icon: Icons.person_outline, text: department.headName),
          if (department.location.isNotEmpty)
            _InfoRow(icon: Icons.location_on_outlined, text: department.location),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$assignmentCount vehicle${assignmentCount != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            if (!department.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.statusOffline.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: const Text('Inactive', style: TextStyle(fontSize: 11, color: AppColors.statusOffline)),
              ),
          ],
        ),
      ],
    ),
  );
}

class _AssignmentCard extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final VoidCallback onRemove;

  const _AssignmentCard({required this.assignment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final vehicle = assignment['vehicles'];
    final dept = assignment['departments'];
    final user = assignment['app_users!vehicle_assignments_assigned_user_id_fkey'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.electric_scooter, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle?['vehicle_id'] ?? 'Unknown', style: AppTextStyles.heading3),
                Text(vehicle?['variant'] ?? '', style: AppTextStyles.caption),
                if (dept != null) Text(dept['name'], style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                if (user != null) Text(user['full_name'], style: AppTextStyles.caption),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.link_off, size: 20),
            onPressed: onRemove,
            color: AppColors.severityCritical,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textLight),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.bodySmall),
      ],
    ),
  );
}
