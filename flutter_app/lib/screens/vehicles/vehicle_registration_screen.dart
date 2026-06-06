import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/vehicle.dart';
import '../../services/api_service.dart';

class VehicleRegistrationScreen extends StatefulWidget {
  final Vehicle? vehicle;
  const VehicleRegistrationScreen({super.key, this.vehicle});

  @override
  State<VehicleRegistrationScreen> createState() => _VehicleRegistrationScreenState();
}

class _VehicleRegistrationScreenState extends State<VehicleRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleIdCtrl = TextEditingController();
  final _batteryCapacityCtrl = TextEditingController();
  final _firmwareCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _variant = 'PiScoot';
  String _batteryType = 'LiFe';
  DateTime? _manufacturingDate;
  bool _gpsEnabled = true;
  bool _trackmanEnabled = false;
  bool _trackmanSafetyEnabled = false;
  bool _saving = false;

  final _variants = ['PiScoot', 'PiScoot-Bolt', 'PiScoot-Aegis'];
  final _batteryTypes = ['LiFe', 'LiPo', 'NMC', 'LFP'];

  @override
  void initState() {
    super.initState();
    if (widget.vehicle != null) {
      final v = widget.vehicle!;
      _vehicleIdCtrl.text = v.vehicleId;
      _batteryCapacityCtrl.text = v.batteryCapacity;
      _firmwareCtrl.text = v.firmwareVersion;
      _notesCtrl.text = v.notes;
      _variant = v.variant;
      _batteryType = v.batteryType;
      _manufacturingDate = v.manufacturingDate;
      _gpsEnabled = v.gpsEnabled;
      _trackmanEnabled = v.trackmanEnabled;
      _trackmanSafetyEnabled = v.trackmanSafetyEnabled;
    }
  }

  @override
  void dispose() {
    _vehicleIdCtrl.dispose();
    _batteryCapacityCtrl.dispose();
    _firmwareCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'vehicle_id': _vehicleIdCtrl.text.trim(),
      'variant': _variant,
      'battery_type': _batteryType,
      'battery_capacity': _batteryCapacityCtrl.text.trim(),
      'manufacturing_date': _manufacturingDate?.toIso8601String().split('T').first,
      'firmware_version': _firmwareCtrl.text.trim().isEmpty ? 'v1.0.0' : _firmwareCtrl.text.trim(),
      'gps_enabled': _gpsEnabled,
      'trackman_enabled': _trackmanEnabled,
      'trackman_safety_enabled': _trackmanSafetyEnabled,
      'notes': _notesCtrl.text.trim(),
    };

    try {
      if (widget.vehicle != null) {
        await ApiService.updateVehicle(widget.vehicle!.id, data);
      } else {
        await ApiService.createVehicle(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.severityCritical),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.vehicle != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Vehicle' : 'Vehicle Registration'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.directions_car, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              Text(isEdit ? 'Edit PiScoot Device' : 'Vehicle Registration', style: AppTextStyles.heading2),
              const SizedBox(height: 4),
              const Text('Register new PiScoot devices for deployment', style: AppTextStyles.bodySmall),
              const SizedBox(height: 28),

              _buildLabel('Vehicle ID *'),
              TextFormField(
                controller: _vehicleIdCtrl,
                readOnly: isEdit,
                decoration: const InputDecoration(hintText: 'Enter unique vehicle identifier'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Vehicle ID is required' : null,
              ),
              const SizedBox(height: 16),

              _buildLabel('Date of Manufacturing *'),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _manufacturingDate != null
                              ? DateFormat('dd-MM-yyyy').format(_manufacturingDate!)
                              : 'dd-mm-yyyy',
                          style: TextStyle(
                            fontSize: 14,
                            color: _manufacturingDate != null ? AppColors.textPrimary : AppColors.textLight,
                          ),
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textLight),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildLabel('Variant *'),
              _buildDropdown(
                value: _variant,
                items: _variants,
                hint: 'Select PiScoot variant',
                onChanged: (v) => setState(() => _variant = v!),
              ),
              const SizedBox(height: 16),

              _buildLabel('Battery Type *'),
              _buildDropdown(
                value: _batteryType,
                items: _batteryTypes,
                hint: 'Select battery type',
                onChanged: (v) => setState(() => _batteryType = v!),
              ),
              const SizedBox(height: 16),

              _buildLabel('Battery Capacity'),
              TextFormField(
                controller: _batteryCapacityCtrl,
                decoration: const InputDecoration(hintText: 'e.g., 48V 25Ah'),
              ),
              const SizedBox(height: 16),

              _buildLabel('Firmware Version'),
              TextFormField(
                controller: _firmwareCtrl,
                decoration: const InputDecoration(hintText: 'e.g., v2.1.0'),
              ),
              const SizedBox(height: 16),

              _buildToggleRow(
                'GPS Tracking',
                'Enable GPS location tracking',
                _gpsEnabled,
                (v) => setState(() => _gpsEnabled = v),
              ),
              const SizedBox(height: 8),
              _buildToggleRow(
                'Trackman Integration',
                'Enable Trackman device sync',
                _trackmanEnabled,
                (v) => setState(() => _trackmanEnabled = v),
              ),
              const SizedBox(height: 8),
              _buildToggleRow(
                'Trackman Safety Enabled',
                'Enable safety tracking for trackman operations',
                _trackmanSafetyEnabled,
                (v) => setState(() => _trackmanSafetyEnabled = v),
              ),
              const SizedBox(height: 16),

              _buildLabel('Notes'),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Additional notes...'),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Update Vehicle' : 'Register Vehicle', style: const TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: AppTextStyles.label),
    ),
  );

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(fontSize: 14, color: AppColors.textLight)),
          icon: const Icon(Icons.keyboard_arrow_down),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildToggleRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accent,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _manufacturingDate ?? DateTime(2024, 1, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary, secondary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _manufacturingDate = date);
  }
}
