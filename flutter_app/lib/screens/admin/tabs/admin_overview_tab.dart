import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../services/api_service.dart';

class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({super.key});

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  bool _loading = true;
  int _pendingCount = 0;
  int _totalUsers = 0;
  int _totalVehicles = 0;
  int _broadcastCount = 0;
  List<Map<String, dynamic>> _activityLog = [];
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.fetchUsersByApprovalStatus('pending'),
        ApiService.fetchAllUsersAdmin(),
        ApiService.fetchActivityLog(limit: 20),
        ApiService.fetchBroadcasts(),
        ApiService.fetchDashboardStats(),
      ]);
      if (!mounted) return;
      setState(() {
        _pendingCount = (results[0] as List).length;
        _totalUsers = (results[1] as List).length;
        _activityLog = results[2] as List<Map<String, dynamic>>;
        _broadcastCount = (results[3] as List).length;
        final stats = results[4] as Map<String, int>;
        _totalVehicles = stats['total_vehicles'] ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    _channel = ApiService.subscribeToActivityLog((payload) {
      if (!mounted) return;
      setState(() {
        _activityLog.insert(0, payload);
        if (_activityLog.length > 50) _activityLog.removeLast();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Page Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.dashboard_rounded,
                    color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overview',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('Admin command center',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              _buildRefreshButton(),
            ],
          ),
          const SizedBox(height: 24),

          // Stat Cards Grid
          _buildStatCardsGrid(),
          const SizedBox(height: 28),

          // Activity Feed
          _buildSectionHeader(
              Icons.timeline_rounded, 'Live Activity Feed', AppColors.primary),
          const SizedBox(height: 12),
          _buildActivityFeed(),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() => _loading = true);
          _loadData();
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.refresh_rounded,
              color: AppColors.textSecondary, size: 20),
        ),
      ),
    );
  }

  Widget _buildStatCardsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 700 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStatCard(
              icon: Icons.pending_actions_rounded,
              label: 'Pending Approvals',
              value: '$_pendingCount',
              color: AppColors.severityHigh,
              highlight: _pendingCount > 0,
            ),
            _buildStatCard(
              icon: Icons.people_alt_rounded,
              label: 'Total Users',
              value: '$_totalUsers',
              color: AppColors.primary,
            ),
            _buildStatCard(
              icon: Icons.electric_scooter_rounded,
              label: 'Fleet Size',
              value: '$_totalVehicles',
              color: AppColors.accent,
            ),
            _buildStatCard(
              icon: Icons.campaign_rounded,
              label: 'Broadcasts',
              value: '$_broadcastCount',
              color: AppColors.statusIdle,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool highlight = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? color.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? color.withValues(alpha: 0.3) : AppColors.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (highlight)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6),
                    ],
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: highlight ? color : AppColors.textPrimary)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.statusActive.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.statusActive,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text('LIVE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.statusActive)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityFeed() {
    if (_activityLog.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.inbox_rounded, size: 40, color: AppColors.textLight),
              SizedBox(height: 12),
              Text('No activity yet',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _activityLog.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = _activityLog[index];
          return _buildActivityItem(entry);
        },
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> entry) {
    final eventType = entry['event_type'] as String? ?? 'other';
    final description = entry['description'] as String? ?? '';
    final actorName = entry['actor_name'] as String? ?? 'System';
    final createdAt = entry['created_at'] != null
        ? DateTime.tryParse(entry['created_at'])
        : null;
    final timeStr = createdAt != null
        ? DateFormat('MMM d, h:mm a').format(createdAt.toLocal())
        : '';

    final iconData = _eventIcon(eventType);
    final iconColor = _eventColor(eventType);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatEventType(eventType),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(actorName,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(timeStr,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textLight)),
            ],
          ),
        ],
      ),
    );
  }

  IconData _eventIcon(String eventType) {
    switch (eventType) {
      case 'user_approved':
        return Icons.check_circle_rounded;
      case 'user_rejected':
        return Icons.cancel_rounded;
      case 'user_suspended':
        return Icons.pause_circle_rounded;
      case 'user_reactivated':
        return Icons.play_circle_rounded;
      case 'user_edited':
        return Icons.edit_rounded;
      case 'user_deleted':
        return Icons.delete_rounded;
      case 'clock_in':
        return Icons.login_rounded;
      case 'clock_out':
        return Icons.logout_rounded;
      case 'report_submitted':
        return Icons.description_rounded;
      case 'alert_acknowledged':
        return Icons.notifications_active_rounded;
      case 'vehicle_updated':
        return Icons.electric_scooter_rounded;
      case 'broadcast_sent':
        return Icons.campaign_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _eventColor(String eventType) {
    switch (eventType) {
      case 'user_approved':
      case 'user_reactivated':
        return AppColors.statusActive;
      case 'user_rejected':
      case 'user_suspended':
      case 'user_deleted':
        return AppColors.severityCritical;
      case 'user_edited':
      case 'vehicle_updated':
        return AppColors.statusIdle;
      case 'broadcast_sent':
        return AppColors.accent;
      case 'alert_acknowledged':
        return AppColors.severityMedium;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatEventType(String eventType) {
    return eventType
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
