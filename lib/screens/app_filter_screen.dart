import 'package:flutter/material.dart';
import 'package:notifspy/services/notification_listener_service.dart';
import 'package:notifspy/screens/app_notifications_screen.dart';
import 'package:notifspy/theme/app_theme.dart';

class AppFilterScreen extends StatelessWidget {
  const AppFilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = NotificationListenerService();
    final apps = service.getUniqueApps();
    final names = service.getAppNames();
    final cs = Theme.of(context).colorScheme;

    final appCounts = <String, int>{};
    final appDeletedCounts = <String, int>{};
    for (final pkg in apps) {
      final notifs = service.getByApp(pkg);
      appCounts[pkg] = notifs.length;
      appDeletedCounts[pkg] = notifs.where((n) => n.isRemoved).length;
    }

    // Sort by count descending
    apps.sort((a, b) => (appCounts[b] ?? 0).compareTo(appCounts[a] ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Apps')),
      body: apps.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.apps, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('No apps tracked yet', style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: apps.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final pkg = apps[index];
                final name = names[pkg] ?? pkg;
                final count = appCounts[pkg] ?? 0;
                final deleted = appDeletedCounts[pkg] ?? 0;
                final color = _colorForPackage(pkg);

                // Count unique contacts
                final contacts = <String>{};
                for (final n in service.getByApp(pkg)) {
                  if (n.title.isNotEmpty) contacts.add(n.title);
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(_iconForPackage(pkg), color: color, size: 20),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Row(
                      children: [
                        Text('$count msgs', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        if (contacts.isNotEmpty) ...[
                          Text(' · ', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                          Text('${contacts.length} contacts', style: TextStyle(fontSize: 11, color: color)),
                        ],
                      ],
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
                        if (deleted > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_forever, size: 11, color: AppTheme.deletedRed),
                              const SizedBox(width: 2),
                              Text('$deleted',
                                style: TextStyle(fontSize: 11, color: AppTheme.deletedRed, fontWeight: FontWeight.w500)),
                            ],
                          ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AppNotificationsScreen(packageName: pkg, appName: name)),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _colorForPackage(String pkg) {
    if (pkg.contains('whatsapp')) return AppTheme.whatsAppGreen;
    if (pkg.contains('telegram')) return AppTheme.telegramBlue;
    if (pkg.contains('instagram')) return const Color(0xFFE1306C);
    if (pkg.contains('twitter') || pkg.contains('x.android')) return const Color(0xFF1DA1F2);
    if (pkg.contains('youtube')) return const Color(0xFFFF0000);
    if (pkg.contains('mail') || pkg.contains('gmail')) return const Color(0xFFEA4335);
    return AppTheme.spyPurple;
  }

  IconData _iconForPackage(String pkg) {
    if (pkg.contains('whatsapp')) return Icons.chat;
    if (pkg.contains('telegram')) return Icons.send;
    if (pkg.contains('sms') || pkg.contains('messenger') || pkg.contains('message')) return Icons.message;
    if (pkg.contains('mail') || pkg.contains('gmail')) return Icons.email;
    if (pkg.contains('instagram')) return Icons.camera_alt;
    if (pkg.contains('twitter') || pkg.contains('x.android')) return Icons.tag;
    if (pkg.contains('youtube')) return Icons.play_circle;
    if (pkg.contains('chrome') || pkg.contains('browser')) return Icons.language;
    if (pkg.contains('phone') || pkg.contains('dialer')) return Icons.phone;
    return Icons.notifications;
  }
}
