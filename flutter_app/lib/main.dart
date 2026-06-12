import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/manager/manager_dashboard.dart';
import 'screens/trackman/trackman_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
      url: 'https://mskizgdxpcuuqzjlblou.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1za2l6Z2R4cGN1dXF6amxibG91Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5MDk0NzgsImV4cCI6MjA5NjQ4NTQ3OH0.gwAKQFhfeLMLUh4I1L4UUORv8hVQ1HzNvLTGQvs4ib4');

  runApp(const PiScootApp());
}

class PiScootApp extends StatelessWidget {
  const PiScootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PiScoot',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const WelcomeScreen();
    return const _RoleRouter();
  }
}

/// After authentication, fetches the user profile from app_users and routes
/// based on role (admin → AdminShell) and approval_status.
class _RoleRouter extends StatefulWidget {
  const _RoleRouter();

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  bool _loading = true;
  String? _role;
  String? _approvalStatus;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() { _loading = false; _error = 'No user session found.'; });
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('app_users')
          .select('role, approval_status, is_active')
          .eq('id', uid)
          .maybeSingle();

      if (data == null) {
        setState(() { _loading = false; _error = 'User profile not found.'; });
        return;
      }

      setState(() {
        _role = data['role'] as String? ?? 'trackman';
        _approvalStatus = data['approval_status'] as String? ?? 'pending';
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A1118),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(height: 16),
              Text('Loading your profile...',
                  style: TextStyle(color: Colors.white60, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorScreen(_error!);
    }

    // Check approval status first
    if (_approvalStatus == 'pending') {
      return _buildPendingScreen();
    }
    if (_approvalStatus == 'rejected') {
      return _buildRejectedScreen();
    }

    // Approved — route by role
    if (_role == 'admin') {
      return const AdminShell();
    } else if (_role == 'manager') {
      return const ManagerDashboardScreen();
    }
    return const TrackmanDashboardScreen();
  }

  Widget _buildPendingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1118),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.severityMedium.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded,
                    size: 56, color: AppColors.severityMedium),
              ),
              const SizedBox(height: 28),
              const Text('Awaiting Approval',
                  style: TextStyle(color: Colors.white, fontSize: 24,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text(
                'Your account has been registered and is pending admin approval. '
                'You will be notified once your access is granted.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1118),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.severityCritical.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block_rounded,
                    size: 56, color: AppColors.severityCritical),
              ),
              const SizedBox(height: 28),
              const Text('Access Denied',
                  style: TextStyle(color: Colors.white, fontSize: 24,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text(
                'Your registration has been reviewed and was not approved. '
                'Please contact your administrator for more information.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String message) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1118),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 56, color: AppColors.severityCritical),
              const SizedBox(height: 20),
              const Text('Something went wrong',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() { _loading = true; _error = null; });
                      _fetchProfile();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    child: const Text('Retry'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.severityCritical,
                      side: const BorderSide(color: AppColors.severityCritical),
                    ),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
