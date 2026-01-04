import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'models/user_data_models.dart';

const _uuid = Uuid();

/// Repository for user data (bookmarks, highlights, notes)
class UserDataRepository {
  static const String _bookmarksBox = 'bookmarks';
  static const String _highlightsBox = 'highlights';
  static const String _notesBox = 'notes';

  // Singleton instance
  static UserDataRepository? _instance;
  static UserDataRepository get instance {
    _instance ??= UserDataRepository._();
    return _instance!;
  }

  UserDataRepository._();

  Box<Bookmark>? _bookmarks;
  Box<Highlight>? _highlights;
  Box<VerseNote>? _notes;

  bool _initialized = false;

  /// Initialize Hive boxes
  Future<void> initialize() async {
    if (_initialized) return;

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(BookmarkAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(HighlightAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(VerseNoteAdapter());
    }

    // Open boxes
    _bookmarks = await Hive.openBox<Bookmark>(_bookmarksBox);
    _highlights = await Hive.openBox<Highlight>(_highlightsBox);
    _notes = await Hive.openBox<VerseNote>(_notesBox);

    _initialized = true;
    debugPrint('UserDataRepository initialized');
  }

  // ============ BOOKMARKS ============

  /// Get all bookmarks
  List<Bookmark> getAllBookmarks() {
    return _bookmarks?.values.toList() ?? [];
  }

  /// Get bookmarks sorted by date (newest first)
  List<Bookmark> getBookmarksSorted() {
    final list = getAllBookmarks();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Check if verse is bookmarked
  bool isBookmarked(int bookId, int chapter, int verse) {
    return _bookmarks?.values.any((b) =>
        b.bookId == bookId && b.chapter == chapter && b.verse == verse) ?? false;
  }

  /// Get bookmark for a verse
  Bookmark? getBookmark(int bookId, int chapter, int verse) {
    try {
      return _bookmarks?.values.firstWhere((b) =>
          b.bookId == bookId && b.chapter == chapter && b.verse == verse);
    } catch (e) {
      return null;
    }
  }

  /// Add bookmark
  Future<Bookmark> addBookmark({
    required int bookId,
    required int chapter,
    required int verse,
    required String verseText,
    required String bookName,
    String? note,
    String? folder,
  }) async {
    final bookmark = Bookmark(
      id: _uuid.v4(),
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      verseText: verseText,
      bookName: bookName,
      createdAt: DateTime.now(),
      note: note,
      folder: folder,
    );

    await _bookmarks?.put(bookmark.id, bookmark);
    debugPrint('Added bookmark: ${bookmark.reference}');
    return bookmark;
  }

  /// Remove bookmark
  Future<void> removeBookmark(String id) async {
    await _bookmarks?.delete(id);
    debugPrint('Removed bookmark: $id');
  }

  /// Remove bookmark by verse
  Future<void> removeBookmarkByVerse(int bookId, int chapter, int verse) async {
    final bookmark = getBookmark(bookId, chapter, verse);
    if (bookmark != null) {
      await removeBookmark(bookmark.id);
    }
  }

  /// Update bookmark note
  Future<void> updateBookmarkNote(String id, String? note) async {
    final bookmark = _bookmarks?.get(id);
    if (bookmark != null) {
      bookmark.note = note;
      await bookmark.save();
    }
  }

  // ============ HIGHLIGHTS ============

  /// Get all highlights
  List<Highlight> getAllHighlights() {
    return _highlights?.values.toList() ?? [];
  }

  /// Get highlights for a chapter
  List<Highlight> getHighlightsForChapter(int bookId, int chapter) {
    return _highlights?.values
        .where((h) => h.bookId == bookId && h.chapter == chapter)
        .toList() ?? [];
  }

  /// Get highlight for a verse
  Highlight? getHighlight(int bookId, int chapter, int verse) {
    try {
      return _highlights?.values.firstWhere((h) =>
          h.bookId == bookId && h.chapter == chapter && h.verse == verse);
    } catch (e) {
      return null;
    }
  }

  /// Check if verse is highlighted
  bool isHighlighted(int bookId, int chapter, int verse) {
    return getHighlight(bookId, chapter, verse) != null;
  }

  /// Add or update highlight
  Future<Highlight> addHighlight({
    required int bookId,
    required int chapter,
    required int verse,
    required String verseText,
    required String bookName,
    HighlightColor color = HighlightColor.yellow,
  }) async {
    // Remove existing highlight if any
    final existing = getHighlight(bookId, chapter, verse);
    if (existing != null) {
      await removeHighlight(existing.id);
    }

    final highlight = Highlight(
      id: _uuid.v4(),
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      verseText: verseText,
      bookName: bookName,
      createdAt: DateTime.now(),
      colorIndex: color.index,
    );

    await _highlights?.put(highlight.id, highlight);
    debugPrint('Added highlight: ${highlight.reference} (${color.name})');
    return highlight;
  }

  /// Remove highlight
  Future<void> removeHighlight(String id) async {
    await _highlights?.delete(id);
    debugPrint('Removed highlight: $id');
  }

  /// Remove highlight by verse
  Future<void> removeHighlightByVerse(int bookId, int chapter, int verse) async {
    final highlight = getHighlight(bookId, chapter, verse);
    if (highlight != null) {
      await removeHighlight(highlight.id);
    }
  }

  /// Update highlight color
  Future<void> updateHighlightColor(String id, HighlightColor color) async {
    final highlight = _highlights?.get(id);
    if (highlight != null) {
      highlight.colorIndex = color.index;
      await highlight.save();
    }
  }

  // ============ NOTES ============

  /// Get all notes
  List<VerseNote> getAllNotes() {
    return _notes?.values.toList() ?? [];
  }

  /// Get notes sorted by date (newest first)
  List<VerseNote> getNotesSorted() {
    final list = getAllNotes();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Get note for a verse
  VerseNote? getNote(int bookId, int chapter, int verse) {
    try {
      return _notes?.values.firstWhere((n) =>
          n.bookId == bookId && n.chapter == chapter && n.verse == verse);
    } catch (e) {
      return null;
    }
  }

  /// Check if verse has a note
  bool hasNote(int bookId, int chapter, int verse) {
    return getNote(bookId, chapter, verse) != null;
  }

  /// Add or update note
  Future<VerseNote> saveNote({
    required int bookId,
    required int chapter,
    required int verse,
    required String bookName,
    required String content,
  }) async {
    final existing = getNote(bookId, chapter, verse);
    final now = DateTime.now();

    if (existing != null) {
      existing.content = content;
      existing.updatedAt = now;
      await existing.save();
      debugPrint('Updated note: ${existing.reference}');
      return existing;
    }

    final note = VerseNote(
      id: _uuid.v4(),
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      bookName: bookName,
      content: content,
      createdAt: now,
      updatedAt: now,
    );

    await _notes?.put(note.id, note);
    debugPrint('Added note: ${note.reference}');
    return note;
  }

  /// Remove note
  Future<void> removeNote(String id) async {
    await _notes?.delete(id);
    debugPrint('Removed note: $id');
  }

  // ============ UTILITY ============

  /// Clear all user data
  Future<void> clearAll() async {
    await _bookmarks?.clear();
    await _highlights?.clear();
    await _notes?.clear();
    debugPrint('Cleared all user data');
  }

  /// Close all boxes
  Future<void> close() async {
    await _bookmarks?.close();
    await _highlights?.close();
    await _notes?.close();
  }
}

/// Provider for user data repository
final userDataRepositoryProvider = Provider<UserDataRepository>((ref) {
  return UserDataRepository.instance;
});

/// Provider for all bookmarks
final bookmarksProvider = Provider<List<Bookmark>>((ref) {
  final repo = ref.watch(userDataRepositoryProvider);
  return repo.getBookmarksSorted();
});

/// Provider for all highlights
final highlightsProvider = Provider<List<Highlight>>((ref) {
  final repo = ref.watch(userDataRepositoryProvider);
  return repo.getAllHighlights();
});

/// Provider for all notes
final notesProvider = Provider<List<VerseNote>>((ref) {
  final repo = ref.watch(userDataRepositoryProvider);
  return repo.getNotesSorted();
});

/// Provider for highlights in a specific chapter
final chapterHighlightsProvider = Provider.family<List<Highlight>, ({int bookId, int chapter})>(
  (ref, params) {
    final repo = ref.watch(userDataRepositoryProvider);
    return repo.getHighlightsForChapter(params.bookId, params.chapter);
  },
);
