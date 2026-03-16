import 'package:hive/hive.dart';

part 'captured_notification.g.dart';

@HiveType(typeId: 0)
class CapturedNotification extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String packageName;

  @HiveField(2)
  late String appName;

  @HiveField(3)
  late String title;

  @HiveField(4)
  late String text;

  @HiveField(5)
  late DateTime timestamp;

  @HiveField(6)
  bool isRemoved = false;

  @HiveField(7)
  DateTime? removedAt;

  @HiveField(8)
  String? bigText;

  @HiveField(9)
  String? subText;

  @HiveField(10)
  String? category;

  @HiveField(11)
  bool isGroupSummary = false;

  @HiveField(12)
  String? conversationTitle;

  bool get isWhatsApp => packageName == 'com.whatsapp' || packageName == 'com.whatsapp.w4b';
  bool get isTelegram => packageName == 'org.telegram.messenger';
  bool get isMessaging => isWhatsApp || isTelegram || packageName.contains('sms') || packageName.contains('messenger');
}
