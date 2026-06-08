import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final bool initialSignUp;
  const LoginScreen({super.key, this.initialSignUp = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  late bool _isSignUp;
  String? _error;
  String? _message;
  
  // RBAC Selection
  String _selectedRole = 'Trackman';
  final List<String> _roles = ['Admin', 'Manager', 'Trackman'];

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialSignUp;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      if (_isSignUp) {
        // Sign Up Flow
        final response = await Supabase.instance.client.auth.signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          data: {'full_name': _emailCtrl.text.trim().split('@')[0]},
        );
        
        if (mounted) {
          setState(() {
            _loading = false;
            if (response.session == null) {
              _message = 'Check your email to confirm your account.';
            } else {
              _message = 'Account created successfully!';
              // Successfully signed up and session created
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
        }
      } else {
        // Sign In Flow
        final authResponse = await Supabase.instance.client.auth.signInWithPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        
        // Validate role from backend (app_users table)
        final user = authResponse.user;
        if (user != null) {
          final profile = await Supabase.instance.client
              .from('app_users')
              .select('role')
              .eq('id', user.id)
              .maybeSingle();

          if (profile != null) {
            final dbRole = (profile['role'] as String?)?.toLowerCase() ?? 'trackman';
            final selectedRoleLower = _selectedRole.toLowerCase();

            // Check if the assigned database role matches the selected toggle
            if (dbRole != selectedRoleLower) {
              await Supabase.instance.client.auth.signOut();
              throw Exception('Access Denied: You do not have $_selectedRole privileges. (Registered as: ${dbRole.toUpperCase()})');
            }
            
            // Login successful and role validated
            if (mounted) {
              setState(() => _loading = false);
              // Pop the login screen to reveal the Dashboard which AuthGate builds automatically
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
            
          } else {
            await Supabase.instance.client.auth.signOut();
            throw Exception('Access Denied: No user profile found in the database.');
          }
        }
      }
      
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 40),
              _buildGlassmorphicFormCard(),
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
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8)
              ),
            ],
          ),
          child: const Icon(Icons.electric_scooter, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 20),
        Text(_isSignUp ? 'Create Account' : 'Welcome Back',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 8),
        Text(_isSignUp ? 'Register for fleet access' : 'Sign in to manage your fleet',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            )),
      ],
    );
  }

  Widget _buildGlassmorphicFormCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isSignUp) _buildRoleSelector(),
                if (!_isSignUp) const SizedBox(height: 30),
                
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.severityCritical.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.severityCritical.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: Colors.white))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_message != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.statusActive.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.statusActive.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.lightGreenAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_message!, style: const TextStyle(fontSize: 13, color: Colors.white))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                _buildTextField(
                  controller: _emailCtrl,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  isEmail: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _passwordCtrl,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isSignUp ? 'Sign Up' : 'Sign In as $_selectedRole', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _error = null;
                        _message = null;
                      });
                    },
                    child: Text(
                      _isSignUp ? 'Already have an account? Sign In' : 'Don\'t have an account? Sign Up',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: _roles.map((role) {
          final isSelected = _selectedRole == role;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedRole = role;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  role,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isEmail = false,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.white60, size: 20),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return '$label is required';
        if (isEmail && !v.contains('@')) return 'Enter a valid email';
        if (isPassword && _isSignUp && v.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
    );
  }
}
