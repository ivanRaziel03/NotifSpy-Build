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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = NotificationListenerService();
  String? _selectedApp; // null = all, 'deleted' = deleted only, else = packageName
  String _searchQuery = '';
  bool _searchActive = false;
  final _searchController = TextEditingController();
  List<CapturedNotification> _notifications = [];
  StreamSubscription? _postedSub;
  StreamSubscription? _removedSub;
  StreamSubscription? _clearedSub;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _postedSub = _service.onNotification.listen((_) => _loadNotifications());
    _removedSub = _service.onNotificationRemoved.listen((_) => _loadNotifications());
    _clearedSub = _service.onCleared.listen((_) => _loadNotifications());
  }

  @override
  void dispose() {
    _postedSub?.cancel();
    _removedSub?.cancel();
    _clearedSub?.cancel();
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
    List<CapturedNotification> list;
    if (_selectedApp == null) {
      list = all;
    } else if (_selectedApp == '_deleted') {
      list = all.where((n) => n.isRemoved).toList();
    } else {
      list = all.where((n) => n.packageName == _selectedApp).toList();
    }

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

  /// Build dynamic filter chips from the apps that actually sent notifications
  List<_AppFilter> _buildDynamicFilters() {
    final all = _service.getAllNotifications();
    final appCounts = <String, int>{};
    final appNames = <String, String>{};
    int deletedCount = 0;

    for (final n in all) {
      appCounts[n.packageName] = (appCounts[n.packageName] ?? 0) + 1;
      appNames[n.packageName] = n.appName;
      if (n.isRemoved) deletedCount++;
    }

    // Sort apps by count descending
    final sortedApps = appCounts.keys.toList()
      ..sort((a, b) => appCounts[b]!.compareTo(appCounts[a]!));

    final filters = <_AppFilter>[
      _AppFilter(id: null, label: 'All', count: all.length, icon: Icons.all_inclusive),
    ];

    // Top apps as filter chips
    for (final pkg in sortedApps.take(6)) {
      filters.add(_AppFilter(
        id: pkg,
        label: _shortAppName(appNames[pkg] ?? pkg),
        count: appCounts[pkg] ?? 0,
        icon: _iconForPackage(pkg),
        color: _colorForPackage(pkg),
      ));
    }

    if (deletedCount > 0) {
      filters.add(_AppFilter(
        id: '_deleted',
        label: 'Deleted',
        count: deletedCount,
        icon: Icons.delete_outline,
        color: AppTheme.deletedRed,
      ));
    }

    return filters;
  }

  String _shortAppName(String name) {
    if (name.length <= 12) return name;
    if (name.contains(' ')) return name.split(' ').first;
    return name.substring(0, 10);
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

  Color _colorForPackage(String pkg) {
    if (pkg.contains('whatsapp')) return AppTheme.whatsAppGreen;
    if (pkg.contains('telegram')) return AppTheme.telegramBlue;
    if (pkg.contains('instagram')) return const Color(0xFFE1306C);
    if (pkg.contains('twitter') || pkg.contains('x.android')) return const Color(0xFF1DA1F2);
    if (pkg.contains('youtube')) return const Color(0xFFFF0000);
    if (pkg.contains('mail') || pkg.contains('gmail')) return const Color(0xFFEA4335);
    return AppTheme.spyPurple;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final deletedCount = _service.deletedCount;
    final totalCount = _service.totalCount;
    final dynamicFilters = _buildDynamicFilters();

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
            tooltip: 'Browse by App',
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

          // Dynamic filter chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: dynamicFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final f = dynamicFilters[index];
                final selected = _selectedApp == f.id;
                return FilterChip(
                  label: Text('${f.label} ${f.count}', style: const TextStyle(fontSize: 12)),
                  avatar: Icon(f.icon, size: 16, color: selected ? Colors.white : (f.color ?? cs.onSurfaceVariant)),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _selectedApp = f.id);
                    _loadNotifications();
                  },
                  selectedColor: f.color ?? cs.primary,
                  showCheckmark: false,
                  labelStyle: TextStyle(color: selected ? Colors.white : null),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Notification list
          Expanded(
            child: _notifications.isEmpty
                ? EmptyState(
                    icon: _selectedApp == '_deleted' ? Icons.delete_sweep : Icons.notifications_off,
                    title: _selectedApp == '_deleted'
                        ? 'No deleted notifications yet'
                        : 'No notifications captured',
                    subtitle: _selectedApp == null
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

class _AppFilter {
  final String? id;
  final String label;
  final int count;
  final IconData icon;
  final Color? color;

  _AppFilter({required this.id, required this.label, required this.count, required this.icon, this.color});
}
