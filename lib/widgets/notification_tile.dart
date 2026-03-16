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
    final isDeleted = notification.isRemoved;

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
        color: isDeleted
            ? AppTheme.deletedRed.withValues(alpha: 0.08)
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDeleted
              ? BorderSide(color: AppTheme.deletedRed.withValues(alpha: 0.25), width: 1)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App icon with deleted overlay
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: appColor.withValues(alpha: 0.12),
                      child: Icon(_getAppIcon(), size: 20, color: appColor),
                    ),
                    if (isDeleted)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppTheme.deletedRed,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDeleted
                                  ? AppTheme.deletedRed.withValues(alpha: 0.08)
                                  : cs.surface,
                              width: 2,
                            ),
                          ),
                          child: const Icon(Icons.close, size: 8, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isDeleted)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.delete_forever, size: 14, color: AppTheme.deletedRed),
                            ),
                          Expanded(
                            child: Text(
                              notification.title.isNotEmpty ? notification.title : notification.appName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isDeleted ? AppTheme.deletedRed : null,
                              ),
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
                        style: TextStyle(
                          fontSize: 13,
                          color: isDeleted ? AppTheme.deletedRed.withValues(alpha: 0.7) : cs.onSurfaceVariant,
                          height: 1.3,
                          fontStyle: isDeleted ? FontStyle.italic : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isDeleted && notification.removedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Deleted ${_formatTimeDiff(notification.removedAt!)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.deletedRed.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
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
    final pkg = notification.packageName;
    if (pkg.contains('instagram')) return const Color(0xFFE1306C);
    if (pkg.contains('twitter') || pkg.contains('x.android')) return const Color(0xFF1DA1F2);
    if (pkg.contains('youtube')) return const Color(0xFFFF0000);
    if (pkg.contains('mail') || pkg.contains('gmail')) return const Color(0xFFEA4335);
    return AppTheme.spyPurple;
  }

  IconData _getAppIcon() {
    if (notification.isWhatsApp) return Icons.chat;
    if (notification.isTelegram) return Icons.send;
    final pkg = notification.packageName;
    if (pkg.contains('sms') || pkg.contains('messenger') || pkg.contains('message')) return Icons.message;
    if (pkg.contains('mail') || pkg.contains('gmail')) return Icons.email;
    if (pkg.contains('instagram')) return Icons.camera_alt;
    if (pkg.contains('twitter') || pkg.contains('x.android')) return Icons.tag;
    if (pkg.contains('youtube')) return Icons.play_circle;
    if (pkg.contains('chrome') || pkg.contains('browser')) return Icons.language;
    if (pkg.contains('phone') || pkg.contains('dialer')) return Icons.phone;
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

  String _formatTimeDiff(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('d MMM, HH:mm').format(dt);
  }
}
