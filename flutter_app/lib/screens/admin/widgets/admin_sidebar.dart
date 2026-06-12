import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class AdminNavItem {
  final IconData icon;
  final String label;
  final bool hasBadge;
  const AdminNavItem({required this.icon, required this.label, this.hasBadge = false});
}

class AdminSidebar extends StatefulWidget {
  final List<AdminNavItem> navItems;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const AdminSidebar({
    super.key,
    required this.navItems,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  int? _hoveredIndex;
  String _adminName = 'Admin';

  @override
  void initState() {
    super.initState();
    _loadAdminName();
  }

  Future<void> _loadAdminName() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final data = await Supabase.instance.client
        .from('app_users')
        .select('full_name')
        .eq('id', uid)
        .maybeSingle();
    if (mounted && data != null) {
      setState(() => _adminName = data['full_name'] ?? 'Admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(4, 0)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo & Title ──
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              left: 20,
              right: 20,
              bottom: 24,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PiScoot',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('Admin Panel',
                        style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Nav Items ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.navItems.length,
              itemBuilder: (_, i) => _buildNavItem(i),
            ),
          ),

          // ── Admin User Footer ──
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.accent,
                  child: Text(
                    _adminName.isNotEmpty ? _adminName[0].toUpperCase() : 'A',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _adminName,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text('Administrator',
                          style: TextStyle(color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await Supabase.instance.client.auth.signOut();
                  },
                  child: const Icon(Icons.logout_rounded, color: Colors.white54, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = widget.navItems[index];
    final isSelected = index == widget.selectedIndex;
    final isHovered = _hoveredIndex == index;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTap: () => widget.onItemSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.18)
                : isHovered
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? const Border(left: BorderSide(color: AppColors.accent, width: 3))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 20,
                color: isSelected ? AppColors.accent : Colors.white70,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected ? AppColors.accent : Colors.white70,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
