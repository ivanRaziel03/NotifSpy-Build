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
                final isWhatsApp = pkg == 'com.whatsapp' || pkg == 'com.whatsapp.w4b';
                final isTelegram = pkg == 'org.telegram.messenger';

                final color = isWhatsApp
                    ? AppTheme.whatsAppGreen
                    : isTelegram
                        ? AppTheme.telegramBlue
                        : cs.primary;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(
                        isWhatsApp ? Icons.chat : isTelegram ? Icons.send : Icons.apps,
                        color: color,
                        size: 20,
                      ),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(pkg, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
                        if (deleted > 0)
                          Text('$deleted deleted',
                            style: TextStyle(fontSize: 11, color: AppTheme.deletedRed, fontWeight: FontWeight.w500)),
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
}
