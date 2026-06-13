import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class TrackmanNotificationsScreen extends StatefulWidget {
  const TrackmanNotificationsScreen({super.key});

  @override
  State<TrackmanNotificationsScreen> createState() =>
      _TrackmanNotificationsScreenState();
}

class _TrackmanNotificationsScreenState
    extends State<TrackmanNotificationsScreen> {
  List<Map<String, dynamic>> notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final client = Supabase.instance.client;

      // Fetch broadcast messages
      final broadcasts = await client
          .from('broadcast_messages')
          .select()
          .or('target_role.eq.trackman,target_role.eq.all')
          .order('created_at', ascending: false);

      // Fetch active vehicle alerts
      final alerts = await client
          .from('vehicle_alerts')
          .select()
          .eq('is_acknowledged', false)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> allNotifications = [];

      // Convert broadcasts
      for (final item in broadcasts) {
        allNotifications.add({
          'title': item['title'],
          'message': item['body'],
          'time': item['created_at'],
          'type': 'broadcast',
        });
      }

      // Convert alerts
      for (final item in alerts) {
        allNotifications.add({
          'title':
              '${item['alert_type'].toString().toUpperCase()} Alert',
          'message': item['message'],
          'time': item['created_at'],
          'type': 'alert',
          'severity': item['severity'],
        });
      }

      // Sort newest first
      allNotifications.sort(
        (a, b) =>
            DateTime.parse(b['time'])
                .compareTo(DateTime.parse(a['time'])),
      );

      setState(() {
        notifications = allNotifications;
        loading = false;
      });
    } catch (e) {
      debugPrint('Notification Error: $e');

      setState(() {
        loading = false;
      });
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'broadcast':
        return Icons.campaign;

      case 'alert':
        return Icons.warning_amber_rounded;

      default:
        return Icons.notifications;
    }
  }

  Color _getColor(Map<String, dynamic> notification) {
    if (notification['type'] == 'alert') {
      switch (notification['severity']) {
        case 'critical':
          return Colors.red;

        case 'high':
          return Colors.orange;

        case 'medium':
          return Colors.amber;

        default:
          return Colors.green;
      }
    }

    return AppColors.primary;
  }

  String _formatTime(String time) {
    final date = DateTime.parse(time);
    final difference = DateTime.now().difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hrs ago';
    }

    return '${difference.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 60,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No notifications available',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,

                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final color = _getColor(notification);

                      return Container(
                        margin:
                            const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),

                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.cardBorder,
                          ),
                        ),

                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  color.withValues(alpha: 0.15),

                              child: Icon(
                                _getIcon(notification['type']),
                                color: color,
                              ),
                            ),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,

                                children: [
                                  Text(
                                    notification['title'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.bold,
                                      color:
                                          AppColors.textPrimary,
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  Text(
                                    notification['message'],
                                    style: const TextStyle(
                                      color:
                                          AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  Text(
                                    _formatTime(
                                      notification['time'],
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}