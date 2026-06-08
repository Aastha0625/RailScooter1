import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../vehicles/vehicle_registry_screen.dart';
import '../departments/department_assignment_screen.dart';
import '../users/user_assignment_screen.dart';
import '../alerts/alerts_rules_screen.dart';
import '../tracking/geofence_tracking_screen.dart';
import '../../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, int> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await ApiService.fetchDashboardStats();
      if (mounted) setState(() { _stats = stats; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load dashboard: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: _loadStats),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('PS', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('PiSolve', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: AppColors.accent,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroSection(),
                    const SizedBox(height: 16),
                    _buildQuickActionCards(context),
                    const SizedBox(height: 24),
                    _buildAnalyticsTitle('Fleet Status Overview'),
                    _buildFleetStatusChart(),
                    const SizedBox(height: 24),
                    _buildAnalyticsTitle('Critical Metrics'),
                    _buildMetricsGrid(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 15, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.electric_scooter, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PiScoot', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                  Text('The Railway Scooter', style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCards(BuildContext context) {
    final modules = [
      _ModuleItem(icon: Icons.map_outlined, label: 'Tracking', color: AppColors.primary, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GeofenceTrackingScreen()))),
      _ModuleItem(icon: Icons.shield_outlined, label: 'Alerts', color: AppColors.severityHigh, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsRulesScreen()))),
      _ModuleItem(icon: Icons.directions_car_outlined, label: 'Vehicles', color: AppColors.accent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleRegistryScreen()))),
      _ModuleItem(icon: Icons.people_outline, label: 'Users', color: AppColors.primary, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserAssignmentScreen()))),
      _ModuleItem(icon: Icons.business_outlined, label: 'Depts', color: AppColors.statusIdle, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DepartmentAssignmentScreen()))),
    ];

    return SizedBox(
      height: 90,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: modules.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _buildActionCard(modules[i]),
      ),
    );
  }

  Widget _buildActionCard(_ModuleItem module) {
    return GestureDetector(
      onTap: module.onTap,
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(module.icon, color: module.color, size: 28),
            const SizedBox(height: 8),
            Text(module.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
      ),
    );
  }

  Widget _buildFleetStatusChart() {
    // Generate derived mockup stats based on the backend total_vehicles
    final total = _stats['total_vehicles'] ?? 10;
    final active = _stats['active_vehicles'] ?? 6;
    final idle = (total * 0.2).toInt();
    final offline = (total * 0.1).toInt();
    final maintenance = total - active - idle - offline;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: [
                  if (active > 0)
                    PieChartSectionData(
                      color: AppColors.statusActive,
                      value: active.toDouble(),
                      title: '$active',
                      radius: 30,
                      titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  if (idle > 0)
                    PieChartSectionData(
                      color: AppColors.statusIdle,
                      value: idle.toDouble(),
                      title: '$idle',
                      radius: 25,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  if (maintenance > 0)
                    PieChartSectionData(
                      color: AppColors.statusMaintenance,
                      value: maintenance.toDouble(),
                      title: '$maintenance',
                      radius: 25,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  if (offline > 0)
                    PieChartSectionData(
                      color: AppColors.statusOffline,
                      value: offline.toDouble(),
                      title: '$offline',
                      radius: 25,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildChartLegend(AppColors.statusActive, 'Active'),
              _buildChartLegend(AppColors.statusIdle, 'Idle'),
              _buildChartLegend(AppColors.statusMaintenance, 'Maint'),
              _buildChartLegend(AppColors.statusOffline, 'Offline'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildChartLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildMetricCard(Icons.warning_amber_rounded, 'Active Alerts', '${_stats['unacknowledged_alerts'] ?? 0}', AppColors.severityHigh)),
          const SizedBox(width: 16),
          Expanded(child: _buildMetricCard(Icons.electric_scooter, 'Total Vehicles', '${_stats['total_vehicles'] ?? 0}', AppColors.accent)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.electric_scooter, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PiScoot', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('Fleet Management', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          _drawerItem(context, Icons.dashboard_outlined, 'Dashboard', () => Navigator.pop(context)),
          _drawerItem(context, Icons.electric_scooter_outlined, 'Vehicle Registry',
              () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleRegistryScreen())); }),
          _drawerItem(context, Icons.business_outlined, 'Departments',
              () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const DepartmentAssignmentScreen())); }),
          _drawerItem(context, Icons.people_outline, 'User Assignment',
              () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const UserAssignmentScreen())); }),
          _drawerItem(context, Icons.notifications_outlined, 'Alerts & Rules',
              () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsRulesScreen())); }),
          _drawerItem(context, Icons.map_outlined, 'GeoFence & Tracking',
              () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const GeofenceTrackingScreen())); }),
          const Spacer(),
          const Divider(height: 1),
          _drawerItem(context, Icons.logout_rounded, 'Log Out', () async {
            Navigator.pop(context);
            await Supabase.instance.client.auth.signOut();
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}

class _ModuleItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ModuleItem({required this.icon, required this.label, required this.color, required this.onTap});
}
