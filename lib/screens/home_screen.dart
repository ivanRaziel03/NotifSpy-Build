import 'dart:async';
import 'package:flutter/material.dart';
import 'package:notifspy/models/captured_notification.dart';
import 'package:notifspy/services/notification_listener_service.dart';
import 'package:notifspy/screens/notification_detail_screen.dart';
import 'package:notifspy/screens/app_filter_screen.dart';
import 'package:notifspy/screens/settings_screen.dart';
import 'package:notifspy/theme/app_theme.dart';
import 'package:notifspy/widgets/notification_tile.dart';
import 'package:notifspy/widgets/empty_state.dart';
import 'package:intl/intl.dart';

enum NotifFilter { all, whatsapp, deleted, messaging }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = NotificationListenerService();
  NotifFilter _filter = NotifFilter.all;
  String _searchQuery = '';
  bool _searchActive = false;
  final _searchController = TextEditingController();
  List<CapturedNotification> _notifications = [];
  StreamSubscription? _postedSub;
  StreamSubscription? _removedSub;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _postedSub = _service.onNotification.listen((_) => _loadNotifications());
    _removedSub = _service.onNotificationRemoved.listen((_) => _loadNotifications());
  }

  @override
  void dispose() {
    _postedSub?.cancel();
    _removedSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _loadNotifications() {
    if (!mounted) return;
    setState(() {
      _notifications = _applyFilter(_service.getAllNotifications());
    });
  }

  List<CapturedNotification> _applyFilter(List<CapturedNotification> all) {
    var list = switch (_filter) {
      NotifFilter.all => all,
      NotifFilter.whatsapp => all.where((n) => n.isWhatsApp).toList(),
      NotifFilter.deleted => all.where((n) => n.isRemoved).toList(),
      NotifFilter.messaging => all.where((n) => n.isMessaging).toList(),
    };

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((n) =>
        n.title.toLowerCase().contains(q) ||
        n.text.toLowerCase().contains(q) ||
        n.appName.toLowerCase().contains(q)
      ).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final deletedCount = _service.deletedCount;
    final totalCount = _service.totalCount;

    return Scaffold(
      appBar: AppBar(
        title: _searchActive
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search notifications...',
                  border: InputBorder.none,
                ),
                onChanged: (v) {
                  _searchQuery = v;
                  _loadNotifications();
                },
              )
            : const Text('NotifSpy', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_searchActive ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searchActive = !_searchActive;
                if (!_searchActive) {
                  _searchQuery = '';
                  _searchController.clear();
                  _loadNotifications();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.apps_rounded),
            tooltip: 'Filter by App',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AppFilterScreen()));
              _loadNotifications();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.spyPurple.withValues(alpha: 0.15),
                  AppTheme.accentCyan.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.spyPurple.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                _statChip(Icons.notifications, '$totalCount', 'Captured', cs),
                const SizedBox(width: 16),
                _statChip(Icons.delete_sweep, '$deletedCount', 'Deleted', cs, color: AppTheme.deletedRed),
                const SizedBox(width: 16),
                _statChip(Icons.apps, '${_service.getUniqueApps().length}', 'Apps', cs, color: AppTheme.accentCyan),
              ],
            ),
          ),

          // Filter chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _filterChip('All', NotifFilter.all, Icons.all_inclusive, cs),
                const SizedBox(width: 8),
                _filterChip('WhatsApp', NotifFilter.whatsapp, Icons.chat, cs, color: AppTheme.whatsAppGreen),
                const SizedBox(width: 8),
                _filterChip('Messaging', NotifFilter.messaging, Icons.message, cs, color: AppTheme.telegramBlue),
                const SizedBox(width: 8),
                _filterChip('Deleted', NotifFilter.deleted, Icons.delete_outline, cs, color: AppTheme.deletedRed),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Notification list
          Expanded(
            child: _notifications.isEmpty
                ? EmptyState(
                    icon: _filter == NotifFilter.deleted ? Icons.delete_sweep : Icons.notifications_off,
                    title: _filter == NotifFilter.deleted
                        ? 'No deleted notifications yet'
                        : 'No notifications captured',
                    subtitle: _filter == NotifFilter.all
                        ? 'Notifications will appear here as they arrive'
                        : 'Try changing the filter',
                  )
                : RefreshIndicator(
                    onRefresh: () async => _loadNotifications(),
                    child: ListView.builder(
                      itemCount: _notifications.length,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        final showDateHeader = index == 0 ||
                            !_isSameDay(notif.timestamp, _notifications[index - 1].timestamp);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDateHeader)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                                child: Text(
                                  _dateHeader(notif.timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurfaceVariant,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            NotificationTile(
                              notification: notif,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => NotificationDetailScreen(notification: notif)),
                              ),
                              onDismiss: () async {
                                await _service.deleteNotification(notif.id);
                                _loadNotifications();
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, ColorScheme cs, {Color? color}) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? cs.primary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color ?? cs.onSurface)),
              Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, NotifFilter filter, IconData icon, ColorScheme cs, {Color? color}) {
    final selected = _filter == filter;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12)),
      avatar: Icon(icon, size: 16, color: selected ? Colors.white : (color ?? cs.onSurfaceVariant)),
      selected: selected,
      onSelected: (_) {
        setState(() => _filter = filter);
        _loadNotifications();
      },
      selectedColor: color ?? cs.primary,
      showCheckmark: false,
      labelStyle: TextStyle(color: selected ? Colors.white : null),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    if (date == today) return 'TODAY';
    if (date == today.subtract(const Duration(days: 1))) return 'YESTERDAY';
    return DateFormat('EEEE, MMM d').format(dt).toUpperCase();
  }
}
