import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_service.dart';
import '../../../data/bible/bible_repository.dart';
import '../../../data/devotional/devotional_repository.dart';
import '../../../data/devotional/models/devotional_models.dart';

/// Provider for devotional preferences
final devotionalPrefsProvider = Provider<DevotionalPrefs>((ref) {
  final repo = ref.watch(devotionalRepositoryProvider);
  return repo.getPrefs();
});

/// Provider for today's devotional
final todaysDevotionalProvider = FutureProvider<DailyDevotional?>((ref) async {
  final devotionalRepo = ref.watch(devotionalRepositoryProvider);
  final bibleRepo = ref.watch(bibleRepositoryProvider);
  return devotionalRepo.getTodaysDevotional(bibleRepo);
});

/// Notifier for managing devotional state
class DevotionalNotifier extends StateNotifier<DevotionalState> {
  final DevotionalRepository _repository;
  final NotificationService _notifications;
  final Ref _ref;

  DevotionalNotifier(this._repository, this._notifications, this._ref)
      : super(DevotionalState(prefs: _repository.getPrefs()));

  /// Load today's devotional
  Future<void> loadTodaysDevotional() async {
    state = state.copyWith(isLoading: true);

    try {
      final bibleRepo = _ref.read(bibleRepositoryProvider);
      final devotional = await _repository.getTodaysDevotional(bibleRepo);

      state = state.copyWith(
        isLoading: false,
        devotional: devotional,
      );

      if (devotional != null) {
        await _repository.markTodayViewed(devotional.verseReference);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Enable devotional reminders
  Future<void> enableReminders(int hour, int minute) async {
    final prefs = _repository.getPrefs();
    prefs.enabled = true;
    prefs.reminderHour = hour;
    prefs.reminderMinute = minute;
    await prefs.save();

    // Request permissions and schedule
    await _notifications.requestPermissions();
    await _notifications.scheduleDailyDevotional(hour: hour, minute: minute);

    state = state.copyWith(prefs: prefs);
  }

  /// Disable devotional reminders
  Future<void> disableReminders() async {
    final prefs = _repository.getPrefs();
    prefs.enabled = false;
    await prefs.save();

    await _notifications.cancelDevotionalReminder();

    state = state.copyWith(prefs: prefs);
  }

  /// Update reminder time
  Future<void> updateReminderTime(int hour, int minute) async {
    final prefs = _repository.getPrefs();
    prefs.reminderHour = hour;
    prefs.reminderMinute = minute;
    await prefs.save();

    if (prefs.enabled) {
      await _notifications.scheduleDailyDevotional(hour: hour, minute: minute);
    }

    state = state.copyWith(prefs: prefs);
  }

  /// Toggle AI reflection
  Future<void> toggleReflection(bool include) async {
    final prefs = _repository.getPrefs();
    prefs.includeReflection = include;
    await prefs.save();

    state = state.copyWith(prefs: prefs);
  }

  /// Get a new verse (skip current)
  Future<void> getNewVerse() async {
    state = state.copyWith(isLoading: true);

    try {
      final bibleRepo = _ref.read(bibleRepositoryProvider);
      final devotional = await _repository.getTodaysDevotional(bibleRepo);

      state = state.copyWith(
        isLoading: false,
        devotional: devotional,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

/// State for devotional feature
class DevotionalState {
  final DevotionalPrefs prefs;
  final DailyDevotional? devotional;
  final bool isLoading;
  final String? error;

  const DevotionalState({
    required this.prefs,
    this.devotional,
    this.isLoading = false,
    this.error,
  });

  DevotionalState copyWith({
    DevotionalPrefs? prefs,
    DailyDevotional? devotional,
    bool? isLoading,
    String? error,
  }) {
    return DevotionalState(
      prefs: prefs ?? this.prefs,
      devotional: devotional ?? this.devotional,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Provider for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

/// Provider for devotional notifier
final devotionalNotifierProvider = StateNotifierProvider<DevotionalNotifier, DevotionalState>((ref) {
  final repo = ref.watch(devotionalRepositoryProvider);
  final notifications = ref.watch(notificationServiceProvider);
  return DevotionalNotifier(repo, notifications, ref);
});
