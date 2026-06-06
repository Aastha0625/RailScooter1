import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _isSignUp = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      if (_isSignUp) {
        final response = await Supabase.instance.client.auth.signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        // DB trigger (handle_new_auth_user) is the primary mechanism.
        // _ensureUserProfile is a session-aware fallback for when email
        // confirmation is disabled and a session is immediately available.
        if (response.user != null) {
          await _ensureUserProfile(response.user!.id, _emailCtrl.text.trim());
        }
      } else {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        // Backfill profile for users created before the DB trigger was applied.
        if (response.user != null) {
          await _ensureUserProfile(response.user!.id, _emailCtrl.text.trim());
        }
      }
    } on AuthException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Fallback profile insert — only works when there IS an active session
  /// (i.e. email confirmation is OFF, or user just confirmed their email).
  ///
  /// Primary mechanism: Postgres trigger on auth.users (SECURITY DEFINER)
  /// which runs server-side and bypasses RLS. See migration:
  ///   supabase/migrations/20260606000000_auto_create_user_profile.sql
  Future<void> _ensureUserProfile(String uid, String email) async {
    // Only attempt if there is an active session — without one, auth.uid()
    // is NULL and the RLS policy (WITH CHECK (auth.uid() = id)) will reject.
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return; // DB trigger will handle it

    try {
      await Supabase.instance.client.from('app_users').upsert(
        {
          'id': uid,
          'full_name': email.split('@').first,
          'role': 'operator',
          'is_active': true,
        },
        onConflict: 'id',      // safe to call multiple times
        ignoreDuplicates: true,
      );
    } catch (_) {
      // Best-effort — the DB trigger is the reliable path
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              _buildHeader(),
              const SizedBox(height: 40),
              _buildFormCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.electric_scooter, color: Colors.white, size: 50),
        ),
        const SizedBox(height: 20),
        const Text('PiScoot', style: TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        )),
        const SizedBox(height: 6),
        Text('The Railway Scooter', style: TextStyle(
          color: AppColors.accent,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        )),
        const SizedBox(height: 4),
        const Text('Fleet Management System', style: TextStyle(
          color: Colors.white54,
          fontSize: 12,
        )),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isSignUp ? 'Create Account' : 'Welcome Back',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 4),
            Text(
              _isSignUp ? 'Register for fleet access' : 'Sign in to manage your fleet',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 24),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.severityCritical.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.severityCritical.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.severityCritical, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.severityCritical))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined, size: 20),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline, size: 20),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (_isSignUp && v.length < 6) return 'Minimum 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isSignUp ? 'Create Account' : 'Sign In', style: const TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(height: 16),

            Center(
              child: TextButton(
                onPressed: () => setState(() { _isSignUp = !_isSignUp; _error = null; }),
                child: Text(
                  _isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Sign Up",
                  style: const TextStyle(color: AppColors.primary, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
