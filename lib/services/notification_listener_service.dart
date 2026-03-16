import 'dart:async';
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

  final _notificationController = StreamController<CapturedNotification>.broadcast();
  Stream<CapturedNotification> get onNotification => _notificationController.stream;

  final _removedController = StreamController<String>.broadcast();
  Stream<String> get onNotificationRemoved => _removedController.stream;

  final _clearedController = StreamController<void>.broadcast();
  Stream<void> get onCleared => _clearedController.stream;

  Future<void> init() async {
    _box = Hive.box<CapturedNotification>('notifications');
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
      ..conversationTitle = data['conversationTitle'] as String?;

    _box?.put(notif.id, notif);
    _notificationController.add(notif);
  }

  void _handleRemoved(Map<String, dynamic> data) {
    final key = data['key'] as String? ?? '';
    final packageName = data['packageName'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final text = data['text'] as String? ?? '';

    if (_box == null) return;

    // Find matching unremoved notifications
    final matches = _box!.values.where((n) =>
      !n.isRemoved &&
      n.packageName == packageName &&
      (title.isEmpty || n.title == title) &&
      (text.isEmpty || n.text == text)
    ).toList();

    for (final match in matches) {
      match.isRemoved = true;
      match.removedAt = DateTime.now();
      match.save();
    }

    if (matches.isNotEmpty) {
      _removedController.add(key);
    }
  }

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

  List<CapturedNotification> getWhatsAppOnly() {
    return getAllNotifications().where((n) => n.isWhatsApp).toList();
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

  void dispose() {
    _subscription?.cancel();
    _notificationController.close();
    _removedController.close();
    _clearedController.close();
  }
}
