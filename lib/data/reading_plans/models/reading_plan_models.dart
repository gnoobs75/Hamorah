import 'package:hive/hive.dart';

part 'reading_plan_models.g.dart';

/// A reading plan with daily passages
@HiveType(typeId: 3)
class ReadingPlan extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final int totalDays;

  @HiveField(4)
  final String category; // 'whole-bible', 'gospels', 'topical', 'custom'

  @HiveField(5)
  final List<ReadingDay> days;

  @HiveField(6)
  final bool isBuiltIn;

  @HiveField(7)
  final String? imageAsset;

  ReadingPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.totalDays,
    required this.category,
    required this.days,
    this.isBuiltIn = true,
    this.imageAsset,
  });

  factory ReadingPlan.fromJson(Map<String, dynamic> json) {
    final daysList = (json['days'] as List?)
        ?.asMap()
        .entries
        .map((entry) => ReadingDay.fromJson(
              entry.value as Map<String, dynamic>,
              json['id'] as String,
              entry.key + 1,
            ))
        .toList() ?? [];

    return ReadingPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      totalDays: json['totalDays'] as int,
      category: json['category'] as String,
      days: daysList,
      isBuiltIn: json['isBuiltIn'] as bool? ?? true,
      imageAsset: json['imageAsset'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'totalDays': totalDays,
    'category': category,
    'days': days.map((d) => d.toJson()).toList(),
    'isBuiltIn': isBuiltIn,
    'imageAsset': imageAsset,
  };
}

/// A single day in a reading plan
@HiveType(typeId: 4)
class ReadingDay extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String planId;

  @HiveField(2)
  final int dayNumber;

  @HiveField(3)
  final List<String> passages; // "Genesis 1-3", "Psalm 1"

  @HiveField(4)
  final String? devotionalText;

  @HiveField(5)
  final String? theme;

  ReadingDay({
    required this.id,
    required this.planId,
    required this.dayNumber,
    required this.passages,
    this.devotionalText,
    this.theme,
  });

  factory ReadingDay.fromJson(Map<String, dynamic> json, String planId, int dayNumber) {
    return ReadingDay(
      id: '${planId}_day_$dayNumber',
      planId: planId,
      dayNumber: dayNumber,
      passages: (json['passages'] as List).cast<String>(),
      devotionalText: json['devotionalText'] as String?,
      theme: json['theme'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'passages': passages,
    'devotionalText': devotionalText,
    'theme': theme,
  };

  /// Get a formatted display string for the passages
  String get passagesDisplay => passages.join(', ');
}

/// User's progress on a reading plan
@HiveType(typeId: 5)
class UserPlanProgress extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String planId;

  @HiveField(2)
  DateTime startDate;

  @HiveField(3)
  int currentDay;

  @HiveField(4)
  List<int> completedDays;

  @HiveField(5)
  int streakCount;

  @HiveField(6)
  DateTime? lastCompletedDate;

  @HiveField(7)
  bool isActive;

  @HiveField(8)
  DateTime? pausedAt;

  UserPlanProgress({
    required this.id,
    required this.planId,
    required this.startDate,
    this.currentDay = 1,
    List<int>? completedDays,
    this.streakCount = 0,
    this.lastCompletedDate,
    this.isActive = true,
    this.pausedAt,
  }) : completedDays = completedDays ?? [];

  /// Get progress percentage (0.0 to 1.0)
  double getProgressPercent(int totalDays) {
    if (totalDays == 0) return 0.0;
    return completedDays.length / totalDays;
  }

  /// Check if a specific day is completed
  bool isDayCompleted(int dayNumber) => completedDays.contains(dayNumber);

  /// Mark a day as completed
  void completeDay(int dayNumber) {
    if (!completedDays.contains(dayNumber)) {
      completedDays.add(dayNumber);
      completedDays.sort();

      // Update streak
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (lastCompletedDate != null) {
        final lastDate = DateTime(
          lastCompletedDate!.year,
          lastCompletedDate!.month,
          lastCompletedDate!.day,
        );
        final difference = today.difference(lastDate).inDays;

        if (difference == 1) {
          // Consecutive day
          streakCount++;
        } else if (difference > 1) {
          // Streak broken
          streakCount = 1;
        }
        // difference == 0 means same day, don't change streak
      } else {
        streakCount = 1;
      }

      lastCompletedDate = now;

      // Update current day to next uncompleted
      while (completedDays.contains(currentDay)) {
        currentDay++;
      }
    }
  }

  /// Get days remaining
  int getDaysRemaining(int totalDays) => totalDays - completedDays.length;

  /// Check if plan is complete
  bool isComplete(int totalDays) => completedDays.length >= totalDays;

  UserPlanProgress copyWith({
    String? id,
    String? planId,
    DateTime? startDate,
    int? currentDay,
    List<int>? completedDays,
    int? streakCount,
    DateTime? lastCompletedDate,
    bool? isActive,
    DateTime? pausedAt,
  }) {
    return UserPlanProgress(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      startDate: startDate ?? this.startDate,
      currentDay: currentDay ?? this.currentDay,
      completedDays: completedDays ?? List.from(this.completedDays),
      streakCount: streakCount ?? this.streakCount,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      isActive: isActive ?? this.isActive,
      pausedAt: pausedAt ?? this.pausedAt,
    );
  }
}

/// Category for organizing reading plans
enum PlanCategory {
  wholeBible('whole-bible', 'Whole Bible'),
  newTestament('new-testament', 'New Testament'),
  oldTestament('old-testament', 'Old Testament'),
  gospels('gospels', 'Gospels'),
  psalms('psalms', 'Psalms & Wisdom'),
  topical('topical', 'Topical'),
  custom('custom', 'Custom');

  final String id;
  final String displayName;

  const PlanCategory(this.id, this.displayName);

  static PlanCategory fromId(String id) {
    return PlanCategory.values.firstWhere(
      (c) => c.id == id,
      orElse: () => PlanCategory.custom,
    );
  }
}
