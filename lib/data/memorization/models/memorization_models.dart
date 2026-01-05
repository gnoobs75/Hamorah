import 'package:hive/hive.dart';

part 'memorization_models.g.dart';

/// A verse being memorized
@HiveType(typeId: 6)
class MemoryVerse extends HiveObject {
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
  final String reference;

  @HiveField(6)
  DateTime addedAt;

  @HiveField(7)
  int repetitions;

  @HiveField(8)
  double easeFactor; // SM-2 ease factor (starts at 2.5)

  @HiveField(9)
  int interval; // Days until next review

  @HiveField(10)
  DateTime? nextReviewDate;

  @HiveField(11)
  bool mastered;

  @HiveField(12)
  int correctStreak; // Consecutive correct answers

  MemoryVerse({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.verseText,
    required this.reference,
    DateTime? addedAt,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.interval = 0,
    this.nextReviewDate,
    this.mastered = false,
    this.correctStreak = 0,
  }) : addedAt = addedAt ?? DateTime.now();

  /// Apply SM-2 algorithm based on quality of response
  /// quality: 0-2 = fail, 3 = hard, 4 = good, 5 = easy
  void processResponse(int quality) {
    if (quality < 3) {
      // Failed - reset
      repetitions = 0;
      interval = 1;
      correctStreak = 0;
    } else {
      // Success
      correctStreak++;
      if (repetitions == 0) {
        interval = 1;
      } else if (repetitions == 1) {
        interval = 6;
      } else {
        interval = (interval * easeFactor).round();
      }
      repetitions++;
    }

    // Update ease factor
    easeFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (easeFactor < 1.3) easeFactor = 1.3;

    // Set next review date
    nextReviewDate = DateTime.now().add(Duration(days: interval));

    // Check if mastered (10+ correct in a row with interval > 21 days)
    if (correctStreak >= 10 && interval > 21) {
      mastered = true;
    }
  }

  /// Check if due for review
  bool get isDueForReview {
    if (nextReviewDate == null) return true;
    return DateTime.now().isAfter(nextReviewDate!);
  }

  /// Get mastery level (0-100)
  int get masteryLevel {
    if (mastered) return 100;
    if (repetitions == 0) return 0;

    // Calculate based on interval and correct streak
    final intervalScore = (interval / 30 * 50).clamp(0, 50);
    final streakScore = (correctStreak / 10 * 50).clamp(0, 50);
    return (intervalScore + streakScore).round();
  }

  /// Get status text
  String get statusText {
    if (mastered) return 'Mastered';
    if (repetitions == 0) return 'New';
    if (isDueForReview) return 'Due for review';
    return 'Learning';
  }

  MemoryVerse copyWith({
    String? id,
    int? bookId,
    int? chapter,
    int? verse,
    String? verseText,
    String? reference,
    DateTime? addedAt,
    int? repetitions,
    double? easeFactor,
    int? interval,
    DateTime? nextReviewDate,
    bool? mastered,
    int? correctStreak,
  }) {
    return MemoryVerse(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapter: chapter ?? this.chapter,
      verse: verse ?? this.verse,
      verseText: verseText ?? this.verseText,
      reference: reference ?? this.reference,
      addedAt: addedAt ?? this.addedAt,
      repetitions: repetitions ?? this.repetitions,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      mastered: mastered ?? this.mastered,
      correctStreak: correctStreak ?? this.correctStreak,
    );
  }
}

/// A review session record
@HiveType(typeId: 7)
class ReviewSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  int versesReviewed;

  @HiveField(3)
  int correctCount;

  @HiveField(4)
  int durationSeconds;

  @HiveField(5)
  List<String> verseIds;

  ReviewSession({
    required this.id,
    DateTime? date,
    this.versesReviewed = 0,
    this.correctCount = 0,
    this.durationSeconds = 0,
    List<String>? verseIds,
  })  : date = date ?? DateTime.now(),
        verseIds = verseIds ?? [];

  double get accuracy {
    if (versesReviewed == 0) return 0;
    return correctCount / versesReviewed;
  }

  String get durationDisplay {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}

/// Practice mode for memorization
enum PracticeMode {
  flashcard('Flashcard', 'See reference, recall verse'),
  fillBlank('Fill in the Blank', 'Complete missing words'),
  firstLetters('First Letters', 'Hints with first letters'),
  typing('Type It Out', 'Type the verse from memory');

  final String title;
  final String description;

  const PracticeMode(this.title, this.description);
}

/// Response quality for SM-2 algorithm
enum ResponseQuality {
  again(0, 'Again', 'Completely forgot'),
  hard(3, 'Hard', 'Recalled with difficulty'),
  good(4, 'Good', 'Recalled correctly'),
  easy(5, 'Easy', 'Perfect recall');

  final int value;
  final String label;
  final String description;

  const ResponseQuality(this.value, this.label, this.description);
}
