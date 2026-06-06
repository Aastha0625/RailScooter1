import 'package:flutter/material.dart';
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
      appBar: AppBar(
        title: const Text('Dashboard'),
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
                const Text('PiSolve', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: AppColors.accent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeroSection(),
              if (!_loading && _stats.isNotEmpty) _buildStatsRow(),
              _buildModuleGrid(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.electric_scooter, color: Colors.white, size: 42),
          ),
          const SizedBox(height: 16),
          const Text('PiScoot', style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          )),
          const SizedBox(height: 4),
          Text('The Railway Scooter', style: TextStyle(
            color: AppColors.accent,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          )),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _statChip(Icons.electric_scooter_outlined, '${_stats['total_vehicles'] ?? 0}', 'Vehicles', AppColors.primary),
          const SizedBox(width: 8),
          _statChip(Icons.check_circle_outline, '${_stats['active_vehicles'] ?? 0}', 'Active', AppColors.statusActive),
          const SizedBox(width: 8),
          _statChip(Icons.notifications_active_outlined, '${_stats['unacknowledged_alerts'] ?? 0}', 'Alerts', AppColors.severityHigh),
          const SizedBox(width: 8),
          _statChip(Icons.business_outlined, '${_stats['total_departments'] ?? 0}', 'Depts', AppColors.statusIdle),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleGrid(BuildContext context) {
    final modules = [
      _ModuleItem(
        icon: Icons.directions_car_outlined,
        label: 'Vehicle\nRegistration',
        color: AppColors.accent,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleRegistryScreen())),
      ),
      _ModuleItem(
        icon: Icons.business_center_outlined,
        label: 'Department\nAssignment',
        color: AppColors.primary,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DepartmentAssignmentScreen())),
      ),
      _ModuleItem(
        icon: Icons.person_outline,
        label: 'User\nAssignment',
        color: AppColors.accent,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserAssignmentScreen())),
      ),
      _ModuleItem(
        icon: Icons.shield_outlined,
        label: 'Alerts & Rules',
        color: AppColors.primary,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsRulesScreen())),
      ),
      _ModuleItem(
        icon: Icons.dashboard_outlined,
        label: 'Dashboard',
        color: AppColors.accent,
        onTap: () {},
      ),
      _ModuleItem(
        icon: Icons.location_on_outlined,
        label: 'GeoFence &\nTracking',
        color: AppColors.primary,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GeofenceTrackingScreen())),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemCount: modules.length,
        itemBuilder: (context, i) => _ModuleCard(module: modules[i]),
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

class _ModuleCard extends StatelessWidget {
  final _ModuleItem module;
  const _ModuleCard({required this.module});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: module.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: module.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: module.color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(module.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                module.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: module.color == AppColors.accent ? AppColors.accent : AppColors.primary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
