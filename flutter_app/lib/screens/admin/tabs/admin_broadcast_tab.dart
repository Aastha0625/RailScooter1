import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/api_service.dart';

class AdminBroadcastTab extends StatefulWidget {
  const AdminBroadcastTab({super.key});

  @override
  State<AdminBroadcastTab> createState() => _AdminBroadcastTabState();
}

class _AdminBroadcastTabState extends State<AdminBroadcastTab> {
  final _titleCtrl   = TextEditingController();
  final _bodyCtrl    = TextEditingController();
  String _targetRole = 'all';
  bool _sending      = false;
  bool _previewing   = false;

  List<Map<String, dynamic>> _history = [];
  bool _historyLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    try {
      final list = await ApiService.fetchBroadcasts();
      if (mounted) setState(() { _history = list; _historyLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both title and message.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await ApiService.sendBroadcast(
        title:      _titleCtrl.text.trim(),
        body:       _bodyCtrl.text.trim(),
        targetRole: _targetRole,
      );
      await ApiService.logActivity(
        eventType: 'broadcast_sent',
        description: 'Broadcast "${_titleCtrl.text.trim()}" sent to $_targetRole',
      );
      _titleCtrl.clear();
      _bodyCtrl.clear();
      setState(() => _previewing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Broadcast sent successfully!'),
            backgroundColor: AppColors.statusActive,
          ),
        );
      }
      _loadHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildTopBar()),
          SliverToBoxAdapter(child: _buildComposer()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  const Text('Sent Broadcasts',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20), onPressed: _loadHistory),
                ],
              ),
            ),
          ),
          _historyLoading
              ? const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.accent))))
              : _history.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.campaign_rounded, size: 48, color: AppColors.textLight),
                              SizedBox(height: 12),
                              Text('No broadcasts sent yet', style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _BroadcastHistoryCard(broadcast: _history[i]),
                        childCount: _history.length,
                      ),
                    ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
      child: const Row(
        children: [
          Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Broadcast Messages', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              Text('Send alerts to Managers or Trackmen', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_rounded, color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Compose Broadcast', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),

          // Target audience
          const Text('Target Audience', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              _AudienceChip(label: 'All Users', value: 'all', selectedValue: _targetRole,
                  icon: Icons.people_rounded, onTap: () => setState(() => _targetRole = 'all')),
              const SizedBox(width: 8),
              _AudienceChip(label: 'Managers', value: 'manager', selectedValue: _targetRole,
                  icon: Icons.manage_accounts_rounded, onTap: () => setState(() => _targetRole = 'manager')),
              const SizedBox(width: 8),
              _AudienceChip(label: 'Trackmen', value: 'trackman', selectedValue: _targetRole,
                  icon: Icons.engineering_rounded, onTap: () => setState(() => _targetRole = 'trackman')),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          const Text('Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            onChanged: (_) => setState(() => _previewing = false),
            decoration: const InputDecoration(hintText: 'e.g. Urgent: Track Inspection Required'),
          ),
          const SizedBox(height: 12),

          // Body
          const Text('Message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _bodyCtrl,
            maxLines: 4,
            onChanged: (_) => setState(() => _previewing = false),
            decoration: const InputDecoration(hintText: 'Type your broadcast message here...'),
          ),
          const SizedBox(height: 16),

          // Preview card
          if (_previewing && _titleCtrl.text.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign_rounded, color: AppColors.primary, size: 16),
                      const SizedBox(width: 6),
                      const Text('Preview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          _targetRole == 'all' ? 'All' : _targetRole.toUpperCase(),
                          style: const TextStyle(fontSize: 9, color: AppColors.accent, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_titleCtrl.text.trim(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  if (_bodyCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(_bodyCtrl.text.trim(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.preview_rounded, size: 16),
                  label: const Text('Preview'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => setState(() => _previewing = true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(_sending ? 'Sending...' : 'Send Broadcast'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _sending ? null : _send,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AudienceChip extends StatelessWidget {
  final String label;
  final String value;
  final String selectedValue;
  final IconData icon;
  final VoidCallback onTap;

  const _AudienceChip({
    required this.label, required this.value, required this.selectedValue,
    required this.icon, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selectedValue;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _BroadcastHistoryCard extends StatelessWidget {
  final Map<String, dynamic> broadcast;
  const _BroadcastHistoryCard({required this.broadcast});

  @override
  Widget build(BuildContext context) {
    final title    = broadcast['title'] as String? ?? '';
    final body     = broadcast['body']  as String? ?? '';
    final role     = broadcast['target_role'] as String? ?? 'all';
    final sentByName = broadcast['app_users']?['full_name'] as String? ?? 'Admin';
    final createdAt = broadcast['created_at'] != null
        ? DateTime.tryParse(broadcast['created_at'])
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_rounded, color: AppColors.accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(role == 'all' ? 'All' : role.toUpperCase(),
                    style: const TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 12, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text('by $sentByName', style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
              const Spacer(),
              if (createdAt != null)
                Text(_timeAgo(createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
            ],
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
