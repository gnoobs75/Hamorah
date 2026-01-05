// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memorization_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MemoryVerseAdapter extends TypeAdapter<MemoryVerse> {
  @override
  final int typeId = 6;

  @override
  MemoryVerse read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MemoryVerse(
      id: fields[0] as String,
      bookId: fields[1] as int,
      chapter: fields[2] as int,
      verse: fields[3] as int,
      verseText: fields[4] as String,
      reference: fields[5] as String,
      addedAt: fields[6] as DateTime?,
      repetitions: fields[7] as int,
      easeFactor: fields[8] as double,
      interval: fields[9] as int,
      nextReviewDate: fields[10] as DateTime?,
      mastered: fields[11] as bool,
      correctStreak: fields[12] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, MemoryVerse obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.chapter)
      ..writeByte(3)
      ..write(obj.verse)
      ..writeByte(4)
      ..write(obj.verseText)
      ..writeByte(5)
      ..write(obj.reference)
      ..writeByte(6)
      ..write(obj.addedAt)
      ..writeByte(7)
      ..write(obj.repetitions)
      ..writeByte(8)
      ..write(obj.easeFactor)
      ..writeByte(9)
      ..write(obj.interval)
      ..writeByte(10)
      ..write(obj.nextReviewDate)
      ..writeByte(11)
      ..write(obj.mastered)
      ..writeByte(12)
      ..write(obj.correctStreak);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryVerseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReviewSessionAdapter extends TypeAdapter<ReviewSession> {
  @override
  final int typeId = 7;

  @override
  ReviewSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReviewSession(
      id: fields[0] as String,
      date: fields[1] as DateTime?,
      versesReviewed: fields[2] as int,
      correctCount: fields[3] as int,
      durationSeconds: fields[4] as int,
      verseIds: (fields[5] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ReviewSession obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.versesReviewed)
      ..writeByte(3)
      ..write(obj.correctCount)
      ..writeByte(4)
      ..write(obj.durationSeconds)
      ..writeByte(5)
      ..write(obj.verseIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
