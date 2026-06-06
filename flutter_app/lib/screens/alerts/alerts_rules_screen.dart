import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/alert_rule.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class AlertsRulesScreen extends StatefulWidget {
  const AlertsRulesScreen({super.key});

  @override
  State<AlertsRulesScreen> createState() => _AlertsRulesScreenState();
}

class _AlertsRulesScreenState extends State<AlertsRulesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<AlertRule> _rules = [];
  List<VehicleAlert> _events = [];
  bool _loading = true;

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
        ApiService.fetchAlertRules(),
        ApiService.fetchAlertEvents(),
      ]);
      if (mounted) {
        setState(() {
          _rules = results[0] as List<AlertRule>;
          _events = results[1] as List<VehicleAlert>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unackCount = _events.where((e) => !e.isAcknowledged).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts & Rules'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            const Tab(text: 'Rules'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Events'),
                  if (unackCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.severityCritical,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$unackCount', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _tabs.index == 0 ? _showAddRule() : null,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : TabBarView(
              controller: _tabs,
              children: [
                _buildRulesList(),
                _buildEventsList(),
              ],
            ),
    );
  }

  Widget _buildRulesList() {
    if (_rules.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rule_outlined, size: 56, color: AppColors.textLight),
            SizedBox(height: 12),
            Text('No rules configured', style: AppTextStyles.heading3),
            Text('Tap + to add a rule', style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rules.length,
        itemBuilder: (_, i) => _RuleCard(
          rule: _rules[i],
          onEdit: () => _showEditRule(_rules[i]),
          onDelete: () => _deleteRule(_rules[i]),
          onToggle: (v) => _toggleRule(_rules[i], v),
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    if (_events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 56, color: AppColors.textLight),
            SizedBox(height: 12),
            Text('No alert events', style: AppTextStyles.heading3),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        itemBuilder: (_, i) => _AlertEventCard(
          alert: _events[i],
          onAcknowledge: _events[i].isAcknowledged ? null : () => _acknowledge(_events[i].id),
        ),
      ),
    );
  }

  void _showAddRule() => _showRuleForm(null);
  void _showEditRule(AlertRule rule) => _showRuleForm(rule);

  void _showRuleForm(AlertRule? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final valueCtrl = TextEditingController(text: existing?.conditionValue.toString() ?? '');
    final unitCtrl = TextEditingController(text: existing?.conditionUnit ?? '');
    String ruleType = existing?.ruleType ?? 'speed';
    String severity = existing?.severity ?? 'medium';
    String operator_ = existing?.conditionOperator ?? 'gt';
    bool emailNotif = existing?.notificationEmail ?? true;
    bool pushNotif = existing?.notificationPush ?? true;
    bool smsNotif = existing?.notificationSms ?? false;
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
                  Text(existing == null ? 'Add Alert Rule' : 'Edit Rule', style: AppTextStyles.heading2),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Rule Name *'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _enumDropdown('Rule Type', ruleType,
                        ['speed', 'battery', 'geofence', 'idle_time', 'movement'],
                        (v) => setModal(() => ruleType = v!))),
                      const SizedBox(width: 8),
                      Expanded(child: _enumDropdown('Severity', severity,
                        ['low', 'medium', 'high', 'critical'],
                        (v) => setModal(() => severity = v!))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _enumDropdown('Operator', operator_,
                        ['gt', 'lt', 'eq', 'gte', 'lte'],
                        (v) => setModal(() => operator_ = v!))),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(
                        controller: valueCtrl,
                        decoration: const InputDecoration(labelText: 'Value *'),
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(labelText: 'Unit'),
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Notifications', style: AppTextStyles.label),
                  _notifToggle('Email', emailNotif, (v) => setModal(() => emailNotif = v)),
                  _notifToggle('Push', pushNotif, (v) => setModal(() => pushNotif = v)),
                  _notifToggle('SMS', smsNotif, (v) => setModal(() => smsNotif = v)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final data = {
                          'name': nameCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                          'rule_type': ruleType,
                          'severity': severity,
                          'condition_operator': operator_,
                          'condition_value': double.tryParse(valueCtrl.text) ?? 0,
                          'condition_unit': unitCtrl.text.trim(),
                          'notification_email': emailNotif,
                          'notification_push': pushNotif,
                          'notification_sms': smsNotif,
                        };
                        if (existing == null) {
                          await ApiService.createAlertRule(data);
                        } else {
                          await ApiService.updateAlertRule(existing.id, data);
                        }
                        if (mounted) { Navigator.pop(context); _load(); }
                      },
                      child: Text(existing == null ? 'Add Rule' : 'Save Changes'),
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

  Future<void> _toggleRule(AlertRule rule, bool value) async {
    await ApiService.updateAlertRule(rule.id, {'is_active': value});
    _load();
  }

  Future<void> _deleteRule(AlertRule rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Rule'),
        content: Text('Delete "${rule.name}"?'),
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
    if (ok == true) { await ApiService.deleteAlertRule(rule.id); _load(); }
  }

  Future<void> _acknowledge(String id) async {
    await ApiService.acknowledgeAlert(id);
    _load();
  }

  Widget _enumDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );

  Widget _notifToggle(String label, bool value, ValueChanged<bool> onChanged) => Row(
    children: [
      Expanded(child: Text(label, style: AppTextStyles.body)),
      Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.accent, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
    ],
  );
}

class _RuleCard extends StatelessWidget {
  final AlertRule rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _RuleCard({required this.rule, required this.onEdit, required this.onDelete, required this.onToggle});

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
            _SeverityDot(severity: rule.severity),
            const SizedBox(width: 8),
            Expanded(child: Text(rule.name, style: AppTextStyles.heading3)),
            Switch(
              value: rule.isActive,
              onChanged: onToggle,
              activeThumbColor: AppColors.accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        if (rule.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(rule.description, style: AppTextStyles.bodySmall),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            _Tag(label: rule.ruleType, color: AppColors.primary),
            const SizedBox(width: 6),
            _Tag(label: '${rule.conditionOperator} ${rule.conditionValue} ${rule.conditionUnit}', color: AppColors.textSecondary),
            const Spacer(),
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.severityCritical), onPressed: onDelete, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ],
        ),
        if (rule.notificationEmail || rule.notificationPush || rule.notificationSms) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              if (rule.notificationEmail) _NotifIcon(icon: Icons.email_outlined),
              if (rule.notificationPush) _NotifIcon(icon: Icons.notifications_outlined),
              if (rule.notificationSms) _NotifIcon(icon: Icons.sms_outlined),
            ],
          ),
        ],
      ],
    ),
  );
}

class _AlertEventCard extends StatelessWidget {
  final VehicleAlert alert;
  final VoidCallback? onAcknowledge;

  const _AlertEventCard({required this.alert, this.onAcknowledge});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: alert.isAcknowledged ? Colors.white : _severityColor(alert.severity).withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: alert.isAcknowledged ? AppColors.cardBorder : _severityColor(alert.severity).withValues(alpha: 0.3),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _severityColor(alert.severity).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.warning_amber_outlined, color: _severityColor(alert.severity), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(alert.vehicleLabel, style: AppTextStyles.heading3.copyWith(fontSize: 14)),
                  const SizedBox(width: 6),
                  _SeverityDot(severity: alert.severity),
                ],
              ),
              Text(alert.message.isNotEmpty ? alert.message : alert.alertType,
                  style: AppTextStyles.bodySmall),
              const SizedBox(height: 2),
              Text(DateFormat('MMM d, HH:mm').format(alert.createdAt.toLocal()),
                  style: AppTextStyles.caption),
            ],
          ),
        ),
        if (!alert.isAcknowledged && onAcknowledge != null)
          TextButton(
            onPressed: onAcknowledge,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Ack', style: TextStyle(fontSize: 12)),
          )
        else if (alert.isAcknowledged)
          const Icon(Icons.check_circle_outline, color: AppColors.statusActive, size: 18),
      ],
    ),
  );

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical': return AppColors.severityCritical;
      case 'high': return AppColors.severityHigh;
      case 'medium': return AppColors.severityMedium;
      default: return AppColors.severityLow;
    }
  }
}

class _SeverityDot extends StatelessWidget {
  final String severity;
  const _SeverityDot({required this.severity});

  Color get _color {
    switch (severity) {
      case 'critical': return AppColors.severityCritical;
      case 'high': return AppColors.severityHigh;
      case 'medium': return AppColors.severityMedium;
      default: return AppColors.severityLow;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 8, height: 8,
    decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
  );
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
  );
}

class _NotifIcon extends StatelessWidget {
  final IconData icon;
  const _NotifIcon({required this.icon});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Icon(icon, size: 14, color: AppColors.textSecondary),
  );
}
