import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bible_database.dart';
import 'models/bible_models.dart';

/// Repository for Bible data access
class BibleRepository {
  final BibleDatabase _database;

  BibleRepository(this._database);

  /// Check if Bible data is loaded
  Future<bool> hasData() => _database.hasData();

  /// Get verse count
  Future<int> getVerseCount() => _database.getVerseCount();

  /// Get all books
  List<BibleBook> getAllBooks() => BibleBooks.all;

  /// Get Old Testament books
  List<BibleBook> getOldTestament() => BibleBooks.oldTestament;

  /// Get New Testament books
  List<BibleBook> getNewTestament() => BibleBooks.newTestament;

  /// Get a book by ID
  BibleBook? getBook(int bookId) => BibleBooks.getById(bookId);

  /// Get a book by name
  BibleBook? getBookByName(String name) => BibleBooks.getByName(name);

  /// Get chapter count for a book
  int getChapterCount(int bookId) {
    final book = BibleBooks.getById(bookId);
    return book?.chapters ?? 0;
  }

  /// Get all verses for a chapter
  Future<BibleChapter> getChapter(int bookId, int chapter) async {
    final book = BibleBooks.getById(bookId);
    final verses = await _database.getChapter(bookId, chapter);

    return BibleChapter(
      bookId: bookId,
      bookName: book?.name ?? 'Unknown',
      chapter: chapter,
      verses: verses,
    );
  }

  /// Get a specific verse
  Future<BibleVerse?> getVerse(int bookId, int chapter, int verse) =>
    _database.getVerse(bookId, chapter, verse);

  /// Get a range of verses
  Future<List<BibleVerse>> getVerseRange(
    int bookId,
    int chapter,
    int startVerse,
    int endVerse,
  ) => _database.getVerseRange(bookId, chapter, startVerse, endVerse);

  /// Search verses by keyword
  Future<List<VerseSearchResult>> search(
    String query, {
    int? bookId,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      // Try FTS search first
      return await _database.searchVerses(query, bookId: bookId, limit: limit);
    } catch (e) {
      // Fall back to simple LIKE search
      return await _database.searchVersesSimple(query, bookId: bookId, limit: limit);
    }
  }

  /// Insert verses (for importing)
  Future<void> insertVerses(List<BibleVerse> verses) =>
    _database.insertVerses(verses);

  /// Clear all Bible data
  Future<void> clearAll() => _database.clearAll();
}

/// Provider for Bible database
final bibleDatabaseProvider = Provider<BibleDatabase>((ref) {
  return BibleDatabase.instance;
});

/// Provider for Bible repository
final bibleRepositoryProvider = Provider<BibleRepository>((ref) {
  final database = ref.watch(bibleDatabaseProvider);
  return BibleRepository(database);
});

/// Provider for checking if Bible data is loaded
final bibleDataLoadedProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(bibleRepositoryProvider);
  return repository.hasData();
});

/// Provider for getting a chapter
final chapterProvider = FutureProvider.family<BibleChapter, ({int bookId, int chapter})>(
  (ref, params) async {
    final repository = ref.watch(bibleRepositoryProvider);
    return repository.getChapter(params.bookId, params.chapter);
  },
);

/// Provider for search results
final searchResultsProvider = FutureProvider.family<List<VerseSearchResult>, String>(
  (ref, query) async {
    if (query.trim().isEmpty) return [];
    final repository = ref.watch(bibleRepositoryProvider);
    return repository.search(query);
  },
);
