import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/vehicle.dart';
import '../../../services/api_service.dart';

class AdminFleetTab extends StatefulWidget {
  const AdminFleetTab({super.key});

  @override
  State<AdminFleetTab> createState() => _AdminFleetTabState();
}

class _AdminFleetTabState extends State<AdminFleetTab> {
  List<Vehicle> _vehicles = [];
  List<Map<String, dynamic>> _assignments = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.fetchVehicles(),
        ApiService.fetchAssignments(),
      ]);
      if (mounted) {
        setState(() {
          _vehicles    = results[0] as List<Vehicle>;
          _assignments = results[1] as List<Map<String, dynamic>>;
          _loading     = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Vehicle> get _filtered {
    if (_filter == 'all') return _vehicles;
    return _vehicles.where((v) => v.status == _filter).toList();
  }

  Map<String, int> get _counts {
    return {
      'all':         _vehicles.length,
      'active':      _vehicles.where((v) => v.status == 'active').length,
      'idle':        _vehicles.where((v) => v.status == 'idle').length,
      'maintenance': _vehicles.where((v) => v.status == 'maintenance').length,
      'offline':     _vehicles.where((v) => v.status == 'offline').length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTopBar(),
          _buildStatusSummary(),
          _buildFilterChips(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.accent,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 340,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.35,
                          ),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final v = _filtered[i];
                            final assignedUser = _assignments
                                .where((a) => a['vehicle_id'] == v.id && (a['is_active'] ?? false))
                                .map((a) => a['app_users']?['full_name'] as String?)
                                .firstOrNull;
                            return _VehicleCard(
                              vehicle: v,
                              assignedUser: assignedUser,
                              onTap: () => _editVehicle(v),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20, right: 20, bottom: 16,
      ),
      color: AppColors.primary,
      child: Row(
        children: [
          const Icon(Icons.electric_scooter_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fleet Management', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                Text('Rail Scooter Registry', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white70), onPressed: _load),
        ],
      ),
    );
  }

  Widget _buildStatusSummary() {
    final c = _counts;
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          _miniStat('Active',  '${c['active']}',      AppColors.statusActive),
          _miniStat('Idle',    '${c['idle']}',         AppColors.statusIdle),
          _miniStat('Maint.',  '${c['maintenance']}',  AppColors.statusMaintenance),
          _miniStat('Offline', '${c['offline']}',      AppColors.statusOffline),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );

  Widget _buildFilterChips() {
    const filters = [
      ('all', 'All'),
      ('active', 'Active'),
      ('idle', 'Idle'),
      ('maintenance', 'Maintenance'),
      ('offline', 'Offline'),
    ];
    return Container(
      height: 48,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: filters.map((f) {
          final isSelected = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? AppColors.accent : AppColors.cardBorder),
                ),
                child: Text(f.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.electric_scooter_rounded, size: 56, color: AppColors.textLight),
        SizedBox(height: 12),
        Text('No vehicles match filter', style: TextStyle(color: AppColors.textSecondary)),
      ],
    ),
  );

  void _editVehicle(Vehicle v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VehicleEditSheet(vehicle: v, onUpdated: _load),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final String? assignedUser;
  final VoidCallback onTap;

  const _VehicleCard({required this.vehicle, this.assignedUser, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(vehicle.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.electric_scooter_rounded, color: statusColor, size: 22),
                ),
                const Spacer(),
                _StatusBadge(status: vehicle.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(vehicle.vehicleId,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            Text(vehicle.variant,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const Spacer(),
            const Divider(height: 16),
            Row(
              children: [
                const Icon(Icons.battery_charging_full_rounded, size: 12, color: AppColors.textLight),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(vehicle.batteryCapacity,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
              ],
            ),
            if (assignedUser != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person_rounded, size: 12, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(assignedUser!,
                        style: const TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':      return AppColors.statusActive;
      case 'idle':        return AppColors.statusIdle;
      case 'maintenance': return AppColors.statusMaintenance;
      default:            return AppColors.statusOffline;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'active':      color = AppColors.statusActive; break;
      case 'idle':        color = AppColors.statusIdle; break;
      case 'maintenance': color = AppColors.statusMaintenance; break;
      default:            color = AppColors.statusOffline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(status.toUpperCase(), style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// ─── Vehicle Edit Sheet ─────────────────────────────────────────────────────
class _VehicleEditSheet extends StatefulWidget {
  final Vehicle vehicle;
  final VoidCallback onUpdated;

  const _VehicleEditSheet({required this.vehicle, required this.onUpdated});

  @override
  State<_VehicleEditSheet> createState() => _VehicleEditSheetState();
}

class _VehicleEditSheetState extends State<_VehicleEditSheet> {
  late String _status;
  late TextEditingController _notesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status   = widget.vehicle.status;
    _notesCtrl = TextEditingController(text: widget.vehicle.notes);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.updateVehicle(widget.vehicle.id, {
        'status': _status,
        'notes':  _notesCtrl.text.trim(),
      });
      await ApiService.logActivity(
        eventType: 'vehicle_updated',
        description: 'Vehicle ${widget.vehicle.vehicleId} status set to $_status',
      );
      if (mounted) { Navigator.pop(context); widget.onUpdated(); }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.electric_scooter_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text('Edit ${widget.vehicle.vehicleId}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(widget.vehicle.variant, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _status,
                isExpanded: true,
                items: const ['active', 'idle', 'maintenance', 'offline']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase(), style: const TextStyle(fontSize: 14))))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Add any maintenance notes...'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}
