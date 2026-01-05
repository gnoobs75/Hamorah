// Manual Hive TypeAdapters for Pastor's Notes models

part of 'pastors_notes_models.dart';

class SermonSessionAdapter extends TypeAdapter<SermonSession> {
  @override
  final int typeId = 20;

  @override
  SermonSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SermonSession(
      id: fields[0] as String,
      title: fields[1] as String,
      date: fields[2] as DateTime,
      transcriptSegmentIds: (fields[3] as List?)?.cast<String>() ?? [],
      annotatedVerseIds: (fields[4] as List?)?.cast<String>() ?? [],
      notes: fields[5] as String?,
      totalDurationMs: fields[6] as int? ?? 0,
      isComplete: fields[7] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, SermonSession obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.transcriptSegmentIds)
      ..writeByte(4)
      ..write(obj.annotatedVerseIds)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.totalDurationMs)
      ..writeByte(7)
      ..write(obj.isComplete);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SermonSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TranscriptSegmentAdapter extends TypeAdapter<TranscriptSegment> {
  @override
  final int typeId = 21;

  @override
  TranscriptSegment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TranscriptSegment(
      id: fields[0] as String,
      sessionId: fields[1] as String,
      text: fields[2] as String,
      timestamp: fields[3] as DateTime,
      offsetFromStartMs: fields[4] as int? ?? 0,
      detectedVerseRefs: (fields[5] as List?)?.cast<String>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, TranscriptSegment obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.text)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.offsetFromStartMs)
      ..writeByte(5)
      ..write(obj.detectedVerseRefs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranscriptSegmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AnnotatedVerseAdapter extends TypeAdapter<AnnotatedVerse> {
  @override
  final int typeId = 22;

  @override
  AnnotatedVerse read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AnnotatedVerse(
      id: fields[0] as String,
      sessionId: fields[1] as String,
      reference: fields[2] as String,
      verseText: fields[3] as String,
      context: fields[4] as String,
      mentionedAtMs: fields[5] as int? ?? 0,
      userNote: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AnnotatedVerse obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.reference)
      ..writeByte(3)
      ..write(obj.verseText)
      ..writeByte(4)
      ..write(obj.context)
      ..writeByte(5)
      ..write(obj.mentionedAtMs)
      ..writeByte(6)
      ..write(obj.userNote);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnotatedVerseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
