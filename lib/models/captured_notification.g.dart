// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'captured_notification.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CapturedNotificationAdapter extends TypeAdapter<CapturedNotification> {
  @override
  final int typeId = 0;

  @override
  CapturedNotification read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CapturedNotification()
      ..id = fields[0] as String
      ..packageName = fields[1] as String
      ..appName = fields[2] as String
      ..title = fields[3] as String
      ..text = fields[4] as String
      ..timestamp = fields[5] as DateTime
      ..isRemoved = fields[6] as bool
      ..removedAt = fields[7] as DateTime?
      ..bigText = fields[8] as String?
      ..subText = fields[9] as String?
      ..category = fields[10] as String?
      ..isGroupSummary = fields[11] as bool
      ..conversationTitle = fields[12] as String?
      ..isFavorite = fields[13] as bool
      ..mediaType = fields[14] as String?
      ..isGhostDelete = fields[15] as bool;
  }

  @override
  void write(BinaryWriter writer, CapturedNotification obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.packageName)
      ..writeByte(2)
      ..write(obj.appName)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.text)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.isRemoved)
      ..writeByte(7)
      ..write(obj.removedAt)
      ..writeByte(8)
      ..write(obj.bigText)
      ..writeByte(9)
      ..write(obj.subText)
      ..writeByte(10)
      ..write(obj.category)
      ..writeByte(11)
      ..write(obj.isGroupSummary)
      ..writeByte(12)
      ..write(obj.conversationTitle)
      ..writeByte(13)
      ..write(obj.isFavorite)
      ..writeByte(14)
      ..write(obj.mediaType)
      ..writeByte(15)
      ..write(obj.isGhostDelete);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CapturedNotificationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
