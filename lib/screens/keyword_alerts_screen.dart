import 'package:flutter/material.dart';
import 'package:notifspy/services/notification_listener_service.dart';
import 'package:notifspy/theme/app_theme.dart';

class KeywordAlertsScreen extends StatefulWidget {
  const KeywordAlertsScreen({super.key});

  @override
  State<KeywordAlertsScreen> createState() => _KeywordAlertsScreenState();
}

class _KeywordAlertsScreenState extends State<KeywordAlertsScreen> {
  final _service = NotificationListenerService();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addKeyword() {
    final kw = _controller.text.trim();
    if (kw.isEmpty) return;
    _service.addKeyword(kw);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keywords = _service.keywords;
    final all = _service.getAllNotifications();

    return Scaffold(
      appBar: AppBar(title: const Text('Keyword Alerts')),
      body: Column(
        children: [
          // Info card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.orange.withValues(alpha: 0.12),
                Colors.orange.withValues(alpha: 0.04),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add keywords to monitor. You\'ll be alerted when any notification contains these words.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          // Add keyword
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Enter keyword...',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _addKeyword(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _addKeyword,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Keywords list
          Expanded(
            child: keywords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text('No keywords set', style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: keywords.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final kw = keywords[index];
                      final hitCount = all.where((n) {
                        final content = '${n.title} ${n.text} ${n.bigText ?? ''}'.toLowerCase();
                        return content.contains(kw);
                      }).length;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.withValues(alpha: 0.12),
                            child: const Icon(Icons.search, color: Colors.orange, size: 20),
                          ),
                          title: Text('"$kw"', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('$hitCount matches found', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          trailing: IconButton(
                            icon: Icon(Icons.close, color: AppTheme.deletedRed, size: 20),
                            onPressed: () {
                              _service.removeKeyword(kw);
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
