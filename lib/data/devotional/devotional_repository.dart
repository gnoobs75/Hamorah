import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../bible/bible_repository.dart';
import 'models/devotional_models.dart';

/// Repository for managing daily devotionals
class DevotionalRepository {
  static DevotionalRepository? _instance;
  static DevotionalRepository get instance {
    _instance ??= DevotionalRepository._();
    return _instance!;
  }

  DevotionalRepository._();

  static const String _boxName = 'devotional_prefs';
  static const String _prefsKey = 'user_prefs';

  Box<DevotionalPrefs>? _box;
  bool _isInitialized = false;

  /// Initialize the repository
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Register adapter
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(DevotionalPrefsAdapter());
    }

    // Open box
    _box = await Hive.openBox<DevotionalPrefs>(_boxName);

    // Create default prefs if not exist
    if (!_box!.containsKey(_prefsKey)) {
      await _box!.put(_prefsKey, DevotionalPrefs(id: _prefsKey));
    }

    _isInitialized = true;
    debugPrint('DevotionalRepository initialized');
  }

  /// Get user's devotional preferences
  DevotionalPrefs getPrefs() {
    return _box?.get(_prefsKey) ?? DevotionalPrefs(id: _prefsKey);
  }

  /// Update devotional preferences
  Future<void> updatePrefs(DevotionalPrefs prefs) async {
    await _box?.put(_prefsKey, prefs);
  }

  /// Enable/disable devotional reminders
  Future<void> setEnabled(bool enabled) async {
    final prefs = getPrefs();
    prefs.enabled = enabled;
    await prefs.save();
  }

  /// Set reminder time
  Future<void> setReminderTime(int hour, int minute) async {
    final prefs = getPrefs();
    prefs.reminderHour = hour;
    prefs.reminderMinute = minute;
    await prefs.save();
  }

  /// Mark today's devotional as viewed
  Future<void> markTodayViewed(String verseRef) async {
    final prefs = getPrefs();
    prefs.lastShownDate = DateTime.now();
    if (!prefs.viewedVerseIds.contains(verseRef)) {
      prefs.viewedVerseIds.add(verseRef);
    }
    await prefs.save();
  }

  /// Get a random verse that hasn't been shown recently
  Map<String, dynamic>? getRandomVerse() {
    final prefs = getPrefs();
    final verses = DevotionalVerses.verses;

    // If all verses have been shown, reset the list
    if (prefs.viewedVerseIds.length >= verses.length) {
      prefs.viewedVerseIds.clear();
      prefs.save();
    }

    // Filter out recently viewed verses
    final availableVerses = verses.where(
      (v) => !prefs.viewedVerseIds.contains(v['ref'] as String),
    ).toList();

    if (availableVerses.isEmpty) {
      return verses[Random().nextInt(verses.length)];
    }

    return availableVerses[Random().nextInt(availableVerses.length)];
  }

  /// Get today's devotional
  Future<DailyDevotional?> getTodaysDevotional(BibleRepository bibleRepo) async {
    final verseData = getRandomVerse();
    if (verseData == null) return null;

    final ref = verseData['ref'] as String;
    final bookId = verseData['book'] as int;
    final chapter = verseData['chapter'] as int;
    final startVerse = verseData['start'] as int;
    final endVerse = verseData['end'] as int?;
    final theme = verseData['theme'] as String?;

    String? verseText;

    try {
      if (endVerse != null) {
        final verses = await bibleRepo.getVerseRange(bookId, chapter, startVerse, endVerse);
        verseText = verses.map((v) => v.text).join(' ');
      } else {
        final verse = await bibleRepo.getVerse(bookId, chapter, startVerse);
        verseText = verse?.text;
      }
    } catch (e) {
      debugPrint('Error fetching verse: $e');
    }

    if (verseText == null) {
      // Fallback text
      verseText = 'Trust in the LORD with all your heart, and do not lean on your own understanding. In all your ways acknowledge him, and he will make straight your paths.';
    }

    return DailyDevotional(
      verseReference: ref,
      verseText: verseText,
      date: DateTime.now(),
      theme: theme,
    );
  }
}

/// Provider for the devotional repository
final devotionalRepositoryProvider = Provider<DevotionalRepository>((ref) {
  return DevotionalRepository.instance;
});
