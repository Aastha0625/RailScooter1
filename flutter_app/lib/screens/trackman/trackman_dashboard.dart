import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../vehicles/vehicle_registry_screen.dart';
import '../departments/department_assignment_screen.dart';
import '../users/user_assignment_screen.dart';
import '../alerts/alerts_rules_screen.dart';
import '../tracking/geofence_tracking_screen.dart';
import 'trackman_history_screen.dart';
import 'trackman_safety_screen.dart';
import 'trackman_geofencing_screen.dart';
import 'trackman_report_issue_screen.dart';

class TrackmanDashboardScreen extends StatefulWidget {
  const TrackmanDashboardScreen({super.key});

  @override
  State<TrackmanDashboardScreen> createState() => _TrackmanDashboardScreenState();
}

class _TrackmanDashboardScreenState extends State<TrackmanDashboardScreen> {
  bool _isUnlocked = false;
  bool _loading = true;
  Map<String, dynamic>? _activeAssignment;

  @override
  void initState() {
    super.initState();
    _fetchActiveVehicle();
  }

  Future<void> _fetchActiveVehicle() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final data = await Supabase.instance.client
          .from('vehicle_assignments')
          .select('''
            id,
            is_active,
            vehicles (
              id,
              vehicle_id,
              battery_level,
              current_speed,
              estimated_range
            )
          ''')
          .eq('assigned_user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _activeAssignment = data;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching active vehicle: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trackman Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 32),
            child: Center(
              child: Transform.scale(
                scale: 6.0,
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActiveVehicleHero(),
            const SizedBox(height: 16),
            _buildSafetyAndLocationCard(),
            const SizedBox(height: 16),
            _buildEmergencyActions(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveVehicleHero() {
    if (_loading) {
      return Container(
        width: double.infinity,
        height: 200,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        ),
        child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    final hasAssignment = _activeAssignment != null;
    final vehicle = hasAssignment ? _activeAssignment!['vehicles'] : null;
    final vehicleLabel = vehicle != null ? vehicle['vehicle_id'] : 'No Vehicle Assigned';

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
                  color: _isUnlocked ? Colors.green : AppColors.statusIdle,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: (_isUnlocked ? Colors.green : AppColors.statusIdle).withValues(alpha: 0.35), blurRadius: 15, offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(_isUnlocked ? Icons.lock_open : Icons.lock, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicleLabel, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                  Text(hasAssignment ? (_isUnlocked ? 'Active Run' : 'Locked') : 'Awaiting Assignment', style: TextStyle(color: hasAssignment ? (_isUnlocked ? Colors.greenAccent : Colors.white70) : Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
              const Spacer(),
              if (hasAssignment)
                Switch(
                  value: _isUnlocked,
                  activeColor: Colors.greenAccent,
                  onChanged: (val) {
                    setState(() {
                      _isUnlocked = val;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Telemetry Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTelemetryItem(Icons.speed, _isUnlocked ? '${vehicle?['current_speed'] ?? 0} km/h' : '0 km/h', 'Speed'),
              _buildTelemetryItem(Icons.battery_charging_full, '${vehicle?['battery_level'] ?? 0}%', 'Battery'),
              _buildTelemetryItem(Icons.timeline, '${vehicle?['estimated_range'] ?? 0} km', 'Est. Range'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildSafetyAndLocationCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.location_on, color: AppColors.accent, size: 40),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Zone', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                  SizedBox(height: 4),
                  Text('Main Station Zone', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TrackmanReportIssueScreen(),));
                  },
                  icon: const Icon(Icons.report_problem, color: Colors.white),
                  label: const Text('Report Issue', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Emergency Stop Triggered!'), backgroundColor: Colors.red));
                  },
                  icon: const Icon(Icons.warning, color: Colors.white),
                  label: const Text('SOS / Stop', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Reusing the exact same Drawer as the Admin Dashboard
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Row(
              children: [
                Transform.scale(
                  scale: 2.5,
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 48,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 24),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PiSolve', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('Fleet Management', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          _drawerItem(context, Icons.dashboard_outlined, 'Dashboard', () => Navigator.pop(context)),
          _drawerItem(context, Icons.history, 'My Ride History', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackmanHistoryScreen()));
          }),
          _drawerItem(context, Icons.shield_outlined, 'Safety Guidelines', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackmanSafetyScreen()));
          }),
          _drawerItem(context, Icons.map_outlined, 'My Current Zone', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackmanGeofencingScreen()));
          }),
          _drawerItem(context, Icons.report_problem_outlined, 'Report an Issue', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackmanReportIssueScreen()));
          }),
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
