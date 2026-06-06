import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/vehicle.dart';

class VehicleDetailsSheet extends StatelessWidget {
  final Vehicle vehicle;
  const VehicleDetailsSheet({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Vehicle Details', style: AppTextStyles.heading2),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                            ),
                            child: const Icon(Icons.directions_car, color: Colors.white, size: 36),
                          ),
                          const SizedBox(height: 12),
                          Text(vehicle.vehicleId, style: AppTextStyles.heading2),
                          const SizedBox(height: 6),
                          _StatusBadge(status: vehicle.status),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _detailRow('Variant', vehicle.variant),
                    _detailRow('Battery', vehicle.batteryType),
                    _detailRow('Capacity', vehicle.batteryCapacity),
                    if (vehicle.manufacturingDate != null)
                      _detailRow('Manufacturing', DateFormat('M/d/yyyy').format(vehicle.manufacturingDate!)),
                    _detailRow('Firmware', vehicle.firmwareVersion),
                    if (vehicle.lastMaintenanceDate != null)
                      _detailRow('Last Maintenance', DateFormat('M/d/yyyy').format(vehicle.lastMaintenanceDate!)),

                    if (vehicle.departmentName != null || vehicle.assignedUserName != null) ...[
                      const SizedBox(height: 20),
                      const Text('Assignment Details', style: AppTextStyles.heading3),
                      const SizedBox(height: 12),
                      if (vehicle.departmentName != null)
                        _detailRow('Department', vehicle.departmentName!),
                      if (vehicle.assignedUserName != null)
                        _detailRow('Assigned User', vehicle.assignedUserName!),
                    ],

                    const SizedBox(height: 20),
                    const Text('Features', style: AppTextStyles.heading3),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _FeatureCard(
                          icon: Icons.gps_fixed,
                          label: 'GPS Tracking',
                          enabled: vehicle.gpsEnabled,
                          color: AppColors.statusActive,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _FeatureCard(
                          icon: Icons.shield_outlined,
                          label: 'Trackman Safety',
                          enabled: vehicle.trackmanSafetyEnabled,
                          color: AppColors.statusIdle,
                        )),
                      ],
                    ),
                    if (vehicle.notes.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Notes', style: AppTextStyles.heading3),
                      const SizedBox(height: 8),
                      Text(vehicle.notes, style: AppTextStyles.body),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        SizedBox(width: 120, child: Text(label + ':', style: AppTextStyles.label)),
        Expanded(child: Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500))),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case 'active': return AppColors.statusActive;
      case 'idle': return AppColors.statusIdle;
      case 'maintenance': return AppColors.statusMaintenance;
      default: return AppColors.statusOffline;
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(status[0].toUpperCase() + status.substring(1),
          style: TextStyle(fontSize: 13, color: _color, fontWeight: FontWeight.w500)),
    ],
  );
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final Color color;

  const _FeatureCard({required this.icon, required this.label, required this.enabled, required this.color});

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? color.withValues(alpha: 0.08) : AppColors.background;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: enabled ? color.withValues(alpha: 0.3) : AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: enabled ? color : AppColors.textLight, size: 24),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: enabled ? color : AppColors.textLight)),
          Text(enabled ? 'Enabled' : 'Disabled',
              style: TextStyle(fontSize: 10, color: enabled ? color : AppColors.textLight)),
        ],
      ),
    );
  }
}
