import 'package:hive/hive.dart';

part 'devotional_models.g.dart';

/// User preferences for daily devotionals
@HiveType(typeId: 9)
class DevotionalPrefs extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  bool enabled;

  @HiveField(2)
  int reminderHour; // 0-23

  @HiveField(3)
  int reminderMinute;

  @HiveField(4)
  DateTime? lastShownDate;

  @HiveField(5)
  List<String> viewedVerseIds; // Track shown verses to avoid repeats

  @HiveField(6)
  bool includeReflection; // Whether to generate AI reflection

  DevotionalPrefs({
    required this.id,
    this.enabled = false,
    this.reminderHour = 7,
    this.reminderMinute = 0,
    this.lastShownDate,
    List<String>? viewedVerseIds,
    this.includeReflection = true,
  }) : viewedVerseIds = viewedVerseIds ?? [];

  /// Get the reminder time as TimeOfDay-like string
  String get reminderTimeString {
    final hour = reminderHour > 12 ? reminderHour - 12 : (reminderHour == 0 ? 12 : reminderHour);
    final period = reminderHour >= 12 ? 'PM' : 'AM';
    final minute = reminderMinute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  /// Check if we should show today's devotional
  bool get shouldShowToday {
    if (lastShownDate == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(lastShownDate!.year, lastShownDate!.month, lastShownDate!.day);
    return !today.isAtSameMomentAs(lastDate);
  }

  DevotionalPrefs copyWith({
    String? id,
    bool? enabled,
    int? reminderHour,
    int? reminderMinute,
    DateTime? lastShownDate,
    List<String>? viewedVerseIds,
    bool? includeReflection,
  }) {
    return DevotionalPrefs(
      id: id ?? this.id,
      enabled: enabled ?? this.enabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      lastShownDate: lastShownDate ?? this.lastShownDate,
      viewedVerseIds: viewedVerseIds ?? List.from(this.viewedVerseIds),
      includeReflection: includeReflection ?? this.includeReflection,
    );
  }
}

/// A daily devotional entry
class DailyDevotional {
  final String verseReference;
  final String verseText;
  final String? reflection;
  final DateTime date;
  final String? theme;

  const DailyDevotional({
    required this.verseReference,
    required this.verseText,
    this.reflection,
    required this.date,
    this.theme,
  });
}

/// Curated list of devotional verses
class DevotionalVerses {
  static const List<Map<String, dynamic>> verses = [
    // Trust and Faith
    {'ref': 'Proverbs 3:5-6', 'book': 20, 'chapter': 3, 'start': 5, 'end': 6, 'theme': 'Trust'},
    {'ref': 'Jeremiah 29:11', 'book': 24, 'chapter': 29, 'start': 11, 'theme': 'Hope'},
    {'ref': 'Isaiah 41:10', 'book': 23, 'chapter': 41, 'start': 10, 'theme': 'Courage'},
    {'ref': 'Romans 8:28', 'book': 45, 'chapter': 8, 'start': 28, 'theme': 'Providence'},
    {'ref': 'Philippians 4:13', 'book': 50, 'chapter': 4, 'start': 13, 'theme': 'Strength'},

    // Peace and Comfort
    {'ref': 'John 14:27', 'book': 43, 'chapter': 14, 'start': 27, 'theme': 'Peace'},
    {'ref': 'Matthew 11:28-30', 'book': 40, 'chapter': 11, 'start': 28, 'end': 30, 'theme': 'Rest'},
    {'ref': 'Psalm 23:1-4', 'book': 19, 'chapter': 23, 'start': 1, 'end': 4, 'theme': 'Comfort'},
    {'ref': 'Psalm 46:1-3', 'book': 19, 'chapter': 46, 'start': 1, 'end': 3, 'theme': 'Refuge'},
    {'ref': '2 Corinthians 1:3-4', 'book': 47, 'chapter': 1, 'start': 3, 'end': 4, 'theme': 'Comfort'},

    // Love and Grace
    {'ref': 'John 3:16', 'book': 43, 'chapter': 3, 'start': 16, 'theme': 'Love'},
    {'ref': 'Romans 5:8', 'book': 45, 'chapter': 5, 'start': 8, 'theme': 'Grace'},
    {'ref': '1 John 4:7-8', 'book': 62, 'chapter': 4, 'start': 7, 'end': 8, 'theme': 'Love'},
    {'ref': 'Ephesians 2:8-9', 'book': 49, 'chapter': 2, 'start': 8, 'end': 9, 'theme': 'Grace'},
    {'ref': 'Romans 8:38-39', 'book': 45, 'chapter': 8, 'start': 38, 'end': 39, 'theme': 'Love'},

    // Wisdom and Guidance
    {'ref': 'James 1:5', 'book': 59, 'chapter': 1, 'start': 5, 'theme': 'Wisdom'},
    {'ref': 'Psalm 119:105', 'book': 19, 'chapter': 119, 'start': 105, 'theme': 'Guidance'},
    {'ref': 'Proverbs 2:6', 'book': 20, 'chapter': 2, 'start': 6, 'theme': 'Wisdom'},
    {'ref': 'Isaiah 30:21', 'book': 23, 'chapter': 30, 'start': 21, 'theme': 'Guidance'},
    {'ref': 'Colossians 3:16', 'book': 51, 'chapter': 3, 'start': 16, 'theme': 'Wisdom'},

    // Joy and Praise
    {'ref': 'Philippians 4:4', 'book': 50, 'chapter': 4, 'start': 4, 'theme': 'Joy'},
    {'ref': 'Psalm 100:1-5', 'book': 19, 'chapter': 100, 'start': 1, 'end': 5, 'theme': 'Praise'},
    {'ref': 'Nehemiah 8:10', 'book': 16, 'chapter': 8, 'start': 10, 'theme': 'Joy'},
    {'ref': 'Psalm 118:24', 'book': 19, 'chapter': 118, 'start': 24, 'theme': 'Gratitude'},
    {'ref': '1 Thessalonians 5:16-18', 'book': 52, 'chapter': 5, 'start': 16, 'end': 18, 'theme': 'Joy'},

    // Strength and Perseverance
    {'ref': 'Isaiah 40:31', 'book': 23, 'chapter': 40, 'start': 31, 'theme': 'Strength'},
    {'ref': 'Joshua 1:9', 'book': 6, 'chapter': 1, 'start': 9, 'theme': 'Courage'},
    {'ref': 'Galatians 6:9', 'book': 48, 'chapter': 6, 'start': 9, 'theme': 'Perseverance'},
    {'ref': '2 Timothy 1:7', 'book': 55, 'chapter': 1, 'start': 7, 'theme': 'Power'},
    {'ref': 'Hebrews 12:1-2', 'book': 58, 'chapter': 12, 'start': 1, 'end': 2, 'theme': 'Faith'},

    // Prayer and Relationship
    {'ref': 'Jeremiah 33:3', 'book': 24, 'chapter': 33, 'start': 3, 'theme': 'Prayer'},
    {'ref': 'Matthew 7:7-8', 'book': 40, 'chapter': 7, 'start': 7, 'end': 8, 'theme': 'Prayer'},
    {'ref': 'John 15:5', 'book': 43, 'chapter': 15, 'start': 5, 'theme': 'Abiding'},
    {'ref': 'Psalm 27:4', 'book': 19, 'chapter': 27, 'start': 4, 'theme': 'Seeking God'},
    {'ref': '1 John 5:14-15', 'book': 62, 'chapter': 5, 'start': 14, 'end': 15, 'theme': 'Prayer'},

    // Forgiveness and Renewal
    {'ref': '1 John 1:9', 'book': 62, 'chapter': 1, 'start': 9, 'theme': 'Forgiveness'},
    {'ref': 'Psalm 51:10', 'book': 19, 'chapter': 51, 'start': 10, 'theme': 'Renewal'},
    {'ref': 'Isaiah 1:18', 'book': 23, 'chapter': 1, 'start': 18, 'theme': 'Forgiveness'},
    {'ref': 'Lamentations 3:22-23', 'book': 25, 'chapter': 3, 'start': 22, 'end': 23, 'theme': 'Mercy'},
    {'ref': '2 Corinthians 5:17', 'book': 47, 'chapter': 5, 'start': 17, 'theme': 'New Life'},

    // Purpose and Calling
    {'ref': 'Ephesians 2:10', 'book': 49, 'chapter': 2, 'start': 10, 'theme': 'Purpose'},
    {'ref': 'Romans 12:1-2', 'book': 45, 'chapter': 12, 'start': 1, 'end': 2, 'theme': 'Dedication'},
    {'ref': 'Micah 6:8', 'book': 33, 'chapter': 6, 'start': 8, 'theme': 'Justice'},
    {'ref': 'Matthew 5:14-16', 'book': 40, 'chapter': 5, 'start': 14, 'end': 16, 'theme': 'Witness'},
    {'ref': '1 Peter 2:9', 'book': 60, 'chapter': 2, 'start': 9, 'theme': 'Identity'},
  ];
}
