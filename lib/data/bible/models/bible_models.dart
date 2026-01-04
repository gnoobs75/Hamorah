/// Bible data models for Hamorah

/// Represents a Bible translation
class BibleTranslation {
  final String id;           // 'KJV', 'ASV', 'WEB', etc.
  final String name;         // 'King James Version'
  final String abbreviation; // 'KJV'
  final String language;     // 'en'
  final bool isDownloaded;
  final int verseCount;
  final String licenseType;  // 'public_domain', 'commercial'

  const BibleTranslation({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.language,
    required this.isDownloaded,
    required this.verseCount,
    required this.licenseType,
  });

  bool get isPublicDomain => licenseType == 'public_domain';
}

/// Represents a book of the Bible
class BibleBook {
  final int id;           // 1-66
  final String name;      // "Genesis", "Matthew", etc.
  final String abbrev;    // "Gen", "Matt", etc.
  final String testament; // "OT" or "NT"
  final int chapters;     // Number of chapters in this book

  const BibleBook({
    required this.id,
    required this.name,
    required this.abbrev,
    required this.testament,
    required this.chapters,
  });

  factory BibleBook.fromMap(Map<String, dynamic> map) {
    return BibleBook(
      id: map['id'] as int,
      name: map['name'] as String,
      abbrev: map['abbrev'] as String,
      testament: map['testament'] as String,
      chapters: map['chapters'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'abbrev': abbrev,
      'testament': testament,
      'chapters': chapters,
    };
  }

  bool get isOldTestament => testament == 'OT';
  bool get isNewTestament => testament == 'NT';
}

/// Represents a single verse
class BibleVerse {
  final int id;
  final int bookId;
  final int chapter;
  final int verse;
  final String text;
  final String? bookName; // Optional, for display convenience

  const BibleVerse({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.text,
    this.bookName,
  });

  factory BibleVerse.fromMap(Map<String, dynamic> map) {
    return BibleVerse(
      id: map['id'] as int,
      bookId: map['book_id'] as int,
      chapter: map['chapter'] as int,
      verse: map['verse'] as int,
      text: map['text'] as String,
      bookName: map['book_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter': chapter,
      'verse': verse,
      'text': text,
    };
  }

  /// Returns reference like "John 3:16"
  String get reference {
    final book = bookName ?? 'Book $bookId';
    return '$book $chapter:$verse';
  }
}

/// Represents a chapter with all its verses
class BibleChapter {
  final int bookId;
  final String bookName;
  final int chapter;
  final List<BibleVerse> verses;

  const BibleChapter({
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verses,
  });

  String get reference => '$bookName $chapter';
  int get verseCount => verses.length;
}

/// Search result with context
class VerseSearchResult {
  final BibleVerse verse;
  final String bookName;
  final String matchedText; // The portion that matched
  final double? relevanceScore; // For semantic search

  const VerseSearchResult({
    required this.verse,
    required this.bookName,
    this.matchedText = '',
    this.relevanceScore,
  });

  String get reference => '${bookName} ${verse.chapter}:${verse.verse}';
}

/// All 66 books of the Bible with metadata
class BibleBooks {
  static const List<BibleBook> all = [
    // Old Testament (39 books)
    BibleBook(id: 1, name: 'Genesis', abbrev: 'Gen', testament: 'OT', chapters: 50),
    BibleBook(id: 2, name: 'Exodus', abbrev: 'Exod', testament: 'OT', chapters: 40),
    BibleBook(id: 3, name: 'Leviticus', abbrev: 'Lev', testament: 'OT', chapters: 27),
    BibleBook(id: 4, name: 'Numbers', abbrev: 'Num', testament: 'OT', chapters: 36),
    BibleBook(id: 5, name: 'Deuteronomy', abbrev: 'Deut', testament: 'OT', chapters: 34),
    BibleBook(id: 6, name: 'Joshua', abbrev: 'Josh', testament: 'OT', chapters: 24),
    BibleBook(id: 7, name: 'Judges', abbrev: 'Judg', testament: 'OT', chapters: 21),
    BibleBook(id: 8, name: 'Ruth', abbrev: 'Ruth', testament: 'OT', chapters: 4),
    BibleBook(id: 9, name: '1 Samuel', abbrev: '1Sam', testament: 'OT', chapters: 31),
    BibleBook(id: 10, name: '2 Samuel', abbrev: '2Sam', testament: 'OT', chapters: 24),
    BibleBook(id: 11, name: '1 Kings', abbrev: '1Kgs', testament: 'OT', chapters: 22),
    BibleBook(id: 12, name: '2 Kings', abbrev: '2Kgs', testament: 'OT', chapters: 25),
    BibleBook(id: 13, name: '1 Chronicles', abbrev: '1Chr', testament: 'OT', chapters: 29),
    BibleBook(id: 14, name: '2 Chronicles', abbrev: '2Chr', testament: 'OT', chapters: 36),
    BibleBook(id: 15, name: 'Ezra', abbrev: 'Ezra', testament: 'OT', chapters: 10),
    BibleBook(id: 16, name: 'Nehemiah', abbrev: 'Neh', testament: 'OT', chapters: 13),
    BibleBook(id: 17, name: 'Esther', abbrev: 'Esth', testament: 'OT', chapters: 10),
    BibleBook(id: 18, name: 'Job', abbrev: 'Job', testament: 'OT', chapters: 42),
    BibleBook(id: 19, name: 'Psalms', abbrev: 'Ps', testament: 'OT', chapters: 150),
    BibleBook(id: 20, name: 'Proverbs', abbrev: 'Prov', testament: 'OT', chapters: 31),
    BibleBook(id: 21, name: 'Ecclesiastes', abbrev: 'Eccl', testament: 'OT', chapters: 12),
    BibleBook(id: 22, name: 'Song of Solomon', abbrev: 'Song', testament: 'OT', chapters: 8),
    BibleBook(id: 23, name: 'Isaiah', abbrev: 'Isa', testament: 'OT', chapters: 66),
    BibleBook(id: 24, name: 'Jeremiah', abbrev: 'Jer', testament: 'OT', chapters: 52),
    BibleBook(id: 25, name: 'Lamentations', abbrev: 'Lam', testament: 'OT', chapters: 5),
    BibleBook(id: 26, name: 'Ezekiel', abbrev: 'Ezek', testament: 'OT', chapters: 48),
    BibleBook(id: 27, name: 'Daniel', abbrev: 'Dan', testament: 'OT', chapters: 12),
    BibleBook(id: 28, name: 'Hosea', abbrev: 'Hos', testament: 'OT', chapters: 14),
    BibleBook(id: 29, name: 'Joel', abbrev: 'Joel', testament: 'OT', chapters: 3),
    BibleBook(id: 30, name: 'Amos', abbrev: 'Amos', testament: 'OT', chapters: 9),
    BibleBook(id: 31, name: 'Obadiah', abbrev: 'Obad', testament: 'OT', chapters: 1),
    BibleBook(id: 32, name: 'Jonah', abbrev: 'Jonah', testament: 'OT', chapters: 4),
    BibleBook(id: 33, name: 'Micah', abbrev: 'Mic', testament: 'OT', chapters: 7),
    BibleBook(id: 34, name: 'Nahum', abbrev: 'Nah', testament: 'OT', chapters: 3),
    BibleBook(id: 35, name: 'Habakkuk', abbrev: 'Hab', testament: 'OT', chapters: 3),
    BibleBook(id: 36, name: 'Zephaniah', abbrev: 'Zeph', testament: 'OT', chapters: 3),
    BibleBook(id: 37, name: 'Haggai', abbrev: 'Hag', testament: 'OT', chapters: 2),
    BibleBook(id: 38, name: 'Zechariah', abbrev: 'Zech', testament: 'OT', chapters: 14),
    BibleBook(id: 39, name: 'Malachi', abbrev: 'Mal', testament: 'OT', chapters: 4),
    // New Testament (27 books)
    BibleBook(id: 40, name: 'Matthew', abbrev: 'Matt', testament: 'NT', chapters: 28),
    BibleBook(id: 41, name: 'Mark', abbrev: 'Mark', testament: 'NT', chapters: 16),
    BibleBook(id: 42, name: 'Luke', abbrev: 'Luke', testament: 'NT', chapters: 24),
    BibleBook(id: 43, name: 'John', abbrev: 'John', testament: 'NT', chapters: 21),
    BibleBook(id: 44, name: 'Acts', abbrev: 'Acts', testament: 'NT', chapters: 28),
    BibleBook(id: 45, name: 'Romans', abbrev: 'Rom', testament: 'NT', chapters: 16),
    BibleBook(id: 46, name: '1 Corinthians', abbrev: '1Cor', testament: 'NT', chapters: 16),
    BibleBook(id: 47, name: '2 Corinthians', abbrev: '2Cor', testament: 'NT', chapters: 13),
    BibleBook(id: 48, name: 'Galatians', abbrev: 'Gal', testament: 'NT', chapters: 6),
    BibleBook(id: 49, name: 'Ephesians', abbrev: 'Eph', testament: 'NT', chapters: 6),
    BibleBook(id: 50, name: 'Philippians', abbrev: 'Phil', testament: 'NT', chapters: 4),
    BibleBook(id: 51, name: 'Colossians', abbrev: 'Col', testament: 'NT', chapters: 4),
    BibleBook(id: 52, name: '1 Thessalonians', abbrev: '1Thess', testament: 'NT', chapters: 5),
    BibleBook(id: 53, name: '2 Thessalonians', abbrev: '2Thess', testament: 'NT', chapters: 3),
    BibleBook(id: 54, name: '1 Timothy', abbrev: '1Tim', testament: 'NT', chapters: 6),
    BibleBook(id: 55, name: '2 Timothy', abbrev: '2Tim', testament: 'NT', chapters: 4),
    BibleBook(id: 56, name: 'Titus', abbrev: 'Titus', testament: 'NT', chapters: 3),
    BibleBook(id: 57, name: 'Philemon', abbrev: 'Phlm', testament: 'NT', chapters: 1),
    BibleBook(id: 58, name: 'Hebrews', abbrev: 'Heb', testament: 'NT', chapters: 13),
    BibleBook(id: 59, name: 'James', abbrev: 'Jas', testament: 'NT', chapters: 5),
    BibleBook(id: 60, name: '1 Peter', abbrev: '1Pet', testament: 'NT', chapters: 5),
    BibleBook(id: 61, name: '2 Peter', abbrev: '2Pet', testament: 'NT', chapters: 3),
    BibleBook(id: 62, name: '1 John', abbrev: '1John', testament: 'NT', chapters: 5),
    BibleBook(id: 63, name: '2 John', abbrev: '2John', testament: 'NT', chapters: 1),
    BibleBook(id: 64, name: '3 John', abbrev: '3John', testament: 'NT', chapters: 1),
    BibleBook(id: 65, name: 'Jude', abbrev: 'Jude', testament: 'NT', chapters: 1),
    BibleBook(id: 66, name: 'Revelation', abbrev: 'Rev', testament: 'NT', chapters: 22),
  ];

  static BibleBook? getById(int id) {
    try {
      return all.firstWhere((book) => book.id == id);
    } catch (_) {
      return null;
    }
  }

  static BibleBook? getByName(String name) {
    final lowerName = name.toLowerCase();
    try {
      return all.firstWhere(
        (book) => book.name.toLowerCase() == lowerName ||
                  book.abbrev.toLowerCase() == lowerName,
      );
    } catch (_) {
      return null;
    }
  }

  static List<BibleBook> get oldTestament =>
    all.where((book) => book.isOldTestament).toList();

  static List<BibleBook> get newTestament =>
    all.where((book) => book.isNewTestament).toList();
}
