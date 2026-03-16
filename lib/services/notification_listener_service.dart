import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:notifspy/models/captured_notification.dart';

class NotificationListenerService {
  static const _channel = MethodChannel('com.samandari.notifspy/listener');
  static const _eventChannel = EventChannel('com.samandari.notifspy/notifications');
  static final NotificationListenerService _instance = NotificationListenerService._();
  factory NotificationListenerService() => _instance;
  NotificationListenerService._();

  final _uuid = const Uuid();
  StreamSubscription? _subscription;
  Box<CapturedNotification>? _box;
  Box? _settingsBox;

  final _notificationController = StreamController<CapturedNotification>.broadcast();
  Stream<CapturedNotification> get onNotification => _notificationController.stream;

  final _removedController = StreamController<String>.broadcast();
  Stream<String> get onNotificationRemoved => _removedController.stream;

  final _clearedController = StreamController<void>.broadcast();
  Stream<void> get onCleared => _clearedController.stream;

  final _keywordHitController = StreamController<CapturedNotification>.broadcast();
  Stream<CapturedNotification> get onKeywordHit => _keywordHitController.stream;

  final _watchlistHitController = StreamController<CapturedNotification>.broadcast();
  Stream<CapturedNotification> get onWatchlistHit => _watchlistHitController.stream;

  // Ghost detection: track recent posts to detect quick deletions
  final _recentPosts = <String, DateTime>{};

  Future<void> init() async {
    _box = Hive.box<CapturedNotification>('notifications');
    _settingsBox = Hive.box('settings');
    _listenToNativeEvents();
  }

  void _listenToNativeEvents() {
    _subscription?.cancel();
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final type = event['type'] as String?;
          if (type == 'posted') {
            _handlePosted(Map<String, dynamic>.from(event));
          } else if (type == 'removed') {
            _handleRemoved(Map<String, dynamic>.from(event));
          }
        }
      },
      onError: (e) => debugPrint('[NotifSpy] Stream error: $e'),
    );
  }

  void _handlePosted(Map<String, dynamic> data) {
    final packageName = data['packageName'] as String? ?? '';
    if (packageName == 'com.samandari.notifspy' || packageName == 'com.example.samapp') return;

    // Check blacklist
    if (blacklistedApps.contains(packageName)) return;

    final title = data['title'] as String? ?? '';
    final text = data['text'] as String? ?? '';
    if (title.isEmpty && text.isEmpty) return;

    final isGroupSummary = data['isGroupSummary'] as bool? ?? false;
    if (isGroupSummary) return;

    final notif = CapturedNotification()
      ..id = _uuid.v4()
      ..packageName = packageName
      ..appName = data['appName'] as String? ?? packageName
      ..title = title
      ..text = text
      ..timestamp = DateTime.now()
      ..bigText = data['bigText'] as String?
      ..subText = data['subText'] as String?
      ..category = data['category'] as String?
      ..isGroupSummary = isGroupSummary
      ..conversationTitle = data['conversationTitle'] as String?
      ..mediaType = _detectMediaType(text, data['bigText'] as String?);

    _box?.put(notif.id, notif);
    _notificationController.add(notif);

    // Track for ghost detection
    final postKey = '$packageName|$title|$text';
    _recentPosts[postKey] = DateTime.now();
    // Clean old entries after 30 seconds
    Future.delayed(const Duration(seconds: 30), () => _recentPosts.remove(postKey));

    // Check keywords
    _checkKeywords(notif);

    // Check watchlist
    _checkWatchlist(notif);
  }

  void _handleRemoved(Map<String, dynamic> data) {
    final key = data['key'] as String? ?? '';
    final packageName = data['packageName'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final text = data['text'] as String? ?? '';

    if (_box == null) return;

    final matches = _box!.values.where((n) =>
      !n.isRemoved &&
      n.packageName == packageName &&
      (title.isEmpty || n.title == title) &&
      (text.isEmpty || n.text == text)
    ).toList();

    // Ghost detection: was this posted very recently (< 10 seconds)?
    final postKey = '$packageName|$title|$text';
    final postTime = _recentPosts[postKey];
    final isGhost = postTime != null && DateTime.now().difference(postTime).inSeconds < 10;

    for (final match in matches) {
      match.isRemoved = true;
      match.removedAt = DateTime.now();
      if (isGhost) match.isGhostDelete = true;
      match.save();
    }

    if (matches.isNotEmpty) {
      _removedController.add(key);
    }
  }

  // ===== Media Detection =====
  String? _detectMediaType(String text, String? bigText) {
    final content = '$text ${bigText ?? ''}'.toLowerCase();
    if (content.contains('photo') || content.contains('image') || content.contains('📷') || content.contains('🖼')) {
      return 'photo';
    }
    if (content.contains('video') || content.contains('📹') || content.contains('🎥')) {
      return 'video';
    }
    if (content.contains('voice message') || content.contains('audio') || content.contains('🎵') || content.contains('🎤')) {
      return 'audio';
    }
    if (content.contains('document') || content.contains('📄') || content.contains('📎') || content.contains('file')) {
      return 'document';
    }
    if (content.contains('sticker') || content.contains('gif')) {
      return 'sticker';
    }
    if (content.contains('location') || content.contains('📍')) {
      return 'location';
    }
    if (content.contains('contact card') || content.contains('vcard')) {
      return 'contact';
    }
    return null;
  }

  // ===== Keyword Alerts =====
  List<String> get keywords {
    final raw = _settingsBox?.get('keywords', defaultValue: <dynamic>[]) as List<dynamic>;
    return raw.cast<String>();
  }

  set keywords(List<String> value) => _settingsBox?.put('keywords', value);

  void addKeyword(String kw) {
    final list = keywords;
    if (!list.contains(kw.toLowerCase())) {
      list.add(kw.toLowerCase());
      keywords = list;
    }
  }

  void removeKeyword(String kw) {
    final list = keywords;
    list.remove(kw.toLowerCase());
    keywords = list;
  }

  void _checkKeywords(CapturedNotification notif) {
    final kws = keywords;
    if (kws.isEmpty) return;
    final content = '${notif.title} ${notif.text} ${notif.bigText ?? ''}'.toLowerCase();
    for (final kw in kws) {
      if (content.contains(kw)) {
        _keywordHitController.add(notif);
        return;
      }
    }
  }

  // ===== Contact Watchlist =====
  List<String> get watchedContacts {
    final raw = _settingsBox?.get('watchedContacts', defaultValue: <dynamic>[]) as List<dynamic>;
    return raw.cast<String>();
  }

  set watchedContacts(List<String> value) => _settingsBox?.put('watchedContacts', value);

  void addWatchedContact(String contact) {
    final list = watchedContacts;
    if (!list.contains(contact)) {
      list.add(contact);
      watchedContacts = list;
    }
  }

  void removeWatchedContact(String contact) {
    final list = watchedContacts;
    list.remove(contact);
    watchedContacts = list;
  }

  bool isContactWatched(String contact) => watchedContacts.contains(contact);

  void _checkWatchlist(CapturedNotification notif) {
    if (watchedContacts.contains(notif.title)) {
      _watchlistHitController.add(notif);
    }
  }

  // ===== App Blacklist =====
  List<String> get blacklistedApps {
    final raw = _settingsBox?.get('blacklistedApps', defaultValue: <dynamic>[]) as List<dynamic>;
    return raw.cast<String>();
  }

  set blacklistedApps(List<String> value) => _settingsBox?.put('blacklistedApps', value);

  void addBlacklistedApp(String pkg) {
    final list = blacklistedApps;
    if (!list.contains(pkg)) {
      list.add(pkg);
      blacklistedApps = list;
    }
  }

  void removeBlacklistedApp(String pkg) {
    final list = blacklistedApps;
    list.remove(pkg);
    blacklistedApps = list;
  }

  // ===== Auto Cleanup =====
  int get autoCleanupDays => _settingsBox?.get('autoCleanupDays', defaultValue: 0) as int;
  set autoCleanupDays(int value) => _settingsBox?.put('autoCleanupDays', value);

  int get nightStartHour => _settingsBox?.get('nightStartHour', defaultValue: 23) as int;
  int get nightEndHour => _settingsBox?.get('nightEndHour', defaultValue: 7) as int;
  set nightStartHour(int value) => _settingsBox?.put('nightStartHour', value);
  set nightEndHour(int value) => _settingsBox?.put('nightEndHour', value);

  Future<int> runAutoCleanup() async {
    final days = autoCleanupDays;
    if (days <= 0 || _box == null) return 0;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final toDelete = _box!.values.where((n) => n.timestamp.isBefore(cutoff)).toList();
    for (final n in toDelete) {
      await _box!.delete(n.id);
    }
    if (toDelete.isNotEmpty) _clearedController.add(null);
    return toDelete.length;
  }

  // ===== Favorites =====
  Future<void> toggleFavorite(String id) async {
    final notif = _box?.get(id);
    if (notif != null) {
      notif.isFavorite = !notif.isFavorite;
      await notif.save();
      _clearedController.add(null); // trigger UI refresh
    }
  }

  List<CapturedNotification> getFavorites() {
    return (_box?.values.where((n) => n.isFavorite).toList() ?? [])
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // ===== Night Summary =====
  List<CapturedNotification> getNightNotifications({DateTime? date}) {
    final d = date ?? DateTime.now();
    final nightStart = DateTime(d.year, d.month, d.day - 1, nightStartHour);
    final nightEnd = DateTime(d.year, d.month, d.day, nightEndHour);
    return getAllNotifications().where((n) =>
      n.timestamp.isAfter(nightStart) && n.timestamp.isBefore(nightEnd)
    ).toList();
  }

  // ===== Export =====
  String exportAllToJson() {
    final data = getAllNotifications().map((n) => n.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert({'notifications': data, 'exportedAt': DateTime.now().toIso8601String()});
  }

  String exportThreadToText(String packageName, String contact) {
    final msgs = getByApp(packageName).where((n) => n.title == contact).toList();
    msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final buf = StringBuffer();
    buf.writeln('Thread: $contact');
    buf.writeln('App: ${msgs.isNotEmpty ? msgs.first.appName : packageName}');
    buf.writeln('Messages: ${msgs.length}');
    buf.writeln('---');
    for (final m in msgs) {
      final time = '${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}';
      final date = '${m.timestamp.year}-${m.timestamp.month.toString().padLeft(2, '0')}-${m.timestamp.day.toString().padLeft(2, '0')}';
      final deleted = m.isRemoved ? ' [DELETED]' : '';
      final ghost = m.isGhostDelete ? ' [GHOST]' : '';
      buf.writeln('[$date $time]$deleted$ghost ${m.text}');
    }
    return buf.toString();
  }

  // ===== Queries =====
  Future<bool> isPermissionGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isPermissionGranted') ?? false;
    } catch (e) {
      debugPrint('[NotifSpy] Permission check error: $e');
      return false;
    }
  }

  Future<void> openPermissionSettings() async {
    try {
      await _channel.invokeMethod('openPermissionSettings');
    } catch (e) {
      debugPrint('[NotifSpy] Open settings error: $e');
    }
  }

  List<CapturedNotification> getAllNotifications() {
    return (_box?.values.toList() ?? [])
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  List<CapturedNotification> getByApp(String packageName) {
    return getAllNotifications().where((n) => n.packageName == packageName).toList();
  }

  List<CapturedNotification> getDeletedOnly() {
    return getAllNotifications().where((n) => n.isRemoved).toList();
  }

  List<CapturedNotification> getGhostDeletes() {
    return getAllNotifications().where((n) => n.isGhostDelete).toList();
  }

  List<CapturedNotification> getByDateRange(DateTime start, DateTime end) {
    return getAllNotifications().where((n) =>
      n.timestamp.isAfter(start) && n.timestamp.isBefore(end)
    ).toList();
  }

  List<String> getUniqueApps() {
    final apps = <String>{};
    for (final n in _box?.values ?? <CapturedNotification>[]) {
      apps.add(n.packageName);
    }
    return apps.toList()..sort();
  }

  Map<String, String> getAppNames() {
    final map = <String, String>{};
    for (final n in _box?.values ?? <CapturedNotification>[]) {
      map[n.packageName] = n.appName;
    }
    return map;
  }

  Future<void> clearAll() async {
    await _box?.clear();
    _clearedController.add(null);
  }

  Future<void> deleteNotification(String id) async {
    await _box?.delete(id);
  }

  int get totalCount => _box?.length ?? 0;
  int get deletedCount => _box?.values.where((n) => n.isRemoved).length ?? 0;
  int get ghostCount => _box?.values.where((n) => n.isGhostDelete).length ?? 0;
  int get favoriteCount => _box?.values.where((n) => n.isFavorite).length ?? 0;

  void dispose() {
    _subscription?.cancel();
    _notificationController.close();
    _removedController.close();
    _clearedController.close();
    _keywordHitController.close();
    _watchlistHitController.close();
  }
}
