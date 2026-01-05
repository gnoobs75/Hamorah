import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/reading_plans/models/reading_plan_models.dart';
import '../../../data/reading_plans/reading_plan_repository.dart';

/// Provider for all available reading plans
final allPlansProvider = Provider<List<ReadingPlan>>((ref) {
  final repo = ref.watch(readingPlanRepositoryProvider);
  return repo.getAllPlans();
});

/// Provider for plans by category
final plansByCategoryProvider = Provider.family<List<ReadingPlan>, String>((ref, category) {
  final repo = ref.watch(readingPlanRepositoryProvider);
  return repo.getPlansByCategory(category);
});

/// Provider for a specific plan
final planProvider = Provider.family<ReadingPlan?, String>((ref, planId) {
  final repo = ref.watch(readingPlanRepositoryProvider);
  try {
    return repo.getPlan(planId);
  } catch (e) {
    return null;
  }
});

/// Provider for all user progress
final allProgressProvider = Provider<List<UserPlanProgress>>((ref) {
  final repo = ref.watch(readingPlanRepositoryProvider);
  return repo.getAllProgress();
});

/// Provider for active plan progress
final activeProgressProvider = Provider<List<UserPlanProgress>>((ref) {
  final repo = ref.watch(readingPlanRepositoryProvider);
  return repo.getActiveProgress();
});

/// Provider for progress on a specific plan
final planProgressProvider = Provider.family<UserPlanProgress?, String>((ref, planId) {
  final repo = ref.watch(readingPlanRepositoryProvider);
  try {
    return repo.getProgress(planId);
  } catch (e) {
    return null;
  }
});

/// Provider for today's readings across all active plans
final todaysReadingsProvider = Provider<List<({ReadingPlan plan, UserPlanProgress progress, ReadingDay day})>>((ref) {
  final repo = ref.watch(readingPlanRepositoryProvider);
  return repo.getTodaysReadings();
});

/// Notifier for managing reading plan state
class ReadingPlanNotifier extends StateNotifier<AsyncValue<void>> {
  final ReadingPlanRepository _repository;
  final Ref _ref;

  ReadingPlanNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  /// Start a new reading plan
  Future<UserPlanProgress?> startPlan(String planId, {DateTime? startDate}) async {
    state = const AsyncValue.loading();
    try {
      final progress = await _repository.startPlan(planId, startDate: startDate);
      state = const AsyncValue.data(null);
      _ref.invalidateSelf();
      return progress;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Complete a day in a plan
  Future<void> completeDay(String progressId, int dayNumber) async {
    try {
      await _repository.completeDay(progressId, dayNumber);
      _ref.invalidateSelf();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Pause a plan
  Future<void> pausePlan(String progressId) async {
    try {
      await _repository.pausePlan(progressId);
      _ref.invalidateSelf();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Resume a plan
  Future<void> resumePlan(String progressId) async {
    try {
      await _repository.resumePlan(progressId);
      _ref.invalidateSelf();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Reset plan progress
  Future<void> resetProgress(String progressId) async {
    try {
      await _repository.resetProgress(progressId);
      _ref.invalidateSelf();
    } catch (e) {
      // Handle error silently
    }
  }

  /// Delete progress
  Future<void> deleteProgress(String progressId) async {
    try {
      await _repository.deleteProgress(progressId);
      _ref.invalidateSelf();
    } catch (e) {
      // Handle error silently
    }
  }
}

/// Provider for the reading plan notifier
final readingPlanNotifierProvider = StateNotifierProvider<ReadingPlanNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(readingPlanRepositoryProvider);
  return ReadingPlanNotifier(repo, ref);
});

/// Combined provider for plan with its progress
final planWithProgressProvider = Provider.family<({ReadingPlan? plan, UserPlanProgress? progress}), String>((ref, planId) {
  final plan = ref.watch(planProvider(planId));
  final progress = ref.watch(planProgressProvider(planId));
  return (plan: plan, progress: progress);
});
