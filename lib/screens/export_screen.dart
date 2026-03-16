import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:notifspy/services/notification_listener_service.dart';
import 'package:notifspy/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = NotificationListenerService();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Export & Backup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.spyPurple.withValues(alpha: 0.12),
                AppTheme.accentCyan.withValues(alpha: 0.06),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.spyPurple.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.save_alt, color: AppTheme.spyPurple, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Export your captured notifications. All data stays local - exports are for your own backup.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Full backup
          _ExportCard(
            icon: Icons.cloud_download,
            title: 'Full Backup (JSON)',
            subtitle: 'Export all ${service.totalCount} notifications as a JSON file',
            color: AppTheme.spyPurple,
            onTap: () => _exportJson(context, service),
          ),
          const SizedBox(height: 12),

          // Export by app
          _ExportCard(
            icon: Icons.apps,
            title: 'Export by App',
            subtitle: 'Choose an app to export its notifications',
            color: AppTheme.accentCyan,
            onTap: () => _exportByApp(context, service),
          ),
          const SizedBox(height: 12),

          // Export contact thread
          _ExportCard(
            icon: Icons.person,
            title: 'Export Contact Thread',
            subtitle: 'Export a conversation as readable text',
            color: AppTheme.whatsAppGreen,
            onTap: () => _exportThread(context, service),
          ),
        ],
      ),
    );
  }

  Future<void> _exportJson(BuildContext context, NotificationListenerService service) async {
    final json = service.exportAllToJson();
    final dir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/notifspy_backup_$timestamp.json');
    await file.writeAsString(json);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'NotifSpy Backup'));
  }

  Future<void> _exportByApp(BuildContext context, NotificationListenerService service) async {
    final apps = service.getUniqueApps();
    final names = service.getAppNames();

    if (!context.mounted) return;
    final pkg = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Select app', style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: apps.length,
              itemBuilder: (_, i) {
                final p = apps[i];
                return ListTile(
                  title: Text(names[p] ?? p),
                  subtitle: Text('${service.getByApp(p).length} notifications', style: TextStyle(fontSize: 12)),
                  onTap: () => Navigator.pop(ctx, p),
                );
              },
            ),
          ),
        ],
      ),
    );

    if (pkg == null) return;

    final notifs = service.getByApp(pkg);
    final data = notifs.map((n) => n.toJson()).toList();
    final appName = names[pkg] ?? pkg;
    final json = '{"app": "$appName", "count": ${data.length}, "notifications": ${_jsonEncode(data)}}';
    final dir = await getTemporaryDirectory();
    final safeName = appName.replaceAll(RegExp(r'[^\w]'), '_');
    final file = File('${dir.path}/notifspy_$safeName.json');
    await file.writeAsString(json);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'NotifSpy - $appName'));
  }

  Future<void> _exportThread(BuildContext context, NotificationListenerService service) async {
    final apps = service.getUniqueApps();
    final names = service.getAppNames();

    if (!context.mounted) return;
    final pkg = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Select app', style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: apps.length,
              itemBuilder: (_, i) {
                final p = apps[i];
                return ListTile(
                  title: Text(names[p] ?? p),
                  onTap: () => Navigator.pop(ctx, p),
                );
              },
            ),
          ),
        ],
      ),
    );

    if (pkg == null || !context.mounted) return;

    // Pick contact
    final contacts = <String>{};
    for (final n in service.getByApp(pkg)) {
      if (n.title.isNotEmpty) contacts.add(n.title);
    }

    final contact = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Select contact', style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: contacts.map((c) => ListTile(
                title: Text(c),
                onTap: () => Navigator.pop(ctx, c),
              )).toList(),
            ),
          ),
        ],
      ),
    );

    if (contact == null) return;

    final text = service.exportThreadToText(pkg, contact);
    final dir = await getTemporaryDirectory();
    final safeName = contact.replaceAll(RegExp(r'[^\w]'), '_');
    final file = File('${dir.path}/notifspy_thread_$safeName.txt');
    await file.writeAsString(text);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Thread: $contact'));
  }

  String _jsonEncode(List<Map<String, dynamic>> data) {
    return data.map((d) => '{${d.entries.map((e) => '"${e.key}": ${e.value is String ? '"${e.value}"' : e.value}').join(', ')}}').join(',\n');
  }
}

class _ExportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ExportCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
