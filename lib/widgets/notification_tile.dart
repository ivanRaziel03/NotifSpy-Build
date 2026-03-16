import 'package:flutter/material.dart';
import 'package:notifspy/models/captured_notification.dart';
import 'package:notifspy/theme/app_theme.dart';
import 'package:intl/intl.dart';

class NotificationTile extends StatelessWidget {
  final CapturedNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;
  final VoidCallback? onLongPress;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.onDismiss,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColor = _getAppColor();
    final isDeleted = notification.isRemoved;
    final isGhost = notification.isGhostDelete;

    return Dismissible(
      key: Key(notification.id),
      direction: onDismiss != null ? DismissDirection.endToStart : DismissDirection.none,
      onDismissed: (_) => onDismiss?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(color: cs.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
        child: Icon(Icons.delete, color: cs.error),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 3),
        color: isGhost
            ? Colors.orange.withValues(alpha: 0.08)
            : isDeleted
                ? AppTheme.deletedRed.withValues(alpha: 0.08)
                : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isGhost
              ? BorderSide(color: Colors.orange.withValues(alpha: 0.3), width: 1)
              : isDeleted
                  ? BorderSide(color: AppTheme.deletedRed.withValues(alpha: 0.25), width: 1)
                  : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: appColor.withValues(alpha: 0.12),
                      child: Icon(_getAppIcon(), size: 20, color: appColor),
                    ),
                    if (isGhost)
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            color: Colors.orange, shape: BoxShape.circle,
                            border: Border.all(color: cs.surface, width: 2),
                          ),
                          child: const Icon(Icons.visibility_off, size: 8, color: Colors.white),
                        ),
                      )
                    else if (isDeleted)
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            color: AppTheme.deletedRed, shape: BoxShape.circle,
                            border: Border.all(color: cs.surface, width: 2),
                          ),
                          child: const Icon(Icons.close, size: 8, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (notification.isFavorite)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.star, size: 14, color: Colors.amber),
                            ),
                          if (isGhost)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.visibility_off, size: 14, color: Colors.orange),
                            )
                          else if (isDeleted)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.delete_forever, size: 14, color: AppTheme.deletedRed),
                            ),
                          Expanded(
                            child: Text(
                              notification.title.isNotEmpty ? notification.title : notification.appName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14,
                                color: isGhost ? Colors.orange : isDeleted ? AppTheme.deletedRed : null,
                              ),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_formatTime(notification.timestamp), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        ],
                      ),
                      if (notification.title.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Row(
                            children: [
                              Text(notification.appName, style: TextStyle(fontSize: 11, color: appColor, fontWeight: FontWeight.w500)),
                              if (notification.mediaType != null) ...[
                                const SizedBox(width: 6),
                                Icon(_mediaIcon(notification.mediaType!), size: 12, color: cs.onSurfaceVariant),
                                const SizedBox(width: 2),
                                Text(notification.mediaType!, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        notification.text,
                        style: TextStyle(
                          fontSize: 13,
                          color: isGhost ? Colors.orange.withValues(alpha: 0.7) : isDeleted ? AppTheme.deletedRed.withValues(alpha: 0.7) : cs.onSurfaceVariant,
                          height: 1.3,
                          fontStyle: isDeleted || isGhost ? FontStyle.italic : null,
                        ),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      if (isGhost)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                            child: Text('Ghost delete - sent & deleted in seconds', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.w600)),
                          ),
                        )
                      else if (isDeleted && notification.removedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Deleted ${_formatTimeDiff(notification.removedAt!)}',
                            style: TextStyle(fontSize: 10, color: AppTheme.deletedRed.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
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

  IconData _mediaIcon(String type) {
    return switch (type) {
      'photo' => Icons.photo,
      'video' => Icons.videocam,
      'audio' => Icons.mic,
      'document' => Icons.insert_drive_file,
      'sticker' => Icons.emoji_emotions,
      'location' => Icons.location_on,
      'contact' => Icons.contact_page,
      _ => Icons.attachment,
    };
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
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return DateFormat('HH:mm').format(dt);
    return DateFormat('d MMM').format(dt);
  }

  String _formatTimeDiff(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('d MMM, HH:mm').format(dt);
  }
}
