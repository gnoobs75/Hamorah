import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'models/reading_plan_models.dart';

/// Repository for managing reading plans and user progress
class ReadingPlanRepository {
  static ReadingPlanRepository? _instance;
  static ReadingPlanRepository get instance {
    _instance ??= ReadingPlanRepository._();
    return _instance!;
  }

  ReadingPlanRepository._();

  static const String _plansBoxName = 'reading_plans';
  static const String _progressBoxName = 'reading_plan_progress';

  Box<ReadingPlan>? _plansBox;
  Box<UserPlanProgress>? _progressBox;
  List<ReadingPlan>? _builtInPlans;

  bool _isInitialized = false;

  /// Initialize the repository
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Register adapters
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ReadingPlanAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ReadingDayAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(UserPlanProgressAdapter());
    }

    // Open boxes
    _plansBox = await Hive.openBox<ReadingPlan>(_plansBoxName);
    _progressBox = await Hive.openBox<UserPlanProgress>(_progressBoxName);

    // Load built-in plans
    await _loadBuiltInPlans();

    _isInitialized = true;
    debugPrint('ReadingPlanRepository initialized');
  }

  Future<void> _loadBuiltInPlans() async {
    try {
      final planFiles = [
        'assets/reading_plans/bible_in_year.json',
        'assets/reading_plans/gospels_30_days.json',
        'assets/reading_plans/psalms_month.json',
        'assets/reading_plans/new_testament_90.json',
      ];

      _builtInPlans = [];

      for (final file in planFiles) {
        try {
          final jsonStr = await rootBundle.loadString(file);
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final plan = ReadingPlan.fromJson(json);
          _builtInPlans!.add(plan);
          debugPrint('Loaded reading plan: ${plan.name}');
        } catch (e) {
          debugPrint('Error loading plan $file: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading built-in plans: $e');
      _builtInPlans = [];
    }
  }

  /// Get all available reading plans (built-in + custom)
  List<ReadingPlan> getAllPlans() {
    final customPlans = _plansBox?.values.toList() ?? [];
    return [...(_builtInPlans ?? []), ...customPlans];
  }

  /// Get built-in plans only
  List<ReadingPlan> getBuiltInPlans() => _builtInPlans ?? [];

  /// Get custom plans only
  List<ReadingPlan> getCustomPlans() => _plansBox?.values.toList() ?? [];

  /// Get plans by category
  List<ReadingPlan> getPlansByCategory(String category) {
    return getAllPlans().where((p) => p.category == category).toList();
  }

  /// Get a specific plan by ID
  ReadingPlan? getPlan(String planId) {
    // Check built-in first
    final builtIn = _builtInPlans?.firstWhere(
      (p) => p.id == planId,
      orElse: () => throw StateError('Not found'),
    );
    if (builtIn != null) return builtIn;

    // Check custom plans
    return _plansBox?.values.firstWhere(
      (p) => p.id == planId,
      orElse: () => throw StateError('Not found'),
    );
  }

  /// Create a custom reading plan
  Future<ReadingPlan> createCustomPlan({
    required String name,
    required String description,
    required List<ReadingDay> days,
    String category = 'custom',
  }) async {
    final plan = ReadingPlan(
      id: const Uuid().v4(),
      name: name,
      description: description,
      totalDays: days.length,
      category: category,
      days: days,
      isBuiltIn: false,
    );

    await _plansBox?.put(plan.id, plan);
    return plan;
  }

  /// Delete a custom plan
  Future<void> deleteCustomPlan(String planId) async {
    await _plansBox?.delete(planId);
    // Also delete any progress for this plan
    final progress = _progressBox?.values.where((p) => p.planId == planId).toList();
    for (final p in progress ?? []) {
      await _progressBox?.delete(p.id);
    }
  }

  // ==================== Progress Management ====================

  /// Get all user progress records
  List<UserPlanProgress> getAllProgress() {
    return _progressBox?.values.toList() ?? [];
  }

  /// Get active plan progress
  List<UserPlanProgress> getActiveProgress() {
    return _progressBox?.values.where((p) => p.isActive).toList() ?? [];
  }

  /// Get progress for a specific plan
  UserPlanProgress? getProgress(String planId) {
    return _progressBox?.values.firstWhere(
      (p) => p.planId == planId && p.isActive,
      orElse: () => throw StateError('Not found'),
    );
  }

  /// Start a new reading plan
  Future<UserPlanProgress> startPlan(String planId, {DateTime? startDate}) async {
    // Deactivate any existing progress for this plan
    final existing = _progressBox?.values.where((p) => p.planId == planId).toList();
    for (final p in existing ?? []) {
      p.isActive = false;
      await p.save();
    }

    final progress = UserPlanProgress(
      id: const Uuid().v4(),
      planId: planId,
      startDate: startDate ?? DateTime.now(),
    );

    await _progressBox?.put(progress.id, progress);
    return progress;
  }

  /// Mark a day as completed
  Future<void> completeDay(String progressId, int dayNumber) async {
    final progress = _progressBox?.get(progressId);
    if (progress != null) {
      progress.completeDay(dayNumber);
      await progress.save();
    }
  }

  /// Pause a reading plan
  Future<void> pausePlan(String progressId) async {
    final progress = _progressBox?.get(progressId);
    if (progress != null) {
      progress.isActive = false;
      progress.pausedAt = DateTime.now();
      await progress.save();
    }
  }

  /// Resume a paused plan
  Future<void> resumePlan(String progressId) async {
    final progress = _progressBox?.get(progressId);
    if (progress != null) {
      progress.isActive = true;
      progress.pausedAt = null;
      await progress.save();
    }
  }

  /// Reset plan progress
  Future<void> resetProgress(String progressId) async {
    final progress = _progressBox?.get(progressId);
    if (progress != null) {
      progress.currentDay = 1;
      progress.completedDays.clear();
      progress.streakCount = 0;
      progress.lastCompletedDate = null;
      progress.startDate = DateTime.now();
      await progress.save();
    }
  }

  /// Delete progress
  Future<void> deleteProgress(String progressId) async {
    await _progressBox?.delete(progressId);
  }

  /// Get today's reading for active plans
  List<({ReadingPlan plan, UserPlanProgress progress, ReadingDay day})> getTodaysReadings() {
    final result = <({ReadingPlan plan, UserPlanProgress progress, ReadingDay day})>[];

    for (final progress in getActiveProgress()) {
      final plan = getPlan(progress.planId);
      if (plan != null && progress.currentDay <= plan.totalDays) {
        final day = plan.days[progress.currentDay - 1];
        result.add((plan: plan, progress: progress, day: day));
      }
    }

    return result;
  }

  /// Get reading for a specific day
  ReadingDay? getReadingForDay(String planId, int dayNumber) {
    final plan = getPlan(planId);
    if (plan != null && dayNumber > 0 && dayNumber <= plan.days.length) {
      return plan.days[dayNumber - 1];
    }
    return null;
  }

  /// Calculate streak for a progress
  int calculateStreak(UserPlanProgress progress) {
    if (progress.lastCompletedDate == null) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(
      progress.lastCompletedDate!.year,
      progress.lastCompletedDate!.month,
      progress.lastCompletedDate!.day,
    );

    final difference = today.difference(lastDate).inDays;

    // Streak is valid if completed today or yesterday
    if (difference <= 1) {
      return progress.streakCount;
    }

    // Streak is broken
    return 0;
  }
}

/// Provider for the reading plan repository
final readingPlanRepositoryProvider = Provider<ReadingPlanRepository>((ref) {
  return ReadingPlanRepository.instance;
});
