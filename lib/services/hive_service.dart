import 'package:hive_flutter/hive_flutter.dart';
import 'package:notifspy/models/captured_notification.dart';

class HiveService {
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CapturedNotificationAdapter());
    await Hive.openBox<CapturedNotification>('notifications');
    await Hive.openBox('settings');
  }
}
