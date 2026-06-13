import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class TrackmanProfileScreen extends StatelessWidget {
  const TrackmanProfileScreen({super.key});

  Future<Map<String, dynamic>> _fetchUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final data = await Supabase.instance.client
        .from('app_users')
        .select('''
          *,
          departments(name)
        ''')
        .eq('id', user.id)
        .single();

    return data;
  }

  Widget _buildInfoTile(
    IconData icon,
    String title,
    String value,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppColors.primary,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchUserProfile(),

        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading profile:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final user = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),

            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),

              child: Column(
                children: [

                  const SizedBox(height: 25),

                  CircleAvatar(
                    radius: 45,
                    backgroundColor: AppColors.primary,
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 15),

                  Text(
                    user['full_name'],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  _buildInfoTile(
                    Icons.badge,
                    'Employee ID',
                    user['employee_id'] ?? 'Not Assigned',
                  ),

                  _buildInfoTile(
                    Icons.apartment,
                    'Department',
                    user['departments']?['name'] ?? 'Not Assigned',
                  ),

                  _buildInfoTile(
                    Icons.phone,
                    'Phone',
                    user['phone'],
                  ),

                  _buildInfoTile(
                    Icons.work,
                    'Role',
                    user['role'].toString().toUpperCase(),
                  ),

                  _buildInfoTile(
                    Icons.verified_user,
                    'Account Status',
                    user['is_active']
                        ? 'Active'
                        : 'Inactive',
                  ),

                  _buildInfoTile(
                    Icons.check_circle,
                    'Approval',
                    user['approval_status'],
                  ),

                  const Divider(),

                  _buildInfoTile(
                    Icons.schedule,
                    'Shift',
                    'Morning Shift (08:00 AM - 04:00 PM)',
                  ),

                  _buildInfoTile(
                    Icons.circle,
                    'Shift Status',
                    '🟢 ON DUTY',
                  ),

                  const SizedBox(height: 15),

                ],
              ),
            ),
          );
        },
      ),
    );
  }
}