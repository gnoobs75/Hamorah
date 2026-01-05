import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'models/memorization_models.dart';

/// Repository for managing verse memorization
class MemorizationRepository {
  static MemorizationRepository? _instance;
  static MemorizationRepository get instance {
    _instance ??= MemorizationRepository._();
    return _instance!;
  }

  MemorizationRepository._();

  static const String _versesBoxName = 'memory_verses';
  static const String _sessionsBoxName = 'review_sessions';

  Box<MemoryVerse>? _versesBox;
  Box<ReviewSession>? _sessionsBox;
  bool _isInitialized = false;

  /// Initialize the repository
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Register adapters
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(MemoryVerseAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(ReviewSessionAdapter());
    }

    // Open boxes
    _versesBox = await Hive.openBox<MemoryVerse>(_versesBoxName);
    _sessionsBox = await Hive.openBox<ReviewSession>(_sessionsBoxName);

    _isInitialized = true;
    debugPrint('MemorizationRepository initialized');
  }

  // ==================== Memory Verses ====================

  /// Get all memory verses
  List<MemoryVerse> getAllVerses() {
    return _versesBox?.values.toList() ?? [];
  }

  /// Get verses due for review
  List<MemoryVerse> getDueVerses() {
    return _versesBox?.values.where((v) => v.isDueForReview && !v.mastered).toList() ?? [];
  }

  /// Get new verses (never reviewed)
  List<MemoryVerse> getNewVerses() {
    return _versesBox?.values.where((v) => v.repetitions == 0).toList() ?? [];
  }

  /// Get mastered verses
  List<MemoryVerse> getMasteredVerses() {
    return _versesBox?.values.where((v) => v.mastered).toList() ?? [];
  }

  /// Get verses currently learning
  List<MemoryVerse> getLearningVerses() {
    return _versesBox?.values.where((v) => v.repetitions > 0 && !v.mastered).toList() ?? [];
  }

  /// Get a specific verse
  MemoryVerse? getVerse(String id) {
    return _versesBox?.get(id);
  }

  /// Add a verse to memorize
  Future<MemoryVerse> addVerse({
    required int bookId,
    required int chapter,
    required int verse,
    required String verseText,
    required String reference,
  }) async {
    final memoryVerse = MemoryVerse(
      id: const Uuid().v4(),
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      verseText: verseText,
      reference: reference,
    );

    await _versesBox?.put(memoryVerse.id, memoryVerse);
    return memoryVerse;
  }

  /// Check if a verse is already being memorized
  bool hasVerse(int bookId, int chapter, int verse) {
    return _versesBox?.values.any(
          (v) => v.bookId == bookId && v.chapter == chapter && v.verse == verse,
        ) ??
        false;
  }

  /// Process a response to a verse
  Future<void> processResponse(String verseId, ResponseQuality quality) async {
    final verse = _versesBox?.get(verseId);
    if (verse != null) {
      verse.processResponse(quality.value);
      await verse.save();
    }
  }

  /// Delete a verse
  Future<void> deleteVerse(String id) async {
    await _versesBox?.delete(id);
  }

  /// Reset a verse's progress
  Future<void> resetVerse(String id) async {
    final verse = _versesBox?.get(id);
    if (verse != null) {
      verse.repetitions = 0;
      verse.easeFactor = 2.5;
      verse.interval = 0;
      verse.nextReviewDate = null;
      verse.mastered = false;
      verse.correctStreak = 0;
      await verse.save();
    }
  }

  // ==================== Review Sessions ====================

  /// Get all review sessions
  List<ReviewSession> getAllSessions() {
    final sessions = _sessionsBox?.values.toList() ?? [];
    sessions.sort((a, b) => b.date.compareTo(a.date));
    return sessions;
  }

  /// Get recent sessions
  List<ReviewSession> getRecentSessions({int limit = 10}) {
    return getAllSessions().take(limit).toList();
  }

  /// Start a new review session
  ReviewSession startSession() {
    return ReviewSession(
      id: const Uuid().v4(),
    );
  }

  /// End and save a review session
  Future<void> endSession(ReviewSession session) async {
    await _sessionsBox?.put(session.id, session);
  }

  // ==================== Statistics ====================

  /// Get total verses count
  int get totalVersesCount => _versesBox?.length ?? 0;

  /// Get due count
  int get dueCount => getDueVerses().length;

  /// Get mastered count
  int get masteredCount => getMasteredVerses().length;

  /// Get average mastery level
  double get averageMastery {
    final verses = getAllVerses();
    if (verses.isEmpty) return 0;
    final total = verses.fold<int>(0, (sum, v) => sum + v.masteryLevel);
    return total / verses.length;
  }

  /// Get total review time (in minutes)
  int get totalReviewMinutes {
    final sessions = getAllSessions();
    final totalSeconds = sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
    return totalSeconds ~/ 60;
  }

  /// Get streak (consecutive days of practice)
  int getStreak() {
    final sessions = getAllSessions();
    if (sessions.isEmpty) return 0;

    int streak = 0;
    DateTime checkDate = DateTime.now();

    for (final session in sessions) {
      final sessionDate = DateTime(session.date.year, session.date.month, session.date.day);
      final targetDate = DateTime(checkDate.year, checkDate.month, checkDate.day);

      if (sessionDate.isAtSameMomentAs(targetDate)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (sessionDate.isBefore(targetDate)) {
        break;
      }
    }

    return streak;
  }
}

/// Provider for memorization repository
final memorizationRepositoryProvider = Provider<MemorizationRepository>((ref) {
  return MemorizationRepository.instance;
});
