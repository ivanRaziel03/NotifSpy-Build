import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notifspy/models/captured_notification.dart';
import 'package:notifspy/theme/app_theme.dart';
import 'package:intl/intl.dart';

class NotificationDetailScreen extends StatelessWidget {
  final CapturedNotification notification;

  const NotificationDetailScreen({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy text',
            onPressed: () {
              final text = '${notification.title}\n${notification.text}';
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _appColor.withValues(alpha: 0.15),
                  _appColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _appColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: _appColor.withValues(alpha: 0.2),
                  child: Icon(_appIcon, size: 32, color: _appColor),
                ),
                const SizedBox(height: 12),
                Text(notification.appName, style: ts.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(notification.packageName, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                if (notification.isRemoved) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.deletedRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_sweep, size: 14, color: AppTheme.deletedRed),
                        const SizedBox(width: 4),
                        Text('Deleted / Dismissed',
                          style: TextStyle(fontSize: 12, color: AppTheme.deletedRed, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Content
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notification.conversationTitle != null && notification.conversationTitle!.isNotEmpty) ...[
                    _labelValue('Group', notification.conversationTitle!, cs),
                    const Divider(height: 20),
                  ],
                  if (notification.title.isNotEmpty) ...[
                    _labelValue('From', notification.title, cs),
                    const Divider(height: 20),
                  ],
                  _labelValue('Message', notification.bigText ?? notification.text, cs, selectable: true),
                  if (notification.subText != null && notification.subText!.isNotEmpty) ...[
                    const Divider(height: 20),
                    _labelValue('Sub', notification.subText!, cs),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Metadata
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Details', style: ts.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _metaRow(Icons.access_time, 'Received', DateFormat('MMM d, yyyy  HH:mm:ss').format(notification.timestamp), cs),
                  if (notification.isRemoved && notification.removedAt != null)
                    _metaRow(Icons.delete_outline, 'Removed', DateFormat('MMM d, yyyy  HH:mm:ss').format(notification.removedAt!), cs),
                  if (notification.category != null)
                    _metaRow(Icons.category, 'Category', notification.category!, cs),
                  _metaRow(Icons.apps, 'Package', notification.packageName, cs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelValue(String label, String value, ColorScheme cs, {bool selectable = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        selectable
            ? SelectableText(value, style: const TextStyle(fontSize: 15, height: 1.5))
            : Text(value, style: const TextStyle(fontSize: 15, height: 1.5)),
      ],
    );
  }

  Widget _metaRow(IconData icon, String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 2),
          ),
        ],
      ),
    );
  }

  Color get _appColor {
    if (notification.isWhatsApp) return AppTheme.whatsAppGreen;
    if (notification.isTelegram) return AppTheme.telegramBlue;
    return AppTheme.spyPurple;
  }

  IconData get _appIcon {
    if (notification.isWhatsApp) return Icons.chat;
    if (notification.isTelegram) return Icons.send;
    return Icons.notifications;
  }
}
