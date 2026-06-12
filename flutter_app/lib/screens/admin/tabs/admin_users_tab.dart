import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/user.dart';
import '../../../models/department.dart';
import '../../../services/api_service.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  List<AppUser> _users = [];
  List<Department> _departments = [];
  bool _loading = true;
  String _searchQuery = '';
  String _filterRole = 'all';   // all | admin | manager | trackman | suspended

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.fetchAllUsersAdmin(),
        ApiService.fetchDepartments(),
      ]);
      if (mounted) {
        setState(() {
          _users = results[0] as List<AppUser>;
          _departments = results[1] as List<Department>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AppUser> get _filtered {
    var list = _users;
    if (_filterRole == 'suspended') {
      list = list.where((u) => !u.isActive).toList();
    } else if (_filterRole != 'all') {
      list = list.where((u) => u.role == _filterRole).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((u) =>
        u.fullName.toLowerCase().contains(q) ||
        (u.employeeId?.toLowerCase().contains(q) ?? false) ||
        u.phone.contains(q) ||
        u.role.contains(q),
      ).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTopBar(),
          _buildFilters(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _filtered.isEmpty
                    ? const Center(child: Text('No users match filter', style: TextStyle(color: AppColors.textSecondary)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.accent,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _UserCard(
                            user: _filtered[i],
                            departments: _departments,
                            onTap: () => _openDetail(_filtered[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20, right: 20, bottom: 12,
      ),
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('All Users', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('${_users.length} total • ${_users.where((u) => u.isActive).length} active',
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white70), onPressed: _load),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by name, ID, phone...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    const filters = [
      ('all', 'All'),
      ('admin', 'Admin'),
      ('manager', 'Manager'),
      ('trackman', 'Trackman'),
      ('suspended', 'Suspended'),
    ];

    return Container(
      height: 48,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: filters.map((f) {
          final isSelected = _filterRole == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filterRole = f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? AppColors.accent : AppColors.cardBorder),
                ),
                child: Text(f.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _openDetail(AppUser user) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminUserDetailSheet(
        user: user,
        departments: _departments,
        onUpdated: _load,
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final List<Department> departments;
  final VoidCallback onTap;

  const _UserCard({required this.user, required this.departments, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: user.isActive ? AppColors.cardBorder : AppColors.severityCritical.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _roleColor(user.role).withValues(alpha: 0.12),
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                    style: TextStyle(color: _roleColor(user.role), fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                if (!user.isActive)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 12, height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.severityCritical,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.white, spreadRadius: 1.5)],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (user.employeeId != null) 'ID: ${user.employeeId}',
                      if (user.phone.isNotEmpty) user.phone,
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _RoleBadge(role: user.role),
                const SizedBox(height: 4),
                if (!user.isActive)
                  const Text('SUSPENDED', style: TextStyle(fontSize: 9, color: AppColors.severityCritical, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 20),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':   return AppColors.severityCritical;
      case 'manager': return AppColors.accent;
      default:        return AppColors.primary;
    }
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    Color bg;
    switch (role) {
      case 'manager': bg = AppColors.accent; break;
      case 'admin':   bg = AppColors.severityCritical; break;
      default:        bg = AppColors.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(role.toUpperCase(),
          style: TextStyle(fontSize: 9, color: bg, fontWeight: FontWeight.w700)),
    );
  }
}

/// ─── User Detail / Edit Bottom Sheet ───────────────────────────────────────
class AdminUserDetailSheet extends StatefulWidget {
  final AppUser user;
  final List<Department> departments;
  final VoidCallback onUpdated;

  const AdminUserDetailSheet({
    super.key,
    required this.user,
    required this.departments,
    required this.onUpdated,
  });

  @override
  State<AdminUserDetailSheet> createState() => _AdminUserDetailSheetState();
}

class _AdminUserDetailSheetState extends State<AdminUserDetailSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _empIdCtrl;
  late TextEditingController _phoneCtrl;
  late String _selectedRole;
  late String? _selectedDeptId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.user.fullName);
    _empIdCtrl = TextEditingController(text: widget.user.employeeId ?? '');
    _phoneCtrl = TextEditingController(text: widget.user.phone);
    _selectedRole   = widget.user.role;
    _selectedDeptId = widget.user.departmentId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _empIdCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.updateUserDetails(widget.user.id, {
        'full_name':    _nameCtrl.text.trim(),
        'employee_id':  _empIdCtrl.text.trim().isEmpty ? null : _empIdCtrl.text.trim(),
        'phone':        _phoneCtrl.text.trim(),
        'role':         _selectedRole,
        'department_id': _selectedDeptId,
      });
      await ApiService.logActivity(
        eventType: 'user_edited',
        description: '${widget.user.fullName}\'s profile was updated',
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleSuspend() async {
    final action = widget.user.isActive ? 'Suspend' : 'Reactivate';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$action ${widget.user.fullName}?',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          widget.user.isActive
              ? 'This user will lose access to the app immediately.'
              : 'This user will regain access to the app.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.user.isActive ? AppColors.severityCritical : AppColors.statusActive,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (widget.user.isActive) {
      await ApiService.suspendUser(widget.user.id);
      await ApiService.logActivity(eventType: 'user_suspended', description: '${widget.user.fullName} was suspended');
    } else {
      await ApiService.reactivateUser(widget.user.id);
      await ApiService.logActivity(eventType: 'user_reactivated', description: '${widget.user.fullName} was reactivated');
    }
    if (mounted) {
      Navigator.pop(context);
      widget.onUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      widget.user.fullName.isNotEmpty ? widget.user.fullName[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.user.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        Text(
                          widget.user.isActive ? '● Active' : '● Suspended',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.user.isActive ? AppColors.statusActive : AppColors.severityCritical,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    icon: Icon(
                      widget.user.isActive ? Icons.block_rounded : Icons.restore_rounded,
                      size: 16,
                    ),
                    label: Text(widget.user.isActive ? 'Suspend' : 'Reactivate'),
                    style: TextButton.styleFrom(
                      foregroundColor: widget.user.isActive ? AppColors.severityCritical : AppColors.statusActive,
                    ),
                    onPressed: _toggleSuspend,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Edit Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  _field('Full Name', _nameCtrl, Icons.person_outline_rounded),
                  const SizedBox(height: 12),
                  _field('Employee ID', _empIdCtrl, Icons.badge_outlined),
                  const SizedBox(height: 12),
                  _field('Phone', _phoneCtrl, Icons.phone_outlined),
                  const SizedBox(height: 12),
                  // Role dropdown
                  _label('Role'),
                  const SizedBox(height: 6),
                  _dropdown<String>(
                    value: _selectedRole,
                    items: const ['admin', 'manager', 'trackman', 'viewer'],
                    display: (v) => v.capitalize(),
                    onChanged: (v) => setState(() => _selectedRole = v!),
                  ),
                  const SizedBox(height: 12),
                  // Department dropdown
                  _label('Department'),
                  const SizedBox(height: 6),
                  _dropdown<String?>(
                    value: _selectedDeptId,
                    items: [null, ...widget.departments.map((d) => d.id)],
                    display: (v) => v == null ? 'No Department' : widget.departments.firstWhere((d) => d.id == v).name,
                    onChanged: (v) => setState(() => _selectedDeptId = v),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(label),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: AppColors.textLight),
        ),
      ),
    ],
  );

  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary));

  Widget _dropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) display,
    required ValueChanged<T?> onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.divider),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        items: items.map((i) => DropdownMenuItem<T>(value: i, child: Text(display(i), style: const TextStyle(fontSize: 14)))).toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

extension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
