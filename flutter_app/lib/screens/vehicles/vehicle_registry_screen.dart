import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/vehicle.dart';
import '../../services/api_service.dart';
import 'vehicle_registration_screen.dart';
import 'vehicle_details_sheet.dart';

class VehicleRegistryScreen extends StatefulWidget {
  const VehicleRegistryScreen({super.key});

  @override
  State<VehicleRegistryScreen> createState() => _VehicleRegistryScreenState();
}

class _VehicleRegistryScreenState extends State<VehicleRegistryScreen> {
  List<Vehicle> _vehicles = [];
  List<Vehicle> _filtered = [];
  bool _loading = true;
  String _statusFilter = '';
  String _variantFilter = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final vehicles = await ApiService.fetchVehicles();
      if (mounted) {
        setState(() {
          _vehicles = vehicles;
          _loading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _vehicles.where((v) {
        final matchStatus = _statusFilter.isEmpty || v.status == _statusFilter;
        final matchVariant = _variantFilter.isEmpty || v.variant.contains(_variantFilter);
        final matchSearch = q.isEmpty ||
            v.vehicleId.toLowerCase().contains(q) ||
            v.variant.toLowerCase().contains(q) ||
            (v.departmentName?.toLowerCase().contains(q) ?? false) ||
            (v.assignedUserName?.toLowerCase().contains(q) ?? false);
        return matchStatus && matchVariant && matchSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Registry'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _pisolveTag(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.accent,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) => _VehicleListItem(
                            vehicle: _filtered[i],
                            onView: () => _showDetails(_filtered[i]),
                            onEdit: () => _openEdit(_filtered[i]),
                            onDelete: () => _confirmDelete(_filtered[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vehicle Registry', style: AppTextStyles.heading2),
                Text(
                  '${_filtered.length} vehicle${_filtered.length != 1 ? 's' : ''} found',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _openAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Search vehicle ID, user, department...',
              prefixIcon: Icon(Icons.search, color: AppColors.textLight, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _filterDropdown(
                hint: 'All Status',
                value: _statusFilter.isEmpty ? null : _statusFilter,
                items: const ['active', 'idle', 'maintenance', 'offline'],
                onChanged: (v) { setState(() => _statusFilter = v ?? ''); _applyFilters(); },
              )),
              const SizedBox(width: 10),
              Expanded(child: _filterDropdown(
                hint: 'All Variants',
                value: _variantFilter.isEmpty ? null : _variantFilter,
                items: const ['PiScoot', 'PiScoot-Bolt', 'PiScoot-Aegis'],
                onChanged: (v) { setState(() => _variantFilter = v ?? ''); _applyFilters(); },
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          items: [
            DropdownMenuItem(value: null, child: Text('All', style: TextStyle(fontSize: 13))),
            ...items.map((s) => DropdownMenuItem(
              value: s,
              child: Text(s, style: const TextStyle(fontSize: 13)),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.electric_scooter_outlined, size: 64, color: AppColors.textLight),
          SizedBox(height: 16),
          Text('No vehicles found', style: AppTextStyles.heading3),
          Text('Try adjusting filters or add a new vehicle', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  void _showDetails(Vehicle v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VehicleDetailsSheet(vehicle: v),
    );
  }

  void _openAdd() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VehicleRegistrationScreen()),
    );
    if (result == true) _load();
  }

  void _openEdit(Vehicle v) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VehicleRegistrationScreen(vehicle: v)),
    );
    if (result == true) _load();
  }

  Future<void> _confirmDelete(Vehicle v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text('Remove ${v.vehicleId} from the registry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.severityCritical),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ApiService.deleteVehicle(v.id);
      _load();
    }
  }

  Widget _pisolveTag() => Row(
    children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
        child: const Center(child: Text('PS', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
      ),
      const SizedBox(width: 4),
      const Text('PiSolve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ],
  );
}

class _VehicleListItem extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VehicleListItem({
    required this.vehicle,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(vehicle.vehicleId, style: AppTextStyles.heading3.copyWith(fontSize: 15)),
                const SizedBox(width: 8),
                _StatusDot(status: vehicle.status),
                const Spacer(),
                _IconAction(icon: Icons.visibility_outlined, onTap: onView),
                const SizedBox(width: 8),
                _IconAction(icon: Icons.edit_outlined, onTap: onEdit),
                const SizedBox(width: 8),
                _IconAction(icon: Icons.delete_outline, onTap: onDelete, color: AppColors.severityCritical),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${vehicle.variant} \u2022 ${vehicle.batteryType}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            Text(vehicle.batteryCapacity, style: AppTextStyles.caption),
            if (vehicle.departmentName != null || vehicle.assignedUserName != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              if (vehicle.departmentName != null)
                _InfoRow(icon: Icons.business_outlined, text: vehicle.departmentName!),
              if (vehicle.assignedUserName != null)
                _InfoRow(icon: Icons.person_outline, text: vehicle.assignedUserName!),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (vehicle.gpsEnabled) _FeatureTag(label: 'GPS', icon: Icons.gps_fixed, color: AppColors.statusActive),
                if (vehicle.gpsEnabled) const SizedBox(width: 8),
                if (vehicle.trackmanEnabled) _FeatureTag(label: 'Trackman', icon: Icons.shield_outlined, color: AppColors.primary),
                const Spacer(),
                Text(vehicle.firmwareVersion, style: AppTextStyles.caption.copyWith(color: AppColors.textLight)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  Color get _color {
    switch (status) {
      case 'active': return AppColors.statusActive;
      case 'idle': return AppColors.statusIdle;
      case 'maintenance': return AppColors.statusMaintenance;
      default: return AppColors.statusOffline;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 8, height: 8,
    decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
  );
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _IconAction({required this.icon, required this.onTap, this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Icon(icon, size: 20, color: color),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textLight),
        const SizedBox(width: 4),
        Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
      ],
    ),
  );
}

class _FeatureTag extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _FeatureTag({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    ],
  );
}
