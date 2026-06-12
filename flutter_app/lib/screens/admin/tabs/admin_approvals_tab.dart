import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/user.dart';
import '../../../services/api_service.dart';


class AdminApprovalsTab extends StatefulWidget {
  final ValueChanged<int>? onBadgeCountChanged;

  const AdminApprovalsTab({super.key, this.onBadgeCountChanged});

  @override
  State<AdminApprovalsTab> createState() => _AdminApprovalsTabState();
}

class _AdminApprovalsTabState extends State<AdminApprovalsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AppUser> _pending = [];
  List<AppUser> _approved = [];
  List<AppUser> _rejected = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.fetchUsersByApprovalStatus('pending'),
        ApiService.fetchUsersByApprovalStatus('approved'),
        ApiService.fetchUsersByApprovalStatus('rejected'),
      ]);
      if (mounted) {
        setState(() {
          _pending  = results[0];
          _approved = results[1];
          _rejected = results[2];
          _loading  = false;
        });
        widget.onBadgeCountChanged?.call(_pending.length);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(AppUser user) async {
    final confirm = await _confirmDialog(
      'Approve ${user.fullName}?',
      'This user will be granted access to the app as a ${user.role}.',
      confirmLabel: 'Approve',
      confirmColor: AppColors.statusActive,
    );
    if (confirm != true) return;
    await ApiService.updateUserApproval(user.id, 'approved');
    await ApiService.logActivity(
      eventType: 'user_approved',
      description: '${user.fullName} was approved as ${user.role}',
    );
    _load();
  }

  Future<void> _reject(AppUser user) async {
    final confirm = await _confirmDialog(
      'Reject ${user.fullName}?',
      'This user will be denied access. They can be approved later from the Users tab.',
      confirmLabel: 'Reject',
      confirmColor: AppColors.severityCritical,
    );
    if (confirm != true) return;
    await ApiService.updateUserApproval(user.id, 'rejected');
    await ApiService.logActivity(
      eventType: 'user_rejected',
      description: '${user.fullName}\'s registration was rejected',
    );
    _load();
  }

  Future<bool?> _confirmDialog(String title, String message,
      {required String confirmLabel, required Color confirmColor}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTopBar(),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.accent,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(text: 'Pending (${_pending.length})'),
              Tab(text: 'Approved (${_approved.length})'),
              Tab(text: 'Rejected (${_rejected.length})'),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(_pending, showActions: true),
                      _buildList(_approved, showActions: false),
                      _buildList(_rejected, showActions: false),
                    ],
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
        left: 20, right: 20, bottom: 16,
      ),
      color: AppColors.primary,
      child: Row(
        children: [
          const Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Approvals', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                Text('Manage new user registrations', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<AppUser> users, {required bool showActions}) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              showActions ? Icons.check_circle_outline_rounded : Icons.inbox_rounded,
              size: 56, color: AppColors.textLight,
            ),
            const SizedBox(height: 12),
            Text(
              showActions ? 'No pending approvals' : 'No users here',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (_, i) => _ApprovalCard(
          user: users[i],
          showActions: showActions,
          onApprove: () => _approve(users[i]),
          onReject: () => _reject(users[i]),
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final AppUser user;
  final bool showActions;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApprovalCard({
    required this.user,
    required this.showActions,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _roleColor(user.role).withValues(alpha: 0.12),
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                  style: TextStyle(color: _roleColor(user.role), fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(user.phone.isEmpty ? 'No phone' : user.phone,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              _RoleBadge(role: user.role),
            ],
          ),
          if (user.createdAt != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textLight),
                const SizedBox(width: 4),
                Text(
                  'Registered ${_timeAgo(user.createdAt!)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                ),
              ],
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.severityCritical,
                      side: const BorderSide(color: AppColors.severityCritical),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onReject,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusActive,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onApprove,
                  ),
                ),
              ],
            ),
          ],
        ],
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(role.toUpperCase(),
          style: TextStyle(fontSize: 10, color: bg, fontWeight: FontWeight.w700)),
    );
  }
}
