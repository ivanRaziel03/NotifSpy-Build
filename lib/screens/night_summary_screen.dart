import 'package:flutter/material.dart';
import 'package:notifspy/services/notification_listener_service.dart';
import 'package:notifspy/screens/notification_detail_screen.dart';
import 'package:notifspy/theme/app_theme.dart';
import 'package:notifspy/widgets/notification_tile.dart';
import 'package:intl/intl.dart';

class NightSummaryScreen extends StatelessWidget {
  const NightSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = NotificationListenerService();
    final cs = Theme.of(context).colorScheme;
    final nightNotifs = service.getNightNotifications();

    final startHour = service.nightStartHour;
    final endHour = service.nightEndHour;

    // Group by app
    final byApp = <String, List<dynamic>>{};
    for (final n in nightNotifs) {
      byApp.putIfAbsent(n.appName, () => []).add(n);
    }

    final deletedCount = nightNotifs.where((n) => n.isRemoved).length;
    final ghostCount = nightNotifs.where((n) => n.isGhostDelete).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Night Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configure hours',
            onPressed: () => _configureHours(context, service),
          ),
        ],
      ),
      body: nightNotifs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.nightlight_round, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('Quiet night!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  const SizedBox(height: 4),
                  Text('No notifications between ${startHour}h–${endHour}h',
                style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Night digest header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFF1A1A3E).withValues(alpha: 0.8),
                      AppTheme.spyPurple.withValues(alpha: 0.3),
                    ]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.nightlight_round, color: Colors.amber, size: 36),
                      const SizedBox(height: 10),
                      Text('While You Slept', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('$startHour:00 – $endHour:00 · ${DateFormat('EEEE, MMM d').format(DateTime.now())}',
                        style: TextStyle(fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _nightStat('${nightNotifs.length}', 'Total', Icons.notifications),
                          _nightStat('${byApp.length}', 'Apps', Icons.apps),
                          _nightStat('$deletedCount', 'Deleted', Icons.delete_sweep),
                          if (ghostCount > 0) _nightStat('$ghostCount', 'Ghost', Icons.visibility_off),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // By app breakdown
                ...byApp.entries.map((entry) {
                  final appName = entry.key;
                  final msgs = entry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Text(appName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.spyPurple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${msgs.length}', style: TextStyle(fontSize: 11, color: AppTheme.spyPurple, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                      ...msgs.take(5).map((n) => NotificationTile(
                        notification: n,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => NotificationDetailScreen(notification: n)),
                        ),
                      )),
                      if (msgs.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 8),
                          child: Text('+${msgs.length - 5} more', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ),
                    ],
                  );
                }),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _nightStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
      ],
    );
  }

  void _configureHours(BuildContext context, NotificationListenerService service) {
    int start = service.nightStartHour;
    int end = service.nightEndHour;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Night Hours'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Night starts at:', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Slider(
                value: start.toDouble(),
                min: 18,
                max: 23,
                divisions: 5,
                label: '$start:00',
                onChanged: (v) => setDialogState(() => start = v.toInt()),
              ),
              Text('Night ends at:', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Slider(
                value: end.toDouble(),
                min: 4,
                max: 12,
                divisions: 8,
                label: '$end:00',
                onChanged: (v) => setDialogState(() => end = v.toInt()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                service.nightStartHour = start;
                service.nightEndHour = end;
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
