import 'dart:async';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';

import 'models/bible_models.dart';

/// Database service for Bible storage and retrieval
/// Supports multiple translations
class BibleDatabase {
  static BibleDatabase? _instance;
  static Database? _database;

  BibleDatabase._();

  static BibleDatabase get instance {
    _instance ??= BibleDatabase._();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final appDir = await getApplicationSupportDirectory();
    final hamorahDir = Directory(join(appDir.path, 'data'));
    if (!await hamorahDir.exists()) {
      await hamorahDir.create(recursive: true);
    }

    final path = join(hamorahDir.path, 'bible.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Translations table
    await db.execute('''
      CREATE TABLE translations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        abbreviation TEXT NOT NULL,
        language TEXT NOT NULL DEFAULT 'en',
        is_downloaded INTEGER NOT NULL DEFAULT 0,
        verse_count INTEGER NOT NULL DEFAULT 0,
        license_type TEXT NOT NULL DEFAULT 'public_domain'
      )
    ''');

    // Verses table with translation support
    await db.execute('''
      CREATE TABLE verses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        translation_id TEXT NOT NULL DEFAULT 'KJV',
        book_id INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        text TEXT NOT NULL,
        UNIQUE(translation_id, book_id, chapter, verse),
        FOREIGN KEY (translation_id) REFERENCES translations(id)
      )
    ''');

    // Indexes
    await db.execute('''
      CREATE INDEX idx_verses_translation_book_chapter
      ON verses(translation_id, book_id, chapter)
    ''');

    // Full-text search table
    await db.execute('''
      CREATE VIRTUAL TABLE verses_fts USING fts5(
        text,
        translation_id,
        content='verses',
        content_rowid='id'
      )
    ''');

    // Trigger to keep FTS in sync
    await db.execute('''
      CREATE TRIGGER verses_ai AFTER INSERT ON verses BEGIN
        INSERT INTO verses_fts(rowid, text, translation_id)
        VALUES (new.id, new.text, new.translation_id);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER verses_ad AFTER DELETE ON verses BEGIN
        INSERT INTO verses_fts(verses_fts, rowid, text, translation_id)
        VALUES('delete', old.id, old.text, old.translation_id);
      END
    ''');

    // Insert available translations
    await db.insert('translations', {
      'id': 'KJV',
      'name': 'King James Version',
      'abbreviation': 'KJV',
      'language': 'en',
      'is_downloaded': 0,
      'verse_count': 0,
      'license_type': 'public_domain',
    });

    await db.insert('translations', {
      'id': 'ASV',
      'name': 'American Standard Version',
      'abbreviation': 'ASV',
      'language': 'en',
      'is_downloaded': 0,
      'verse_count': 0,
      'license_type': 'public_domain',
    });

    await db.insert('translations', {
      'id': 'WEB',
      'name': 'World English Bible',
      'abbreviation': 'WEB',
      'language': 'en',
      'is_downloaded': 0,
      'verse_count': 0,
      'license_type': 'public_domain',
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration from v1 to v2 is complex - easier to recreate
      // Drop old tables and recreate with new schema
      await db.execute('DROP TABLE IF EXISTS verses_fts');
      await db.execute('DROP TABLE IF EXISTS verses');
      await db.execute('DROP TRIGGER IF EXISTS verses_ai');
      await db.execute('DROP TRIGGER IF EXISTS verses_ad');

      // Create new schema
      await _onCreate(db, newVersion);
    }
  }

  /// Get all available translations
  Future<List<BibleTranslation>> getTranslations() async {
    final db = await database;
    final results = await db.query('translations', orderBy: 'name');
    return results.map((map) => BibleTranslation(
      id: map['id'] as String,
      name: map['name'] as String,
      abbreviation: map['abbreviation'] as String,
      language: map['language'] as String,
      isDownloaded: (map['is_downloaded'] as int) == 1,
      verseCount: map['verse_count'] as int,
      licenseType: map['license_type'] as String,
    )).toList();
  }

  /// Get a specific translation
  Future<BibleTranslation?> getTranslation(String id) async {
    final db = await database;
    final results = await db.query('translations', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    final map = results.first;
    return BibleTranslation(
      id: map['id'] as String,
      name: map['name'] as String,
      abbreviation: map['abbreviation'] as String,
      language: map['language'] as String,
      isDownloaded: (map['is_downloaded'] as int) == 1,
      verseCount: map['verse_count'] as int,
      licenseType: map['license_type'] as String,
    );
  }

  /// Update translation download status
  Future<void> updateTranslationStatus(String id, bool isDownloaded, int verseCount) async {
    final db = await database;
    await db.update(
      'translations',
      {'is_downloaded': isDownloaded ? 1 : 0, 'verse_count': verseCount},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Check if translation has data
  Future<bool> hasData({String translationId = 'KJV'}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM verses WHERE translation_id = ?',
      [translationId],
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  /// Get verse count for a translation
  Future<int> getVerseCount({String translationId = 'KJV'}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM verses WHERE translation_id = ?',
      [translationId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Insert a verse
  Future<void> insertVerse(BibleVerse verse, {String translationId = 'KJV'}) async {
    final db = await database;
    await db.insert(
      'verses',
      {
        'translation_id': translationId,
        'book_id': verse.bookId,
        'chapter': verse.chapter,
        'verse': verse.verse,
        'text': verse.text,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple verses in a batch
  Future<void> insertVerses(List<BibleVerse> verses, {String translationId = 'KJV'}) async {
    final db = await database;
    final batch = db.batch();

    for (final verse in verses) {
      batch.insert(
        'verses',
        {
          'translation_id': translationId,
          'book_id': verse.bookId,
          'chapter': verse.chapter,
          'verse': verse.verse,
          'text': verse.text,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get all verses for a chapter
  Future<List<BibleVerse>> getChapter(int bookId, int chapter, {String translationId = 'KJV'}) async {
    final db = await database;
    final results = await db.query(
      'verses',
      where: 'translation_id = ? AND book_id = ? AND chapter = ?',
      whereArgs: [translationId, bookId, chapter],
      orderBy: 'verse ASC',
    );

    final book = BibleBooks.getById(bookId);
    return results.map((map) => BibleVerse(
      id: map['id'] as int,
      bookId: map['book_id'] as int,
      chapter: map['chapter'] as int,
      verse: map['verse'] as int,
      text: map['text'] as String,
      bookName: book?.name,
    )).toList();
  }

  /// Get a specific verse
  Future<BibleVerse?> getVerse(int bookId, int chapter, int verse, {String translationId = 'KJV'}) async {
    final db = await database;
    final results = await db.query(
      'verses',
      where: 'translation_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      whereArgs: [translationId, bookId, chapter, verse],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final book = BibleBooks.getById(bookId);
    final map = results.first;
    return BibleVerse(
      id: map['id'] as int,
      bookId: map['book_id'] as int,
      chapter: map['chapter'] as int,
      verse: map['verse'] as int,
      text: map['text'] as String,
      bookName: book?.name,
    );
  }

  /// Get a range of verses
  Future<List<BibleVerse>> getVerseRange(
    int bookId,
    int chapter,
    int startVerse,
    int endVerse, {
    String translationId = 'KJV',
  }) async {
    final db = await database;
    final results = await db.query(
      'verses',
      where: 'translation_id = ? AND book_id = ? AND chapter = ? AND verse >= ? AND verse <= ?',
      whereArgs: [translationId, bookId, chapter, startVerse, endVerse],
      orderBy: 'verse ASC',
    );

    final book = BibleBooks.getById(bookId);
    return results.map((map) => BibleVerse(
      id: map['id'] as int,
      bookId: map['book_id'] as int,
      chapter: map['chapter'] as int,
      verse: map['verse'] as int,
      text: map['text'] as String,
      bookName: book?.name,
    )).toList();
  }

  /// Search verses using full-text search
  Future<List<VerseSearchResult>> searchVerses(
    String query, {
    String translationId = 'KJV',
    int? bookId,
    int limit = 50,
  }) async {
    final db = await database;

    String sql;
    List<dynamic> args;

    if (bookId != null) {
      sql = '''
        SELECT v.id, v.book_id, v.chapter, v.verse, v.text
        FROM verses v
        JOIN verses_fts fts ON v.id = fts.rowid
        WHERE verses_fts MATCH ? AND v.book_id = ? AND v.translation_id = ?
        ORDER BY rank
        LIMIT ?
      ''';
      args = ['"$query"', bookId, translationId, limit];
    } else {
      sql = '''
        SELECT v.id, v.book_id, v.chapter, v.verse, v.text
        FROM verses v
        JOIN verses_fts fts ON v.id = fts.rowid
        WHERE verses_fts MATCH ? AND v.translation_id = ?
        ORDER BY rank
        LIMIT ?
      ''';
      args = ['"$query"', translationId, limit];
    }

    final results = await db.rawQuery(sql, args);

    return results.map((map) {
      final book = BibleBooks.getById(map['book_id'] as int);
      return VerseSearchResult(
        verse: BibleVerse(
          id: map['id'] as int,
          bookId: map['book_id'] as int,
          chapter: map['chapter'] as int,
          verse: map['verse'] as int,
          text: map['text'] as String,
          bookName: book?.name,
        ),
        bookName: book?.name ?? 'Unknown',
        matchedText: query,
      );
    }).toList();
  }

  /// Simple LIKE search (fallback if FTS fails)
  Future<List<VerseSearchResult>> searchVersesSimple(
    String query, {
    String translationId = 'KJV',
    int? bookId,
    int limit = 50,
  }) async {
    final db = await database;

    String whereClause = 'translation_id = ? AND text LIKE ?';
    List<dynamic> args = [translationId, '%$query%'];

    if (bookId != null) {
      whereClause += ' AND book_id = ?';
      args.add(bookId);
    }

    final results = await db.query(
      'verses',
      where: whereClause,
      whereArgs: args,
      limit: limit,
    );

    return results.map((map) {
      final book = BibleBooks.getById(map['book_id'] as int);
      return VerseSearchResult(
        verse: BibleVerse(
          id: map['id'] as int,
          bookId: map['book_id'] as int,
          chapter: map['chapter'] as int,
          verse: map['verse'] as int,
          text: map['text'] as String,
          bookName: book?.name,
        ),
        bookName: book?.name ?? 'Unknown',
        matchedText: query,
      );
    }).toList();
  }

  /// Get chapter count for a book
  Future<int> getChapterCount(int bookId, {String translationId = 'KJV'}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(chapter) as max_chapter FROM verses WHERE translation_id = ? AND book_id = ?',
      [translationId, bookId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear all data for a translation
  Future<void> clearTranslation(String translationId) async {
    final db = await database;
    await db.delete('verses', where: 'translation_id = ?', whereArgs: [translationId]);
    await updateTranslationStatus(translationId, false, 0);
  }

  /// Clear all data
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('verses');
    await db.execute('DELETE FROM verses_fts');
    await db.update('translations', {'is_downloaded': 0, 'verse_count': 0});
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
