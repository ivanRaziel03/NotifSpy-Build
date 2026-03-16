import 'dart:async';
import 'package:flutter/material.dart';
import 'package:notifspy/models/captured_notification.dart';
import 'package:notifspy/services/notification_listener_service.dart';
import 'package:notifspy/screens/notification_detail_screen.dart';
import 'package:notifspy/screens/app_filter_screen.dart';
import 'package:notifspy/screens/settings_screen.dart';
import 'package:notifspy/screens/statistics_screen.dart';
import 'package:notifspy/screens/favorites_screen.dart';
import 'package:notifspy/screens/night_summary_screen.dart';
import 'package:notifspy/screens/keyword_alerts_screen.dart';
import 'package:notifspy/screens/watchlist_screen.dart';
import 'package:notifspy/screens/export_screen.dart';
import 'package:notifspy/screens/blacklist_screen.dart';
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
  String? _selectedApp;
  String _searchQuery = '';
  bool _searchActive = false;
  final _searchController = TextEditingController();
  List<CapturedNotification> _notifications = [];
  StreamSubscription? _postedSub;
  StreamSubscription? _removedSub;
  StreamSubscription? _clearedSub;

  // Date range filter
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _postedSub = _service.onNotification.listen((_) => _loadNotifications());
    _removedSub = _service.onNotificationRemoved.listen((_) => _loadNotifications());
    _clearedSub = _service.onCleared.listen((_) => _loadNotifications());
    // Run auto-cleanup on start
    _service.runAutoCleanup();
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
    } else if (_selectedApp == '_ghost') {
      list = all.where((n) => n.isGhostDelete).toList();
    } else if (_selectedApp == '_favorites') {
      list = all.where((n) => n.isFavorite).toList();
    } else {
      list = all.where((n) => n.packageName == _selectedApp).toList();
    }

    if (_dateRange != null) {
      list = list.where((n) =>
        n.timestamp.isAfter(_dateRange!.start) &&
        n.timestamp.isBefore(_dateRange!.end.add(const Duration(days: 1)))
      ).toList();
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

  List<_AppFilter> _buildDynamicFilters() {
    final all = _service.getAllNotifications();
    final appCounts = <String, int>{};
    final appNames = <String, String>{};
    int deletedCount = 0;
    int ghostCount = 0;
    int favCount = 0;

    for (final n in all) {
      appCounts[n.packageName] = (appCounts[n.packageName] ?? 0) + 1;
      appNames[n.packageName] = n.appName;
      if (n.isRemoved) deletedCount++;
      if (n.isGhostDelete) ghostCount++;
      if (n.isFavorite) favCount++;
    }

    final sortedApps = appCounts.keys.toList()
      ..sort((a, b) => appCounts[b]!.compareTo(appCounts[a]!));

    final filters = <_AppFilter>[
      _AppFilter(id: null, label: 'All', count: all.length, icon: Icons.all_inclusive),
    ];

    if (favCount > 0) {
      filters.add(_AppFilter(id: '_favorites', label: 'Starred', count: favCount, icon: Icons.star, color: Colors.amber));
    }

    for (final pkg in sortedApps.take(5)) {
      filters.add(_AppFilter(
        id: pkg,
        label: _shortAppName(appNames[pkg] ?? pkg),
        count: appCounts[pkg] ?? 0,
        icon: _iconForPackage(pkg),
        color: _colorForPackage(pkg),
      ));
    }

    if (ghostCount > 0) {
      filters.add(_AppFilter(id: '_ghost', label: 'Ghost', count: ghostCount, icon: Icons.visibility_off, color: Colors.orange));
    }

    if (deletedCount > 0) {
      filters.add(_AppFilter(id: '_deleted', label: 'Deleted', count: deletedCount, icon: Icons.delete_outline, color: AppTheme.deletedRed));
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

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadNotifications();
    }
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
                decoration: const InputDecoration(hintText: 'Search notifications...', border: InputBorder.none),
                onChanged: (v) { _searchQuery = v; _loadNotifications(); },
              )
            : const Text('NotifSpy', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_searchActive ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searchActive = !_searchActive;
                if (!_searchActive) { _searchQuery = ''; _searchController.clear(); _loadNotifications(); }
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.date_range, color: _dateRange != null ? AppTheme.accentCyan : null),
            tooltip: 'Filter by date',
            onPressed: _pickDateRange,
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'apps', child: ListTile(leading: Icon(Icons.apps_rounded), title: Text('Browse Apps'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'stats', child: ListTile(leading: Icon(Icons.bar_chart), title: Text('Statistics'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'night', child: ListTile(leading: Icon(Icons.nightlight_round), title: Text('Night Summary'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'keywords', child: ListTile(leading: Icon(Icons.search), title: Text('Keyword Alerts'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'watchlist', child: ListTile(leading: Icon(Icons.visibility), title: Text('Watchlist'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'favorites', child: ListTile(leading: Icon(Icons.star), title: Text('Favorites'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.save_alt), title: Text('Export & Backup'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'blacklist', child: ListTile(leading: Icon(Icons.block), title: Text('App Blacklist'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings), title: Text('Settings'), dense: true, contentPadding: EdgeInsets.zero)),
            ],
            onSelected: (v) {
              Widget? screen;
              switch (v) {
                case 'apps': screen = const AppFilterScreen();
                case 'stats': screen = const StatisticsScreen();
                case 'night': screen = const NightSummaryScreen();
                case 'keywords': screen = const KeywordAlertsScreen();
                case 'watchlist': screen = const WatchlistScreen();
                case 'favorites': screen = const FavoritesScreen();
                case 'export': screen = const ExportScreen();
                case 'blacklist': screen = const BlacklistScreen();
                case 'settings': screen = const SettingsScreen();
              }
              if (screen != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => screen!)).then((_) => _loadNotifications());
              }
            },
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
              gradient: LinearGradient(colors: [
                AppTheme.spyPurple.withValues(alpha: 0.15),
                AppTheme.accentCyan.withValues(alpha: 0.08),
              ]),
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

          // Date range indicator
          if (_dateRange != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Chip(
                avatar: const Icon(Icons.date_range, size: 16),
                label: Text('${DateFormat('MMM d').format(_dateRange!.start)} – ${DateFormat('MMM d').format(_dateRange!.end)}', style: const TextStyle(fontSize: 12)),
                onDeleted: () { setState(() => _dateRange = null); _loadNotifications(); },
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
                  onSelected: (_) { setState(() => _selectedApp = f.id); _loadNotifications(); },
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
                    icon: _selectedApp == '_deleted' ? Icons.delete_sweep : _selectedApp == '_ghost' ? Icons.visibility_off : Icons.notifications_off,
                    title: _selectedApp == '_deleted' ? 'No deleted notifications'
                         : _selectedApp == '_ghost' ? 'No ghost deletes detected'
                         : _selectedApp == '_favorites' ? 'No favorites yet'
                         : 'No notifications captured',
                    subtitle: _selectedApp == null ? 'Notifications will appear here as they arrive' : 'Try changing the filter',
                  )
                : RefreshIndicator(
                    onRefresh: () async => _loadNotifications(),
                    child: ListView.builder(
                      itemCount: _notifications.length,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        final showDateHeader = index == 0 || !_isSameDay(notif.timestamp, _notifications[index - 1].timestamp);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDateHeader)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                                child: Text(
                                  _dateHeader(notif.timestamp),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.5),
                                ),
                              ),
                            NotificationTile(
                              notification: notif,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationDetailScreen(notification: notif))),
                              onLongPress: () async {
                                await _service.toggleFavorite(notif.id);
                                _loadNotifications();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(notif.isFavorite ? 'Added to favorites' : 'Removed from favorites'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
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
