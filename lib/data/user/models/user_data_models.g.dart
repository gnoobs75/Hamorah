// GENERATED CODE - DO NOT MODIFY BY HAND
// Manual Hive TypeAdapters for user data models

part of 'user_data_models.dart';

class BookmarkAdapter extends TypeAdapter<Bookmark> {
  @override
  final int typeId = 0;

  @override
  Bookmark read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Bookmark(
      id: fields[0] as String,
      bookId: fields[1] as int,
      chapter: fields[2] as int,
      verse: fields[3] as int,
      verseText: fields[4] as String,
      bookName: fields[5] as String,
      createdAt: fields[6] as DateTime,
      note: fields[7] as String?,
      folder: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Bookmark obj) {
    writer
      ..writeByte(9)
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
      ..write(obj.bookName)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.note)
      ..writeByte(8)
      ..write(obj.folder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookmarkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HighlightAdapter extends TypeAdapter<Highlight> {
  @override
  final int typeId = 1;

  @override
  Highlight read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Highlight(
      id: fields[0] as String,
      bookId: fields[1] as int,
      chapter: fields[2] as int,
      verse: fields[3] as int,
      verseText: fields[4] as String,
      bookName: fields[5] as String,
      createdAt: fields[6] as DateTime,
      colorIndex: fields[7] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Highlight obj) {
    writer
      ..writeByte(8)
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
      ..write(obj.bookName)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.colorIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighlightAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class VerseNoteAdapter extends TypeAdapter<VerseNote> {
  @override
  final int typeId = 2;

  @override
  VerseNote read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VerseNote(
      id: fields[0] as String,
      bookId: fields[1] as int,
      chapter: fields[2] as int,
      verse: fields[3] as int,
      bookName: fields[4] as String,
      content: fields[5] as String,
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, VerseNote obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.chapter)
      ..writeByte(3)
      ..write(obj.verse)
      ..writeByte(4)
      ..write(obj.bookName)
      ..writeByte(5)
      ..write(obj.content)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerseNoteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
