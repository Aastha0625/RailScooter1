import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../models/geofence.dart';
import '../../models/vehicle_location.dart';
import '../../services/api_service.dart';

class GeofenceTrackingScreen extends StatefulWidget {
  const GeofenceTrackingScreen({super.key});

  @override
  State<GeofenceTrackingScreen> createState() => _GeofenceTrackingScreenState();
}

class _GeofenceTrackingScreenState extends State<GeofenceTrackingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Geofence> _geofences = [];
  List<VehicleLocation> _liveLocations = [];
  bool _loading = true;
  final _mapController = MapController();

  static const _defaultCenter = LatLng(28.6139, 77.2090); // New Delhi

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.fetchGeofences(),
        ApiService.fetchLiveTracking(),
      ]);
      if (mounted) {
        setState(() {
          _geofences = results[0] as List<Geofence>;
          _liveLocations = results[1] as List<VehicleLocation>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load tracking data: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: _load),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoFence & Tracking'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Live Map'),
            Tab(text: 'Geofences'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _tabs.index == 1 ? _showAddGeofence() : _load(),
        backgroundColor: AppColors.accent,
        child: Icon(_tabs.index == 1 ? Icons.add : Icons.refresh, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : TabBarView(
              controller: _tabs,
              children: [
                _buildLiveMap(),
                _buildGeofenceList(),
              ],
            ),
    );
  }

  Widget _buildLiveMap() {
    final markers = _liveLocations.map((loc) => Marker(
      point: LatLng(loc.latitude, loc.longitude),
      width: 60,
      height: 60,
      child: _VehicleMarker(location: loc),
    )).toList();

    final circles = _geofences.where((g) => g.isActive).map((g) => CircleMarker(
      point: LatLng(g.centerLat, g.centerLng),
      radius: g.radiusMeters,
      color: _hexToColor(g.colorHex).withValues(alpha: 0.15),
      borderColor: _hexToColor(g.colorHex),
      borderStrokeWidth: 2,
      useRadiusInMeter: true,
    )).toList();

    return Column(
      children: [
        _buildLiveStats(),
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _liveLocations.isNotEmpty
                  ? LatLng(_liveLocations.first.latitude, _liveLocations.first.longitude)
                  : _defaultCenter,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.piscoot.app',
              ),
              CircleLayer(circles: circles),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
        if (_liveLocations.isNotEmpty) _buildVehicleBottomSheet(),
      ],
    );
  }

  Widget _buildLiveStats() {
    final online = _liveLocations.where((l) => l.isOnline).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          _statPill(Icons.circle, '$online Online', AppColors.statusActive),
          const SizedBox(width: 8),
          _statPill(Icons.electric_scooter_outlined, '${_liveLocations.length} Tracked', AppColors.primary),
          const SizedBox(width: 8),
          _statPill(Icons.pentagon_outlined, '${_geofences.length} Zones', AppColors.accent),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _load,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    ],
  );

  Widget _buildVehicleBottomSheet() {
    return Container(
      height: 100,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        itemCount: _liveLocations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final loc = _liveLocations[i];
          return GestureDetector(
            onTap: () => _mapController.move(LatLng(loc.latitude, loc.longitude), 16),
            child: Container(
              width: 130,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: loc.isOnline ? AppColors.statusActive : AppColors.statusOffline,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(loc.vehicleLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${loc.speedKmh.toStringAsFixed(1)} km/h', style: AppTextStyles.caption),
                  Text('Battery: ${loc.batteryPercent}%', style: AppTextStyles.caption),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGeofenceList() {
    if (_geofences.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pentagon_outlined, size: 56, color: AppColors.textLight),
            SizedBox(height: 12),
            Text('No geofences defined', style: AppTextStyles.heading3),
            Text('Tap + to add a geofence zone', style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _geofences.length,
        itemBuilder: (_, i) => _GeofenceCard(
          geofence: _geofences[i],
          onDelete: () => _deleteGeofence(_geofences[i]),
          onViewOnMap: () {
            _tabs.animateTo(0);
            Future.delayed(const Duration(milliseconds: 300), () {
              _mapController.move(
                LatLng(_geofences[i].centerLat, _geofences[i].centerLng), 15);
            });
          },
        ),
      ),
    );
  }

  void _showAddGeofence() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final latCtrl = TextEditingController(text: '28.6139');
    final lngCtrl = TextEditingController(text: '77.2090');
    final radiusCtrl = TextEditingController(text: '500');
    String fenceType = 'operational';
    bool alertOnExit = true;
    bool alertOnEnter = false;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Geofence Zone', style: AppTextStyles.heading2),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Zone Name *'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: fenceType,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'operational', child: Text('Operational')),
                          DropdownMenuItem(value: 'restricted', child: Text('Restricted')),
                          DropdownMenuItem(value: 'depot', child: Text('Depot')),
                        ],
                        onChanged: (v) => setModal(() => fenceType = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(
                        controller: latCtrl,
                        decoration: const InputDecoration(labelText: 'Latitude *'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(
                        controller: lngCtrl,
                        decoration: const InputDecoration(labelText: 'Longitude *'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: radiusCtrl,
                    decoration: const InputDecoration(labelText: 'Radius (meters)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Expanded(child: Text('Alert on Exit', style: AppTextStyles.body)),
                    Switch(value: alertOnExit, onChanged: (v) => setModal(() => alertOnExit = v), activeThumbColor: AppColors.accent),
                  ]),
                  Row(children: [
                    const Expanded(child: Text('Alert on Enter', style: AppTextStyles.body)),
                    Switch(value: alertOnEnter, onChanged: (v) => setModal(() => alertOnEnter = v), activeThumbColor: AppColors.accent),
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        await ApiService.createGeofence({
                          'name': nameCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                          'fence_type': fenceType,
                          'center_lat': double.tryParse(latCtrl.text) ?? 0,
                          'center_lng': double.tryParse(lngCtrl.text) ?? 0,
                          'radius_meters': double.tryParse(radiusCtrl.text) ?? 500,
                          'is_active': true,
                          'alert_on_exit': alertOnExit,
                          'alert_on_enter': alertOnEnter,
                        });
                        if (mounted) { Navigator.pop(context); _load(); }
                      },
                      child: const Text('Add Geofence'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteGeofence(Geofence g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Geofence'),
        content: Text('Remove "${g.name}"?'),
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
    if (ok == true) { await ApiService.deleteGeofence(g.id); _load(); }
  }

  Color _hexToColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}

class _VehicleMarker extends StatelessWidget {
  final VehicleLocation location;
  const _VehicleMarker({required this.location});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: location.isOnline ? AppColors.primary : AppColors.statusOffline,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(location.vehicleLabel,
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
      ),
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: location.isOnline ? AppColors.accent : AppColors.statusOffline,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
        ),
        child: const Icon(Icons.electric_scooter, color: Colors.white, size: 14),
      ),
    ],
  );
}

class _GeofenceCard extends StatelessWidget {
  final Geofence geofence;
  final VoidCallback onDelete;
  final VoidCallback onViewOnMap;

  const _GeofenceCard({required this.geofence, required this.onDelete, required this.onViewOnMap});

  Color get _typeColor {
    switch (geofence.fenceType) {
      case 'restricted': return AppColors.severityCritical;
      case 'depot': return AppColors.statusIdle;
      default: return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(color: _typeColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(geofence.name, style: AppTextStyles.heading3)),
            _TypeBadge(type: geofence.fenceType, color: _typeColor),
          ],
        ),
        if (geofence.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(geofence.description, style: AppTextStyles.bodySmall),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 13, color: AppColors.textLight),
            const SizedBox(width: 4),
            Text('${geofence.centerLat.toStringAsFixed(4)}, ${geofence.centerLng.toStringAsFixed(4)}',
                style: AppTextStyles.caption),
            const SizedBox(width: 8),
            Icon(Icons.radio_button_unchecked, size: 13, color: AppColors.textLight),
            const SizedBox(width: 4),
            Text('${geofence.radiusMeters.round()}m', style: AppTextStyles.caption),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (geofence.alertOnExit) _AlertTag(label: 'Exit Alert'),
            if (geofence.alertOnEnter) ...[
              const SizedBox(width: 6),
              _AlertTag(label: 'Entry Alert'),
            ],
            const Spacer(),
            TextButton.icon(
              onPressed: onViewOnMap,
              icon: const Icon(Icons.map_outlined, size: 14),
              label: const Text('Map', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 28),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.severityCritical),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    ),
  );
}

class _TypeBadge extends StatelessWidget {
  final String type;
  final Color color;
  const _TypeBadge({required this.type, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(type, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
}

class _AlertTag extends StatelessWidget {
  final String label;
  const _AlertTag({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.severityMedium.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: const TextStyle(fontSize: 9, color: AppColors.severityMedium, fontWeight: FontWeight.w600)),
  );
}
