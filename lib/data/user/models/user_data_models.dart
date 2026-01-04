import 'package:hive/hive.dart';

part 'user_data_models.g.dart';

/// Highlight color options
enum HighlightColor {
  yellow,
  green,
  blue,
  pink,
  orange,
}

/// Extension to get color values
extension HighlightColorExtension on HighlightColor {
  int get colorValue {
    switch (this) {
      case HighlightColor.yellow:
        return 0xFFFFF59D; // Yellow 200
      case HighlightColor.green:
        return 0xFFA5D6A7; // Green 200
      case HighlightColor.blue:
        return 0xFF90CAF9; // Blue 200
      case HighlightColor.pink:
        return 0xFFF48FB1; // Pink 200
      case HighlightColor.orange:
        return 0xFFFFCC80; // Orange 200
    }
  }
}

/// A bookmarked verse
@HiveType(typeId: 0)
class Bookmark extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int bookId;

  @HiveField(2)
  final int chapter;

  @HiveField(3)
  final int verse;

  @HiveField(4)
  final String verseText;

  @HiveField(5)
  final String bookName;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  String? note;

  @HiveField(8)
  String? folder;

  Bookmark({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.verseText,
    required this.bookName,
    required this.createdAt,
    this.note,
    this.folder,
  });

  String get reference => '$bookName $chapter:$verse';

  Bookmark copyWith({
    String? note,
    String? folder,
  }) {
    return Bookmark(
      id: id,
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      verseText: verseText,
      bookName: bookName,
      createdAt: createdAt,
      note: note ?? this.note,
      folder: folder ?? this.folder,
    );
  }
}

/// A highlighted verse
@HiveType(typeId: 1)
class Highlight extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int bookId;

  @HiveField(2)
  final int chapter;

  @HiveField(3)
  final int verse;

  @HiveField(4)
  final String verseText;

  @HiveField(5)
  final String bookName;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  int colorIndex; // Index into HighlightColor enum

  Highlight({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.verseText,
    required this.bookName,
    required this.createdAt,
    this.colorIndex = 0,
  });

  String get reference => '$bookName $chapter:$verse';

  HighlightColor get color => HighlightColor.values[colorIndex];

  Highlight copyWith({int? colorIndex}) {
    return Highlight(
      id: id,
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      verseText: verseText,
      bookName: bookName,
      createdAt: createdAt,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }
}

/// A note on a verse
@HiveType(typeId: 2)
class VerseNote extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int bookId;

  @HiveField(2)
  final int chapter;

  @HiveField(3)
  final int verse;

  @HiveField(4)
  final String bookName;

  @HiveField(5)
  String content;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  DateTime updatedAt;

  VerseNote({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.bookName,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  String get reference => '$bookName $chapter:$verse';
}
