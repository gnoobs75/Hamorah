import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';

import 'models/bible_models.dart';

/// Database service for Bible storage and retrieval
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
    // Use application support directory (more reliable on desktop)
    final appDir = await getApplicationSupportDirectory();

    // Create Hamorah subdirectory
    final hamorahDir = Directory(join(appDir.path, 'data'));
    if (!await hamorahDir.exists()) {
      await hamorahDir.create(recursive: true);
    }

    final path = join(hamorahDir.path, 'bible.db');

    // Open or create database
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create verses table
    await db.execute('''
      CREATE TABLE verses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        text TEXT NOT NULL,
        UNIQUE(book_id, chapter, verse)
      )
    ''');

    // Create index for fast lookups
    await db.execute('''
      CREATE INDEX idx_verses_book_chapter ON verses(book_id, chapter)
    ''');

    // Create full-text search table
    await db.execute('''
      CREATE VIRTUAL TABLE verses_fts USING fts5(
        text,
        content='verses',
        content_rowid='id'
      )
    ''');

    // Trigger to keep FTS in sync
    await db.execute('''
      CREATE TRIGGER verses_ai AFTER INSERT ON verses BEGIN
        INSERT INTO verses_fts(rowid, text) VALUES (new.id, new.text);
      END
    ''');
  }

  /// Check if Bible data is loaded
  Future<bool> hasData() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM verses');
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  /// Get verse count
  Future<int> getVerseCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM verses');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Insert a verse
  Future<void> insertVerse(BibleVerse verse) async {
    final db = await database;
    await db.insert(
      'verses',
      {
        'book_id': verse.bookId,
        'chapter': verse.chapter,
        'verse': verse.verse,
        'text': verse.text,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple verses in a batch
  Future<void> insertVerses(List<BibleVerse> verses) async {
    final db = await database;
    final batch = db.batch();

    for (final verse in verses) {
      batch.insert(
        'verses',
        {
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
  Future<List<BibleVerse>> getChapter(int bookId, int chapter) async {
    final db = await database;
    final results = await db.query(
      'verses',
      where: 'book_id = ? AND chapter = ?',
      whereArgs: [bookId, chapter],
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
  Future<BibleVerse?> getVerse(int bookId, int chapter, int verse) async {
    final db = await database;
    final results = await db.query(
      'verses',
      where: 'book_id = ? AND chapter = ? AND verse = ?',
      whereArgs: [bookId, chapter, verse],
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
    int endVerse,
  ) async {
    final db = await database;
    final results = await db.query(
      'verses',
      where: 'book_id = ? AND chapter = ? AND verse >= ? AND verse <= ?',
      whereArgs: [bookId, chapter, startVerse, endVerse],
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
        WHERE verses_fts MATCH ? AND v.book_id = ?
        ORDER BY rank
        LIMIT ?
      ''';
      args = ['"$query"', bookId, limit];
    } else {
      sql = '''
        SELECT v.id, v.book_id, v.chapter, v.verse, v.text
        FROM verses v
        JOIN verses_fts fts ON v.id = fts.rowid
        WHERE verses_fts MATCH ?
        ORDER BY rank
        LIMIT ?
      ''';
      args = ['"$query"', limit];
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
    int? bookId,
    int limit = 50,
  }) async {
    final db = await database;

    String whereClause = 'text LIKE ?';
    List<dynamic> args = ['%$query%'];

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
  Future<int> getChapterCount(int bookId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(chapter) as max_chapter FROM verses WHERE book_id = ?',
      [bookId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear all data (for reimporting)
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('verses');
    await db.execute('DELETE FROM verses_fts');
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
