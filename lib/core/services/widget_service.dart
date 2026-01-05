import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../data/devotional/models/devotional_models.dart';
import '../../data/reading_plans/models/reading_plan_models.dart';

/// Service for managing home screen widgets
class WidgetService {
  static WidgetService? _instance;
  static WidgetService get instance {
    _instance ??= WidgetService._();
    return _instance!;
  }

  WidgetService._();

  // Widget identifiers
  static const String dailyVerseWidgetAndroid = 'DailyVerseWidget';
  static const String dailyVerseWidgetIOS = 'DailyVerseWidget';
  static const String readingPlanWidgetAndroid = 'ReadingPlanWidget';
  static const String readingPlanWidgetIOS = 'ReadingPlanWidget';

  // App group for iOS
  static const String appGroupId = 'group.com.hamorah.widgets';

  bool _isInitialized = false;

  /// Initialize the widget service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set app group for iOS
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }

      // Register interaction callback
      HomeWidget.widgetClicked.listen(_onWidgetClicked);

      _isInitialized = true;
      debugPrint('WidgetService initialized');
    } catch (e) {
      debugPrint('Error initializing WidgetService: $e');
    }
  }

  void _onWidgetClicked(Uri? uri) {
    if (uri == null) return;

    debugPrint('Widget clicked: $uri');

    // Handle deep links from widgets
    // Example: hamorah://devotional, hamorah://reading-plan/123
    final path = uri.path;
    final host = uri.host;

    // The app's main navigation should handle these routes
    // This is typically done via a global navigator key or routing service
    debugPrint('Widget navigation: host=$host, path=$path');
  }

  /// Update the daily verse widget
  Future<void> updateDailyVerseWidget({
    required String verseReference,
    required String verseText,
    String? theme,
  }) async {
    try {
      await HomeWidget.saveWidgetData('verse_reference', verseReference);
      await HomeWidget.saveWidgetData('verse_text', verseText);
      await HomeWidget.saveWidgetData('verse_theme', theme ?? '');
      await HomeWidget.saveWidgetData('last_updated', DateTime.now().toIso8601String());

      // Update the widget
      if (Platform.isAndroid) {
        await HomeWidget.updateWidget(
          androidName: dailyVerseWidgetAndroid,
          qualifiedAndroidName: 'com.hamorah.widgets.$dailyVerseWidgetAndroid',
        );
      } else if (Platform.isIOS) {
        await HomeWidget.updateWidget(iOSName: dailyVerseWidgetIOS);
      }

      debugPrint('Daily verse widget updated');
    } catch (e) {
      debugPrint('Error updating daily verse widget: $e');
    }
  }

  /// Update the reading plan widget
  Future<void> updateReadingPlanWidget({
    required String planName,
    required int currentDay,
    required int totalDays,
    required String todayReading,
    required double progress,
  }) async {
    try {
      await HomeWidget.saveWidgetData('plan_name', planName);
      await HomeWidget.saveWidgetData('current_day', currentDay);
      await HomeWidget.saveWidgetData('total_days', totalDays);
      await HomeWidget.saveWidgetData('today_reading', todayReading);
      await HomeWidget.saveWidgetData('progress', progress);
      await HomeWidget.saveWidgetData('last_updated', DateTime.now().toIso8601String());

      // Update the widget
      if (Platform.isAndroid) {
        await HomeWidget.updateWidget(
          androidName: readingPlanWidgetAndroid,
          qualifiedAndroidName: 'com.hamorah.widgets.$readingPlanWidgetAndroid',
        );
      } else if (Platform.isIOS) {
        await HomeWidget.updateWidget(iOSName: readingPlanWidgetIOS);
      }

      debugPrint('Reading plan widget updated');
    } catch (e) {
      debugPrint('Error updating reading plan widget: $e');
    }
  }

  /// Update widgets with current data
  Future<void> updateAllWidgets({
    DailyDevotional? devotional,
    UserPlanProgress? activeProgress,
    ReadingPlan? activePlan,
  }) async {
    // Update daily verse widget
    if (devotional != null) {
      await updateDailyVerseWidget(
        verseReference: devotional.verseReference,
        verseText: devotional.verseText,
        theme: devotional.theme,
      );
    }

    // Update reading plan widget
    if (activeProgress != null && activePlan != null) {
      final currentDay = activePlan.days[activeProgress.currentDay - 1];
      await updateReadingPlanWidget(
        planName: activePlan.name,
        currentDay: activeProgress.currentDay,
        totalDays: activePlan.totalDays,
        todayReading: currentDay.passagesDisplay,
        progress: activeProgress.getProgressPercent(activePlan.totalDays),
      );
    }
  }

  /// Check if widgets are supported
  Future<bool> isWidgetSupported() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return true;
    }
    return false;
  }

  /// Request widget pin (Android only)
  Future<bool> requestWidgetPin(String widgetName) async {
    if (!Platform.isAndroid) return false;

    try {
      await HomeWidget.requestPinWidget(
        androidName: widgetName,
        qualifiedAndroidName: 'com.hamorah.widgets.$widgetName',
      );
      return true;
    } catch (e) {
      debugPrint('Error requesting widget pin: $e');
      return false;
    }
  }

  /// Get initial widget URI (for handling launch from widget)
  Future<Uri?> getInitialUri() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (e) {
      debugPrint('Error getting initial URI: $e');
      return null;
    }
  }
}

/// Provider for widget service
final widgetServiceProvider = Provider<WidgetService>((ref) {
  return WidgetService.instance;
});

/// Widget configuration for settings
class WidgetConfig {
  final bool dailyVerseEnabled;
  final bool readingPlanEnabled;
  final String? selectedPlanId;

  const WidgetConfig({
    this.dailyVerseEnabled = true,
    this.readingPlanEnabled = true,
    this.selectedPlanId,
  });

  WidgetConfig copyWith({
    bool? dailyVerseEnabled,
    bool? readingPlanEnabled,
    String? selectedPlanId,
  }) {
    return WidgetConfig(
      dailyVerseEnabled: dailyVerseEnabled ?? this.dailyVerseEnabled,
      readingPlanEnabled: readingPlanEnabled ?? this.readingPlanEnabled,
      selectedPlanId: selectedPlanId ?? this.selectedPlanId,
    );
  }
}
