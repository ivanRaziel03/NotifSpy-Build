import 'package:flutter/material.dart';
import 'package:notifspy/models/captured_notification.dart';
import 'package:notifspy/services/notification_listener_service.dart';
import 'package:notifspy/screens/contact_thread_screen.dart';
import 'package:notifspy/widgets/empty_state.dart';
import 'package:notifspy/theme/app_theme.dart';
import 'package:intl/intl.dart';

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

  Map<String, List<CapturedNotification>> get _grouped {
    var all = _service.getByApp(widget.packageName);
    if (_deletedOnly) all = all.where((n) => n.isRemoved).toList();

    final groups = <String, List<CapturedNotification>>{};
    for (final n in all) {
      final key = n.title.isNotEmpty ? n.title : '(No title)';
      groups.putIfAbsent(key, () => []).add(n);
    }

    return Map.fromEntries(
      groups.entries.toList()
        ..sort((a, b) {
          final aTime = a.value.first.timestamp;
          final bTime = b.value.first.timestamp;
          return bTime.compareTo(aTime);
        }),
    );
  }

  Color get _appColor {
    final pkg = widget.packageName;
    if (pkg.contains('whatsapp')) return AppTheme.whatsAppGreen;
    if (pkg.contains('telegram')) return AppTheme.telegramBlue;
    if (pkg.contains('instagram')) return const Color(0xFFE1306C);
    if (pkg.contains('twitter') || pkg.contains('x.android')) return const Color(0xFF1DA1F2);
    return AppTheme.spyPurple;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final groups = _grouped;
    final totalMessages = groups.values.fold<int>(0, (sum, list) => sum + list.length);
    final totalDeleted = groups.values.fold<int>(
      0, (sum, list) => sum + list.where((n) => n.isRemoved).length,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appName),
        actions: [
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
          // App stats header
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _appColor.withValues(alpha: 0.15),
                  _appColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _appColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.person, size: 18, color: _appColor),
                const SizedBox(width: 6),
                Text('${groups.length}', style: TextStyle(fontWeight: FontWeight.bold, color: _appColor)),
                Text(' contacts', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const Spacer(),
                Icon(Icons.message, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('$totalMessages', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface)),
                if (totalDeleted > 0) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.delete_sweep, size: 18, color: AppTheme.deletedRed),
                  const SizedBox(width: 4),
                  Text('$totalDeleted', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.deletedRed)),
                ],
              ],
            ),
          ),

          // Grouped contact list
          Expanded(
            child: groups.isEmpty
                ? const EmptyState(
                    icon: Icons.notifications_off,
                    title: 'No notifications',
                    subtitle: 'Nothing to show with current filters',
                  )
                : ListView.builder(
                    itemCount: groups.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (context, index) {
                      final contact = groups.keys.elementAt(index);
                      final messages = groups[contact]!;
                      final deletedInThread = messages.where((n) => n.isRemoved).length;
                      final lastMessage = messages.first;

                      return _ContactCard(
                        contact: contact,
                        lastMessage: lastMessage,
                        messageCount: messages.length,
                        deletedCount: deletedInThread,
                        appColor: _appColor,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContactThreadScreen(
                                contact: contact,
                                packageName: widget.packageName,
                                appName: widget.appName,
                              ),
                            ),
                          );
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
}

class _ContactCard extends StatelessWidget {
  final String contact;
  final CapturedNotification lastMessage;
  final int messageCount;
  final int deletedCount;
  final Color appColor;
  final VoidCallback onTap;

  const _ContactCard({
    required this.contact,
    required this.lastMessage,
    required this.messageCount,
    required this.deletedCount,
    required this.appColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDeleted = deletedCount > 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Contact avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: appColor.withValues(alpha: 0.12),
                child: Text(
                  contact.isNotEmpty ? contact[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: appColor),
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contact,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(lastMessage.timestamp),
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMessage.text,
                      style: TextStyle(
                        fontSize: 13,
                        color: lastMessage.isRemoved
                            ? AppTheme.deletedRed.withValues(alpha: 0.7)
                            : cs.onSurfaceVariant,
                        fontStyle: lastMessage.isRemoved ? FontStyle.italic : null,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: appColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$messageCount messages',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: appColor),
                          ),
                        ),
                        if (hasDeleted) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.deletedRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.delete_forever, size: 10, color: AppTheme.deletedRed),
                                const SizedBox(width: 2),
                                Text(
                                  '$deletedCount deleted',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.deletedRed),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant.withValues(alpha: 0.4), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return DateFormat('HH:mm').format(dt);
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('d MMM').format(dt);
  }
}
