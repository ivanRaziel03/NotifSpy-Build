import 'dart:async';
import 'package:flutter/material.dart';
import 'package:notifspy/models/captured_notification.dart';
import 'package:notifspy/services/notification_listener_service.dart';
import 'package:notifspy/screens/notification_detail_screen.dart';
import 'package:notifspy/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ContactThreadScreen extends StatefulWidget {
  final String contact;
  final String packageName;
  final String appName;

  const ContactThreadScreen({
    super.key,
    required this.contact,
    required this.packageName,
    required this.appName,
  });

  @override
  State<ContactThreadScreen> createState() => _ContactThreadScreenState();
}

class _ContactThreadScreenState extends State<ContactThreadScreen> {
  final _service = NotificationListenerService();
  bool _deletedOnly = false;
  StreamSubscription? _sub;
  StreamSubscription? _removedSub;

  @override
  void initState() {
    super.initState();
    _sub = _service.onNotification.listen((_) {
      if (mounted) setState(() {});
    });
    _removedSub = _service.onNotificationRemoved.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _removedSub?.cancel();
    super.dispose();
  }

  List<CapturedNotification> get _messages {
    var all = _service.getByApp(widget.packageName)
        .where((n) => n.title == widget.contact)
        .toList();
    if (_deletedOnly) all = all.where((n) => n.isRemoved).toList();
    return all;
  }

  Color get _appColor {
    final pkg = widget.packageName;
    if (pkg.contains('whatsapp')) return AppTheme.whatsAppGreen;
    if (pkg.contains('telegram')) return AppTheme.telegramBlue;
    if (pkg.contains('instagram')) return const Color(0xFFE1306C);
    return AppTheme.spyPurple;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final messages = _messages;
    final deletedCount = messages.where((n) => n.isRemoved).length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _appColor.withValues(alpha: 0.12),
              child: Text(
                widget.contact.isNotEmpty ? widget.contact[0].toUpperCase() : '?',
                style: TextStyle(fontWeight: FontWeight.bold, color: _appColor, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contact,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${messages.length} messages${deletedCount > 0 ? ' · $deletedCount deleted' : ''} · ${widget.appName}',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_deletedOnly ? Icons.delete : Icons.delete_outline),
            tooltip: _deletedOnly ? 'Show all' : 'Deleted only',
            color: _deletedOnly ? AppTheme.deletedRed : null,
            onPressed: () => setState(() => _deletedOnly = !_deletedOnly),
          ),
        ],
      ),
      body: messages.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.message_outlined, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('No messages', style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: messages.length,
              reverse: true,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
              itemBuilder: (context, index) {
                final msg = messages[messages.length - 1 - index];
                final prevMsg = index < messages.length - 1 ? messages[messages.length - 2 - index] : null;
                final showDateHeader = prevMsg == null || !_isSameDay(msg.timestamp, prevMsg.timestamp);

                return Column(
                  children: [
                    if (showDateHeader)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _dateLabel(msg.timestamp),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                          ),
                        ),
                      ),
                    _MessageBubble(
                      notification: msg,
                      appColor: _appColor,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => NotificationDetailScreen(notification: msg)),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(dt);
  }
}

class _MessageBubble extends StatelessWidget {
  final CapturedNotification notification;
  final Color appColor;
  final VoidCallback onTap;

  const _MessageBubble({
    required this.notification,
    required this.appColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDeleted = notification.isRemoved;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: isDeleted
              ? AppTheme.deletedRed.withValues(alpha: 0.08)
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: isDeleted
              ? Border.all(color: AppTheme.deletedRed.withValues(alpha: 0.2))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDeleted)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_forever, size: 12, color: AppTheme.deletedRed),
                    const SizedBox(width: 4),
                    Text(
                      'Deleted message',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.deletedRed,
                      ),
                    ),
                  ],
                ),
              ),
            SelectableText(
              notification.bigText ?? notification.text,
              style: TextStyle(
                fontSize: 14,
                color: isDeleted ? AppTheme.deletedRed.withValues(alpha: 0.85) : cs.onSurface,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  DateFormat('HH:mm').format(notification.timestamp),
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                ),
                if (isDeleted && notification.removedAt != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '· deleted ${DateFormat('HH:mm').format(notification.removedAt!)}',
                    style: TextStyle(fontSize: 10, color: AppTheme.deletedRed.withValues(alpha: 0.5)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
