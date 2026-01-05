// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_plan_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReadingPlanAdapter extends TypeAdapter<ReadingPlan> {
  @override
  final int typeId = 3;

  @override
  ReadingPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadingPlan(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      totalDays: fields[3] as int,
      category: fields[4] as String,
      days: (fields[5] as List).cast<ReadingDay>(),
      isBuiltIn: fields[6] as bool,
      imageAsset: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingPlan obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.totalDays)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.days)
      ..writeByte(6)
      ..write(obj.isBuiltIn)
      ..writeByte(7)
      ..write(obj.imageAsset);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingPlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReadingDayAdapter extends TypeAdapter<ReadingDay> {
  @override
  final int typeId = 4;

  @override
  ReadingDay read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadingDay(
      id: fields[0] as String,
      planId: fields[1] as String,
      dayNumber: fields[2] as int,
      passages: (fields[3] as List).cast<String>(),
      devotionalText: fields[4] as String?,
      theme: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingDay obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.planId)
      ..writeByte(2)
      ..write(obj.dayNumber)
      ..writeByte(3)
      ..write(obj.passages)
      ..writeByte(4)
      ..write(obj.devotionalText)
      ..writeByte(5)
      ..write(obj.theme);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingDayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserPlanProgressAdapter extends TypeAdapter<UserPlanProgress> {
  @override
  final int typeId = 5;

  @override
  UserPlanProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserPlanProgress(
      id: fields[0] as String,
      planId: fields[1] as String,
      startDate: fields[2] as DateTime,
      currentDay: fields[3] as int,
      completedDays: (fields[4] as List).cast<int>(),
      streakCount: fields[5] as int,
      lastCompletedDate: fields[6] as DateTime?,
      isActive: fields[7] as bool,
      pausedAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UserPlanProgress obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.planId)
      ..writeByte(2)
      ..write(obj.startDate)
      ..writeByte(3)
      ..write(obj.currentDay)
      ..writeByte(4)
      ..write(obj.completedDays)
      ..writeByte(5)
      ..write(obj.streakCount)
      ..writeByte(6)
      ..write(obj.lastCompletedDate)
      ..writeByte(7)
      ..write(obj.isActive)
      ..writeByte(8)
      ..write(obj.pausedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPlanProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
