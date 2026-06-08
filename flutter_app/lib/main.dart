import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
      url: 'https://efyhhqeshzvhjbjrbkza.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVmeWhocWVzaHp2aGpianJia3phIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3MjQyMTgsImV4cCI6MjA5NjMwMDIxOH0.KqP28xGn46TqocKypRbpj_-9AwD4NWd7N65fC1pZNK4');

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
    if (session != null) return const DashboardScreen();
    return const WelcomeScreen();
  }
}
