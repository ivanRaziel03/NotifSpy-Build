import 'package:flutter/material.dart';
import 'package:notifspy/services/notification_listener_service.dart';
import 'package:notifspy/theme/app_theme.dart';

class BlacklistScreen extends StatefulWidget {
  const BlacklistScreen({super.key});

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen> {
  final _service = NotificationListenerService();

  void _addFromApps() {
    final apps = _service.getUniqueApps();
    final names = _service.getAppNames();
    final blacklisted = _service.blacklistedApps;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Select apps to blacklist', style: Theme.of(context).textTheme.titleMedium),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: apps.length,
                itemBuilder: (_, i) {
                  final pkg = apps[i];
                  final name = names[pkg] ?? pkg;
                  final isBlocked = blacklisted.contains(pkg);
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: isBlocked ? AppTheme.deletedRed.withValues(alpha: 0.15) : null,
                      child: Icon(
                        isBlocked ? Icons.block : Icons.apps,
                        size: 18,
                        color: isBlocked ? AppTheme.deletedRed : null,
                      ),
                    ),
                    title: Text(name),
                    subtitle: Text(pkg, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    trailing: isBlocked
                        ? const Icon(Icons.block, color: AppTheme.deletedRed)
                        : const Icon(Icons.add_circle_outline),
                    onTap: () {
                      if (isBlocked) {
                        _service.removeBlacklistedApp(pkg);
                      } else {
                        _service.addBlacklistedApp(pkg);
                      }
                      setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final blacklisted = _service.blacklistedApps;
    final names = _service.getAppNames();

    return Scaffold(
      appBar: AppBar(title: const Text('App Blacklist')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFromApps,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.deletedRed.withValues(alpha: 0.1),
                AppTheme.deletedRed.withValues(alpha: 0.03),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.deletedRed.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.block, color: AppTheme.deletedRed, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Blacklisted apps won\'t be captured. Use this to filter out noisy system apps.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: blacklisted.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text('No apps blacklisted', style: TextStyle(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text('All notifications are being captured', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: blacklisted.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final pkg = blacklisted[index];
                      final name = names[pkg] ?? pkg;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.deletedRed.withValues(alpha: 0.12),
                            child: const Icon(Icons.block, color: AppTheme.deletedRed, size: 20),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(pkg, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle, color: AppTheme.deletedRed, size: 20),
                            onPressed: () {
                              _service.removeBlacklistedApp(pkg);
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
