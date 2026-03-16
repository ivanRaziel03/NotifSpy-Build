import 'package:flutter/material.dart';
import 'package:notifspy/services/notification_listener_service.dart';
import 'package:notifspy/theme/app_theme.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  final _service = NotificationListenerService();

  void _addFromContacts() {
    final all = _service.getAllNotifications();
    final contacts = <String, int>{};
    for (final n in all) {
      if (n.title.isNotEmpty) {
        contacts[n.title] = (contacts[n.title] ?? 0) + 1;
      }
    }
    final sorted = contacts.keys.toList()
      ..sort((a, b) => contacts[b]!.compareTo(contacts[a]!));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final watched = _service.watchedContacts;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Select contacts to watch', style: Theme.of(context).textTheme.titleMedium),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: sorted.length,
                  itemBuilder: (_, i) {
                    final c = sorted[i];
                    final isWatched = watched.contains(c);
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: isWatched ? AppTheme.accentCyan.withValues(alpha: 0.15) : null,
                        child: Text(c[0].toUpperCase(), style: TextStyle(
                          fontSize: 14,
                          color: isWatched ? AppTheme.accentCyan : null,
                          fontWeight: FontWeight.bold,
                        )),
                      ),
                      title: Text(c),
                      subtitle: Text('${contacts[c]} messages', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      trailing: isWatched
                          ? const Icon(Icons.check_circle, color: AppTheme.accentCyan)
                          : const Icon(Icons.add_circle_outline),
                      onTap: () {
                        if (isWatched) {
                          _service.removeWatchedContact(c);
                        } else {
                          _service.addWatchedContact(c);
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final watched = _service.watchedContacts;
    final all = _service.getAllNotifications();

    return Scaffold(
      appBar: AppBar(title: const Text('Contact Watchlist')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFromContacts,
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.accentCyan.withValues(alpha: 0.12),
                AppTheme.accentCyan.withValues(alpha: 0.04),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility, color: AppTheme.accentCyan, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Watched contacts are highlighted in your feed. Their messages get priority tracking.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: watched.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_off, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text('No contacts watched', style: TextStyle(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Text('Tap + to add from your notifications', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: watched.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final c = watched[index];
                      final msgs = all.where((n) => n.title == c).toList();
                      final deleted = msgs.where((n) => n.isRemoved).length;
                      final lastMsg = msgs.isNotEmpty ? msgs.first : null;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.accentCyan.withValues(alpha: 0.15),
                            child: Text(c.isNotEmpty ? c[0].toUpperCase() : '?',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentCyan)),
                          ),
                          title: Text(c, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            lastMsg != null ? '${msgs.length} msgs${deleted > 0 ? ' · $deleted deleted' : ''} · Last: ${lastMsg.text}' : 'No messages yet',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.remove_circle, color: AppTheme.deletedRed, size: 20),
                            onPressed: () {
                              _service.removeWatchedContact(c);
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
