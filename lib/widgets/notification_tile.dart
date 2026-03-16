import 'package:flutter/material.dart';
import 'package:notifspy/models/captured_notification.dart';
import 'package:notifspy/theme/app_theme.dart';
import 'package:intl/intl.dart';

class NotificationTile extends StatelessWidget {
  final CapturedNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColor = _getAppColor();

    return Dismissible(
      key: Key(notification.id),
      direction: onDismiss != null ? DismissDirection.endToStart : DismissDirection.none,
      onDismissed: (_) => onDismiss?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: cs.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete, color: cs.error),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App icon
                CircleAvatar(
                  radius: 20,
                  backgroundColor: appColor.withValues(alpha: 0.12),
                  child: Icon(_getAppIcon(), size: 20, color: appColor),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title.isNotEmpty ? notification.title : notification.appName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(notification.timestamp),
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      if (notification.title.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            notification.appName,
                            style: TextStyle(fontSize: 11, color: appColor, fontWeight: FontWeight.w500),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        notification.text,
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Deleted indicator
                if (notification.isRemoved)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, top: 2),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.deletedRed,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getAppColor() {
    if (notification.isWhatsApp) return AppTheme.whatsAppGreen;
    if (notification.isTelegram) return AppTheme.telegramBlue;
    return AppTheme.spyPurple;
  }

  IconData _getAppIcon() {
    if (notification.isWhatsApp) return Icons.chat;
    if (notification.isTelegram) return Icons.send;
    if (notification.packageName.contains('sms') || notification.packageName.contains('messenger')) return Icons.message;
    if (notification.packageName.contains('mail') || notification.packageName.contains('gmail')) return Icons.email;
    return Icons.notifications;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return DateFormat('HH:mm').format(dt);
    return DateFormat('d MMM').format(dt);
  }
}
