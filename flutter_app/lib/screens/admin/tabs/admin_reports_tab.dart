import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/vehicle_alert.dart';
import '../../../services/api_service.dart';

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  List<VehicleAlert> _alerts = [];
  bool _loading = true;
  bool _showOnlyUnack = false;
  String _filterSeverity = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final alerts = await ApiService.fetchAlertEvents();
      if (mounted) setState(() { _alerts = alerts; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<VehicleAlert> get _filtered {
    var list = _alerts;
    if (_showOnlyUnack) list = list.where((a) => !a.isAcknowledged).toList();
    if (_filterSeverity != 'all') list = list.where((a) => a.severity == _filterSeverity).toList();
    return list;
  }

  Future<void> _acknowledge(VehicleAlert alert) async {
    await ApiService.acknowledgeAlert(alert.id);
    await ApiService.logActivity(
      eventType: 'alert_acknowledged',
      description: 'Alert on ${alert.vehicleId} acknowledged (${alert.alertType})',
    );
    _load();
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
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 56, color: AppColors.statusActive),
                            SizedBox(height: 12),
                            Text('No alerts found', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.accent,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _AlertCard(
                            alert: _filtered[i],
                            onAcknowledge: () => _acknowledge(_filtered[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final unackCount = _alerts.where((a) => !a.isAcknowledged).length;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20, right: 20, bottom: 16,
      ),
      color: AppColors.primary,
      child: Row(
        children: [
          const Icon(Icons.report_problem_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reports & Alerts', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                Text('$unackCount unacknowledged', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          if (unackCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.severityCritical,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$unackCount OPEN',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white70), onPressed: _load),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    const severities = [
      ('all', 'All'),
      ('critical', 'Critical'),
      ('high', 'High'),
      ('medium', 'Medium'),
      ('low', 'Low'),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: severities.map((f) {
                      final isSelected = _filterSeverity == f.$1;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _filterSeverity = f.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected ? _severityColor(f.$1) : AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? _severityColor(f.$1) : AppColors.cardBorder),
                            ),
                            child: Text(f.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : AppColors.textSecondary)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _showOnlyUnack,
                  onChanged: (v) => setState(() => _showOnlyUnack = v),
                  activeThumbColor: AppColors.accent,
                ),
              ),
              const Text('Unack only', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'critical': return AppColors.severityCritical;
      case 'high':     return AppColors.severityHigh;
      case 'medium':   return AppColors.severityMedium;
      case 'low':      return AppColors.severityLow;
      default:         return AppColors.textSecondary;
    }
  }
}

class _AlertCard extends StatelessWidget {
  final VehicleAlert alert;
  final VoidCallback onAcknowledge;

  const _AlertCard({required this.alert, required this.onAcknowledge});

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(alert.severity);
    final timeAgo = _timeAgo(alert.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(_alertIcon(alert.alertType), color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.message.isEmpty ? alert.alertType : alert.message,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text('Vehicle: ${alert.vehicleId.substring(0, 8)}...',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _SeverityBadge(severity: alert.severity),
                    const SizedBox(height: 4),
                    Text(timeAgo, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                  ],
                ),
              ],
            ),
            if (!alert.isAcknowledged) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Acknowledge', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.statusActive,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: onAcknowledge,
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 13, color: AppColors.statusActive),
                  SizedBox(width: 4),
                  Text('Acknowledged', style: TextStyle(fontSize: 11, color: AppColors.statusActive, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'critical': return AppColors.severityCritical;
      case 'high':     return AppColors.severityHigh;
      case 'medium':   return AppColors.severityMedium;
      case 'low':      return AppColors.severityLow;
      default:         return AppColors.textSecondary;
    }
  }

  IconData _alertIcon(String type) {
    switch (type) {
      case 'speed':     return Icons.speed_rounded;
      case 'battery':   return Icons.battery_alert_rounded;
      case 'geofence':  return Icons.fence_rounded;
      case 'idle_time': return Icons.timer_off_rounded;
      case 'movement':  return Icons.warning_rounded;
      default:          return Icons.notifications_active_rounded;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _SeverityBadge extends StatelessWidget {
  final String severity;
  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (severity) {
      case 'critical': color = AppColors.severityCritical; break;
      case 'high':     color = AppColors.severityHigh; break;
      case 'medium':   color = AppColors.severityMedium; break;
      default:         color = AppColors.severityLow;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(severity.toUpperCase(), style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
    );
  }
}
