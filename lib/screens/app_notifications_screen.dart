import 'package:flutter/material.dart';
import 'package:notifspy/models/captured_notification.dart';
import 'package:notifspy/services/notification_listener_service.dart';
import 'package:notifspy/screens/notification_detail_screen.dart';
import 'package:notifspy/widgets/notification_tile.dart';
import 'package:notifspy/widgets/empty_state.dart';
import 'package:notifspy/theme/app_theme.dart';

class AppNotificationsScreen extends StatefulWidget {
  final String packageName;
  final String appName;

  const AppNotificationsScreen({super.key, required this.packageName, required this.appName});

  @override
  State<AppNotificationsScreen> createState() => _AppNotificationsScreenState();
}

class _AppNotificationsScreenState extends State<AppNotificationsScreen> {
  final _service = NotificationListenerService();
  bool _deletedOnly = false;
  String _contactFilter = '';

  List<CapturedNotification> get _filtered {
    var list = _service.getByApp(widget.packageName);
    if (_deletedOnly) list = list.where((n) => n.isRemoved).toList();
    if (_contactFilter.isNotEmpty) {
      final q = _contactFilter.toLowerCase();
      list = list.where((n) => n.title.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  List<String> get _contacts {
    final titles = <String>{};
    for (final n in _service.getByApp(widget.packageName)) {
      if (n.title.isNotEmpty) titles.add(n.title);
    }
    return titles.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _filtered;
    final contacts = _contacts;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appName),
        actions: [
          if (contacts.length > 1)
            IconButton(
              icon: const Icon(Icons.person_search),
              tooltip: 'Filter by contact',
              onPressed: () => _showContactPicker(contacts),
            ),
          IconButton(
            icon: Icon(_deletedOnly ? Icons.delete : Icons.delete_outline),
            tooltip: _deletedOnly ? 'Show all' : 'Deleted only',
            color: _deletedOnly ? AppTheme.deletedRed : null,
            onPressed: () => setState(() => _deletedOnly = !_deletedOnly),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_contactFilter.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Chip(
                avatar: const Icon(Icons.person, size: 16),
                label: Text(_contactFilter),
                onDeleted: () => setState(() => _contactFilter = ''),
              ),
            ),
          Expanded(
            child: notifications.isEmpty
                ? const EmptyState(
                    icon: Icons.notifications_off,
                    title: 'No notifications',
                    subtitle: 'Nothing to show with current filters',
                  )
                : ListView.builder(
                    itemCount: notifications.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      return NotificationTile(
                        notification: notif,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => NotificationDetailScreen(notification: notif)),
                        ),
                        onDismiss: () async {
                          await _service.deleteNotification(notif.id);
                          setState(() {});
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showContactPicker(List<String> contacts) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Filter by contact', style: Theme.of(context).textTheme.titleMedium),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: contacts.length,
                itemBuilder: (_, i) {
                  final c = contacts[i];
                  final count = _service.getByApp(widget.packageName).where((n) => n.title == c).length;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      child: Text(c.isNotEmpty ? c[0].toUpperCase() : '?', style: const TextStyle(fontSize: 14)),
                    ),
                    title: Text(c),
                    trailing: Text('$count', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    onTap: () {
                      setState(() => _contactFilter = c);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
