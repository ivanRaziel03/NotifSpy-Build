import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:notifspy/models/captured_notification.dart';

class NotificationListenerService with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.samandari.notifspy/listener');
  static const _eventChannel =
      EventChannel('com.samandari.notifspy/notifications');
  static final NotificationListenerService _instance =
      NotificationListenerService._();
  factory NotificationListenerService() => _instance;
  NotificationListenerService._();

  final _uuid = const Uuid();
  StreamSubscription? _subscription;
  Box<CapturedNotification>? _box;
  Box? _settingsBox;
  bool _initialized = false;
  int _reconnectAttempts = 0;
  static const _maxReconnectDelay = Duration(seconds: 30);

  final _notificationController =
      StreamController<CapturedNotification>.broadcast();
  Stream<CapturedNotification> get onNotification =>
      _notificationController.stream;

  final _removedController = StreamController<String>.broadcast();
  Stream<String> get onNotificationRemoved => _removedController.stream;

  final _clearedController = StreamController<void>.broadcast();
  Stream<void> get onCleared => _clearedController.stream;

  final _keywordHitController =
      StreamController<CapturedNotification>.broadcast();
  Stream<CapturedNotification> get onKeywordHit =>
      _keywordHitController.stream;

  final _watchlistHitController =
      StreamController<CapturedNotification>.broadcast();
  Stream<CapturedNotification> get onWatchlistHit =>
      _watchlistHitController.stream;

  final _recentPosts = <String, DateTime>{};

  static const _noisePatterns = [
    'checking for new messages',
    'you may have new messages',
    'waiting for this message',
    'message deleted',
    'this message was deleted',
    'messages you send to this',
    'tap for more info',
    'end-to-end encrypted',
  ];

  bool _isNoiseText(String text) {
    final lower = text.toLowerCase().trim();
    return _noisePatterns.any((p) => lower.contains(p));
  }

  CapturedNotification? _findByNotificationKey(String key) {
    if (_box == null) return null;
    try {
      return _box!.values.firstWhere((n) => n.notificationKey == key);
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _box = Hive.box<CapturedNotification>('notifications');
    _settingsBox = Hive.box('settings');
    WidgetsBinding.instance.addObserver(this);
    _connectToNativeStream();
    _initialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensureStreamConnected();
    }
  }

  void _connectToNativeStream() {
    _subscription?.cancel();
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      _onEvent,
      onError: _onStreamError,
      onDone: _onStreamDone,
    );
    _reconnectAttempts = 0;
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'] as String?;
    if (type == 'posted') {
      _handlePosted(Map<String, dynamic>.from(event));
    } else if (type == 'removed') {
      _handleRemoved(Map<String, dynamic>.from(event));
    }
  }

  void _onStreamError(dynamic error) {
    debugPrint('[NotifSpy] Stream error: $error');
    _scheduleReconnect();
  }

  void _onStreamDone() {
    debugPrint('[NotifSpy] Stream completed — scheduling reconnect');
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectAttempts++;
    final delayMs = (500 * (1 << _reconnectAttempts.clamp(0, 6)))
        .clamp(500, _maxReconnectDelay.inMilliseconds);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!_notificationController.isClosed) {
        _connectToNativeStream();
      }
    });
  }

  Future<void> _ensureStreamConnected() async {
    final running = await isServiceRunning();
    if (!running) {
      await rebindService();
    }
    _connectToNativeStream();
  }

  void _handlePosted(Map<String, dynamic> data) {
    final packageName = data['packageName'] as String? ?? '';
    if (packageName == 'com.samandari.notifspy') return;
    if (blacklistedApps.contains(packageName)) return;

    final title = data['title'] as String? ?? '';
    final text = data['text'] as String? ?? '';
    if (title.isEmpty && text.isEmpty) return;

    final isGroupSummary = data['isGroupSummary'] as bool? ?? false;
    if (isGroupSummary) return;

    final nKey = data['key'] as String?;
    final isNoise = _isNoiseText(text);

    final existing = nKey != null ? _findByNotificationKey(nKey) : null;
    if (existing != null) {
      if (isNoise) {
        existing.isRemoved = true;
        existing.removedAt = DateTime.now();
        existing.isGhostDelete =
            DateTime.now().difference(existing.timestamp).inSeconds < 30;
        existing.save();
        _removedController.add(nKey ?? '');
        return;
      }
      existing.originalText ??= existing.text;
      existing.text = text;
      existing.bigText = data['bigText'] as String?;
      existing.timestamp = DateTime.now();
      existing.save();
      _notificationController.add(existing);
      return;
    }

    if (isNoise) return;

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
      ..mediaType = _detectMediaType(text, data['bigText'] as String?)
      ..notificationKey = nKey;

    _box?.put(notif.id, notif);
    _notificationController.add(notif);

    final postKey = '$packageName|$title|$text';
    _recentPosts[postKey] = DateTime.now();
    Future.delayed(
      const Duration(seconds: 30),
      () => _recentPosts.remove(postKey),
    );

    _checkKeywords(notif);
    _checkWatchlist(notif);
  }

  void _handleRemoved(Map<String, dynamic> data) {
    final key = data['key'] as String? ?? '';
    final packageName = data['packageName'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final text = data['text'] as String? ?? '';

    if (_box == null) return;

    final byKey = key.isNotEmpty ? _findByNotificationKey(key) : null;

    List<CapturedNotification> matches;
    if (byKey != null && !byKey.isRemoved) {
      matches = [byKey];
    } else {
      matches = _box!.values
          .where((n) =>
              !n.isRemoved &&
              n.packageName == packageName &&
              (title.isEmpty || n.title == title) &&
              (text.isEmpty || _isNoiseText(text) || n.text == text))
          .toList();
    }

    final postKey = '$packageName|$title|${byKey?.text ?? text}';
    final postTime = _recentPosts[postKey];
    final isGhost =
        postTime != null && DateTime.now().difference(postTime).inSeconds < 10;

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

  String? _detectMediaType(String text, String? bigText) {
    final content = '$text ${bigText ?? ''}'.toLowerCase();
    if (content.contains('photo') ||
        content.contains('image') ||
        content.contains('\u{1F4F7}') ||
        content.contains('\u{1F5BC}')) {
      return 'photo';
    }
    if (content.contains('video') ||
        content.contains('\u{1F4F9}') ||
        content.contains('\u{1F3A5}')) {
      return 'video';
    }
    if (content.contains('voice message') ||
        content.contains('audio') ||
        content.contains('\u{1F3B5}') ||
        content.contains('\u{1F3A4}')) {
      return 'audio';
    }
    if (content.contains('document') ||
        content.contains('\u{1F4C4}') ||
        content.contains('\u{1F4CE}') ||
        content.contains('file')) {
      return 'document';
    }
    if (content.contains('sticker') || content.contains('gif')) {
      return 'sticker';
    }
    if (content.contains('location') || content.contains('\u{1F4CD}')) {
      return 'location';
    }
    if (content.contains('contact card') || content.contains('vcard')) {
      return 'contact';
    }
    return null;
  }

  // ===== Keyword Alerts =====
  List<String> get keywords {
    final raw = _settingsBox?.get('keywords');
    if (raw == null) return [];
    return (raw as List<dynamic>).cast<String>();
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
    final content =
        '${notif.title} ${notif.text} ${notif.bigText ?? ''}'.toLowerCase();
    for (final kw in kws) {
      if (content.contains(kw)) {
        _keywordHitController.add(notif);
        return;
      }
    }
  }

  // ===== Contact Watchlist =====
  List<String> get watchedContacts {
    final raw = _settingsBox?.get('watchedContacts');
    if (raw == null) return [];
    return (raw as List<dynamic>).cast<String>();
  }

  set watchedContacts(List<String> value) =>
      _settingsBox?.put('watchedContacts', value);

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
    final raw = _settingsBox?.get('blacklistedApps');
    if (raw == null) return [];
    return (raw as List<dynamic>).cast<String>();
  }

  set blacklistedApps(List<String> value) =>
      _settingsBox?.put('blacklistedApps', value);

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
  int get autoCleanupDays =>
      (_settingsBox?.get('autoCleanupDays') as int?) ?? 0;
  set autoCleanupDays(int value) =>
      _settingsBox?.put('autoCleanupDays', value);

  int get nightStartHour =>
      (_settingsBox?.get('nightStartHour') as int?) ?? 23;
  int get nightEndHour => (_settingsBox?.get('nightEndHour') as int?) ?? 7;
  set nightStartHour(int value) =>
      _settingsBox?.put('nightStartHour', value);
  set nightEndHour(int value) => _settingsBox?.put('nightEndHour', value);

  Future<int> runAutoCleanup() async {
    final days = autoCleanupDays;
    if (days <= 0 || _box == null) return 0;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final toDelete =
        _box!.values.where((n) => n.timestamp.isBefore(cutoff)).toList();
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
      _clearedController.add(null);
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
    return getAllNotifications()
        .where(
            (n) => n.timestamp.isAfter(nightStart) && n.timestamp.isBefore(nightEnd))
        .toList();
  }

  // ===== Export =====
  String exportAllToJson() {
    final data = getAllNotifications().map((n) => n.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'notifications': data,
      'exportedAt': DateTime.now().toIso8601String(),
    });
  }

  String exportThreadToText(String packageName, String contact) {
    final msgs =
        getByApp(packageName).where((n) => n.title == contact).toList();
    msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final buf = StringBuffer();
    buf.writeln('Thread: $contact');
    buf.writeln('App: ${msgs.isNotEmpty ? msgs.first.appName : packageName}');
    buf.writeln('Messages: ${msgs.length}');
    buf.writeln('---');
    for (final m in msgs) {
      final time =
          '${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}';
      final date =
          '${m.timestamp.year}-${m.timestamp.month.toString().padLeft(2, '0')}-${m.timestamp.day.toString().padLeft(2, '0')}';
      final deleted = m.isRemoved ? ' [DELETED]' : '';
      final ghost = m.isGhostDelete ? ' [GHOST]' : '';
      buf.writeln('[$date $time]$deleted$ghost ${m.text}');
    }
    return buf.toString();
  }

  // ===== Platform Queries =====
  Future<bool> isPermissionGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isPermissionGranted') ?? false;
    } on PlatformException catch (e) {
      debugPrint('[NotifSpy] Permission check error: $e');
      return false;
    }
  }

  Future<void> openPermissionSettings() async {
    try {
      await _channel.invokeMethod('openPermissionSettings');
    } on PlatformException catch (e) {
      debugPrint('[NotifSpy] Open settings error: $e');
    }
  }

  Future<bool> isServiceRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isServiceRunning') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isBatteryOptimized() async {
    try {
      return await _channel.invokeMethod<bool>('isBatteryOptimized') ?? true;
    } on PlatformException {
      return true;
    }
  }

  Future<void> requestBatteryOptimization() async {
    try {
      await _channel.invokeMethod('requestBatteryOptimization');
    } on PlatformException catch (e) {
      debugPrint('[NotifSpy] Battery optimization error: $e');
    }
  }

  Future<bool> rebindService() async {
    try {
      return await _channel.invokeMethod<bool>('rebindService') ?? false;
    } on PlatformException {
      return false;
    }
  }

  // ===== Data Queries =====
  List<CapturedNotification> getAllNotifications() {
    return (_box?.values.toList() ?? [])
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  List<CapturedNotification> getByApp(String packageName) {
    return getAllNotifications()
        .where((n) => n.packageName == packageName)
        .toList();
  }

  List<CapturedNotification> getDeletedOnly() {
    return getAllNotifications().where((n) => n.isRemoved).toList();
  }

  List<CapturedNotification> getGhostDeletes() {
    return getAllNotifications().where((n) => n.isGhostDelete).toList();
  }

  List<CapturedNotification> getByDateRange(DateTime start, DateTime end) {
    return getAllNotifications()
        .where((n) => n.timestamp.isAfter(start) && n.timestamp.isBefore(end))
        .toList();
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
  int get deletedCount =>
      _box?.values.where((n) => n.isRemoved).length ?? 0;
  int get ghostCount =>
      _box?.values.where((n) => n.isGhostDelete).length ?? 0;
  int get favoriteCount =>
      _box?.values.where((n) => n.isFavorite).length ?? 0;

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _notificationController.close();
    _removedController.close();
    _clearedController.close();
    _keywordHitController.close();
    _watchlistHitController.close();
  }
}
