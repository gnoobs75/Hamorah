// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'devotional_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DevotionalPrefsAdapter extends TypeAdapter<DevotionalPrefs> {
  @override
  final int typeId = 9;

  @override
  DevotionalPrefs read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DevotionalPrefs(
      id: fields[0] as String,
      enabled: fields[1] as bool,
      reminderHour: fields[2] as int,
      reminderMinute: fields[3] as int,
      lastShownDate: fields[4] as DateTime?,
      viewedVerseIds: (fields[5] as List?)?.cast<String>(),
      includeReflection: fields[6] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, DevotionalPrefs obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.enabled)
      ..writeByte(2)
      ..write(obj.reminderHour)
      ..writeByte(3)
      ..write(obj.reminderMinute)
      ..writeByte(4)
      ..write(obj.lastShownDate)
      ..writeByte(5)
      ..write(obj.viewedVerseIds)
      ..writeByte(6)
      ..write(obj.includeReflection);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DevotionalPrefsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
