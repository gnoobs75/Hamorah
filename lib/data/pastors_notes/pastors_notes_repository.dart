import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'models/pastors_notes_models.dart';

const _uuid = Uuid();

/// Repository for managing Pastor's Notes sermon sessions
class PastorsNotesRepository {
  static const String _sessionsBox = 'sermon_sessions';
  static const String _segmentsBox = 'transcript_segments';
  static const String _versesBox = 'annotated_verses';

  // Singleton
  static PastorsNotesRepository? _instance;
  static PastorsNotesRepository get instance {
    _instance ??= PastorsNotesRepository._();
    return _instance!;
  }

  PastorsNotesRepository._();

  Box<SermonSession>? _sessions;
  Box<TranscriptSegment>? _segments;
  Box<AnnotatedVerse>? _verses;

  bool _initialized = false;

  /// Initialize Hive boxes
  Future<void> initialize() async {
    if (_initialized) return;

    // Register adapters
    if (!Hive.isAdapterRegistered(20)) {
      Hive.registerAdapter(SermonSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(21)) {
      Hive.registerAdapter(TranscriptSegmentAdapter());
    }
    if (!Hive.isAdapterRegistered(22)) {
      Hive.registerAdapter(AnnotatedVerseAdapter());
    }

    // Open boxes
    _sessions = await Hive.openBox<SermonSession>(_sessionsBox);
    _segments = await Hive.openBox<TranscriptSegment>(_segmentsBox);
    _verses = await Hive.openBox<AnnotatedVerse>(_versesBox);

    _initialized = true;
    debugPrint('PastorsNotesRepository initialized');
  }

  /// Create a new sermon session
  Future<SermonSession> createSession({String? title}) async {
    final session = SermonSession(
      id: _uuid.v4(),
      title: title ?? 'Sermon - ${DateTime.now().toString().split(' ')[0]}',
      date: DateTime.now(),
    );

    await _sessions?.put(session.id, session);
    debugPrint('Created new sermon session: ${session.id}');
    return session;
  }

  /// Get all sessions, sorted by date (newest first)
  List<SermonSession> getAllSessions() {
    final sessions = _sessions?.values.toList() ?? [];
    sessions.sort((a, b) => b.date.compareTo(a.date));
    return sessions;
  }

  /// Get a session by ID
  SermonSession? getSession(String sessionId) {
    return _sessions?.get(sessionId);
  }

  /// Update a session
  Future<void> updateSession(SermonSession session) async {
    await _sessions?.put(session.id, session);
  }

  /// Add a transcript segment to a session
  Future<TranscriptSegment> addSegment({
    required String sessionId,
    required String text,
    required int offsetFromStartMs,
    List<String>? detectedVerseRefs,
  }) async {
    final segment = TranscriptSegment(
      id: _uuid.v4(),
      sessionId: sessionId,
      text: text,
      timestamp: DateTime.now(),
      offsetFromStartMs: offsetFromStartMs,
      detectedVerseRefs: detectedVerseRefs,
    );

    await _segments?.put(segment.id, segment);

    // Add segment ID to session
    final session = _sessions?.get(sessionId);
    if (session != null) {
      session.transcriptSegmentIds.add(segment.id);
      await session.save();
    }

    return segment;
  }

  /// Get all segments for a session
  List<TranscriptSegment> getSegmentsForSession(String sessionId) {
    final session = _sessions?.get(sessionId);
    if (session == null) return [];

    final segments = <TranscriptSegment>[];
    for (final segmentId in session.transcriptSegmentIds) {
      final segment = _segments?.get(segmentId);
      if (segment != null) {
        segments.add(segment);
      }
    }

    segments.sort((a, b) => a.offsetFromStartMs.compareTo(b.offsetFromStartMs));
    return segments;
  }

  /// Add an annotated verse to a session
  Future<AnnotatedVerse> addAnnotatedVerse({
    required String sessionId,
    required String reference,
    required String verseText,
    required String context,
    required int mentionedAtMs,
  }) async {
    final verse = AnnotatedVerse(
      id: _uuid.v4(),
      sessionId: sessionId,
      reference: reference,
      verseText: verseText,
      context: context,
      mentionedAtMs: mentionedAtMs,
    );

    await _verses?.put(verse.id, verse);

    // Add verse ID to session
    final session = _sessions?.get(sessionId);
    if (session != null) {
      session.annotatedVerseIds.add(verse.id);
      await session.save();
    }

    return verse;
  }

  /// Get all annotated verses for a session
  List<AnnotatedVerse> getVersesForSession(String sessionId) {
    final session = _sessions?.get(sessionId);
    if (session == null) return [];

    final verses = <AnnotatedVerse>[];
    for (final verseId in session.annotatedVerseIds) {
      final verse = _verses?.get(verseId);
      if (verse != null) {
        verses.add(verse);
      }
    }

    verses.sort((a, b) => a.mentionedAtMs.compareTo(b.mentionedAtMs));
    return verses;
  }

  /// Update an annotated verse (e.g., add user note)
  Future<void> updateAnnotatedVerse(AnnotatedVerse verse) async {
    await _verses?.put(verse.id, verse);
  }

  /// Complete a session
  Future<void> completeSession(String sessionId, int totalDurationMs) async {
    final session = _sessions?.get(sessionId);
    if (session != null) {
      session.isComplete = true;
      await _sessions?.put(session.id, session.copyWith(
        isComplete: true,
        totalDurationMs: totalDurationMs,
      ));
    }
  }

  /// Delete a session and all its data
  Future<void> deleteSession(String sessionId) async {
    final session = _sessions?.get(sessionId);
    if (session != null) {
      // Delete all segments
      for (final segmentId in session.transcriptSegmentIds) {
        await _segments?.delete(segmentId);
      }
      // Delete all verses
      for (final verseId in session.annotatedVerseIds) {
        await _verses?.delete(verseId);
      }
      // Delete session
      await _sessions?.delete(sessionId);
    }
  }

  /// Get full transcript text for a session
  String getFullTranscript(String sessionId) {
    final segments = getSegmentsForSession(sessionId);
    return segments.map((s) => s.text).join(' ');
  }

  /// Search sessions by keyword
  List<SermonSession> searchSessions(String query) {
    final lowerQuery = query.toLowerCase();
    final sessions = getAllSessions();

    return sessions.where((session) {
      // Check title
      if (session.title.toLowerCase().contains(lowerQuery)) return true;

      // Check notes
      if (session.notes?.toLowerCase().contains(lowerQuery) ?? false) return true;

      // Check transcript segments
      final segments = getSegmentsForSession(session.id);
      for (final segment in segments) {
        if (segment.text.toLowerCase().contains(lowerQuery)) return true;
      }

      return false;
    }).toList();
  }

  /// Search sessions by verse reference
  List<SermonSession> searchByVerse(String reference) {
    final lowerRef = reference.toLowerCase();
    final sessions = getAllSessions();

    return sessions.where((session) {
      final verses = getVersesForSession(session.id);
      return verses.any((v) => v.reference.toLowerCase().contains(lowerRef));
    }).toList();
  }

  /// Clear all data
  Future<void> clearAll() async {
    await _segments?.clear();
    await _verses?.clear();
    await _sessions?.clear();
    debugPrint('Cleared all Pastor\'s Notes data');
  }
}

/// Provider for Pastor's Notes repository
final pastorsNotesRepositoryProvider = Provider<PastorsNotesRepository>((ref) {
  return PastorsNotesRepository.instance;
});
