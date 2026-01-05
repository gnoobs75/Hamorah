import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/memorization/memorization_repository.dart';
import '../../../data/memorization/models/memorization_models.dart';

/// Provider for all memory verses
final allMemoryVersesProvider = Provider<List<MemoryVerse>>((ref) {
  final repo = ref.watch(memorizationRepositoryProvider);
  return repo.getAllVerses();
});

/// Provider for verses due for review
final dueVersesProvider = Provider<List<MemoryVerse>>((ref) {
  final repo = ref.watch(memorizationRepositoryProvider);
  return repo.getDueVerses();
});

/// Provider for new verses
final newVersesProvider = Provider<List<MemoryVerse>>((ref) {
  final repo = ref.watch(memorizationRepositoryProvider);
  return repo.getNewVerses();
});

/// Provider for learning verses
final learningVersesProvider = Provider<List<MemoryVerse>>((ref) {
  final repo = ref.watch(memorizationRepositoryProvider);
  return repo.getLearningVerses();
});

/// Provider for mastered verses
final masteredVersesProvider = Provider<List<MemoryVerse>>((ref) {
  final repo = ref.watch(memorizationRepositoryProvider);
  return repo.getMasteredVerses();
});

/// Provider for memorization stats
final memorizationStatsProvider = Provider<MemorizationStats>((ref) {
  final repo = ref.watch(memorizationRepositoryProvider);
  return MemorizationStats(
    totalVerses: repo.totalVersesCount,
    dueCount: repo.dueCount,
    masteredCount: repo.masteredCount,
    averageMastery: repo.averageMastery,
    streak: repo.getStreak(),
    totalMinutes: repo.totalReviewMinutes,
  );
});

/// Stats model
class MemorizationStats {
  final int totalVerses;
  final int dueCount;
  final int masteredCount;
  final double averageMastery;
  final int streak;
  final int totalMinutes;

  const MemorizationStats({
    required this.totalVerses,
    required this.dueCount,
    required this.masteredCount,
    required this.averageMastery,
    required this.streak,
    required this.totalMinutes,
  });
}

/// Practice session state
class PracticeSessionState {
  final List<MemoryVerse> verses;
  final int currentIndex;
  final bool showingAnswer;
  final PracticeMode mode;
  final DateTime startTime;
  final int correctCount;
  final Map<String, ResponseQuality> responses;

  const PracticeSessionState({
    required this.verses,
    this.currentIndex = 0,
    this.showingAnswer = false,
    this.mode = PracticeMode.flashcard,
    required this.startTime,
    this.correctCount = 0,
    this.responses = const {},
  });

  MemoryVerse? get currentVerse {
    if (currentIndex >= 0 && currentIndex < verses.length) {
      return verses[currentIndex];
    }
    return null;
  }

  bool get isComplete => currentIndex >= verses.length;

  int get remaining => verses.length - currentIndex;

  double get progress {
    if (verses.isEmpty) return 0;
    return currentIndex / verses.length;
  }

  Duration get elapsed => DateTime.now().difference(startTime);

  PracticeSessionState copyWith({
    List<MemoryVerse>? verses,
    int? currentIndex,
    bool? showingAnswer,
    PracticeMode? mode,
    DateTime? startTime,
    int? correctCount,
    Map<String, ResponseQuality>? responses,
  }) {
    return PracticeSessionState(
      verses: verses ?? this.verses,
      currentIndex: currentIndex ?? this.currentIndex,
      showingAnswer: showingAnswer ?? this.showingAnswer,
      mode: mode ?? this.mode,
      startTime: startTime ?? this.startTime,
      correctCount: correctCount ?? this.correctCount,
      responses: responses ?? this.responses,
    );
  }
}

/// Practice session notifier
class PracticeSessionNotifier extends StateNotifier<PracticeSessionState?> {
  final MemorizationRepository _repository;

  PracticeSessionNotifier(this._repository) : super(null);

  /// Start a new practice session
  void startSession(List<MemoryVerse> verses, {PracticeMode mode = PracticeMode.flashcard}) {
    if (verses.isEmpty) return;

    // Shuffle verses for variety
    final shuffled = List<MemoryVerse>.from(verses)..shuffle();

    state = PracticeSessionState(
      verses: shuffled,
      mode: mode,
      startTime: DateTime.now(),
    );
  }

  /// Show the answer
  void showAnswer() {
    if (state == null) return;
    state = state!.copyWith(showingAnswer: true);
  }

  /// Process response and move to next
  Future<void> processResponse(ResponseQuality quality) async {
    if (state == null || state!.currentVerse == null) return;

    final verse = state!.currentVerse!;
    await _repository.processResponse(verse.id, quality);

    final newResponses = Map<String, ResponseQuality>.from(state!.responses);
    newResponses[verse.id] = quality;

    final isCorrect = quality.value >= 3;

    state = state!.copyWith(
      currentIndex: state!.currentIndex + 1,
      showingAnswer: false,
      correctCount: isCorrect ? state!.correctCount + 1 : state!.correctCount,
      responses: newResponses,
    );
  }

  /// End the session
  Future<ReviewSession?> endSession() async {
    if (state == null) return null;

    final session = ReviewSession(
      id: DateTime.now().toIso8601String(),
      versesReviewed: state!.currentIndex,
      correctCount: state!.correctCount,
      durationSeconds: state!.elapsed.inSeconds,
      verseIds: state!.responses.keys.toList(),
    );

    await _repository.endSession(session);
    state = null;
    return session;
  }

  /// Cancel the session
  void cancelSession() {
    state = null;
  }

  /// Change practice mode
  void changeMode(PracticeMode mode) {
    if (state == null) return;
    state = state!.copyWith(mode: mode);
  }
}

/// Provider for practice session
final practiceSessionProvider = StateNotifierProvider<PracticeSessionNotifier, PracticeSessionState?>((ref) {
  final repo = ref.watch(memorizationRepositoryProvider);
  return PracticeSessionNotifier(repo);
});

/// Memorization notifier for general actions
class MemorizationNotifier extends StateNotifier<AsyncValue<void>> {
  final MemorizationRepository _repository;
  final Ref _ref;

  MemorizationNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  /// Add a verse to memorize
  Future<MemoryVerse?> addVerse({
    required int bookId,
    required int chapter,
    required int verse,
    required String verseText,
    required String reference,
  }) async {
    state = const AsyncValue.loading();
    try {
      final memoryVerse = await _repository.addVerse(
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        verseText: verseText,
        reference: reference,
      );
      state = const AsyncValue.data(null);
      _ref.invalidateSelf();
      return memoryVerse;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Delete a verse
  Future<void> deleteVerse(String id) async {
    await _repository.deleteVerse(id);
    _ref.invalidateSelf();
  }

  /// Reset a verse
  Future<void> resetVerse(String id) async {
    await _repository.resetVerse(id);
    _ref.invalidateSelf();
  }

  /// Check if verse is already being memorized
  bool hasVerse(int bookId, int chapter, int verse) {
    return _repository.hasVerse(bookId, chapter, verse);
  }
}

/// Provider for memorization notifier
final memorizationNotifierProvider = StateNotifierProvider<MemorizationNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(memorizationRepositoryProvider);
  return MemorizationNotifier(repo, ref);
});
