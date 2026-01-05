import 'package:hive/hive.dart';

part 'pastors_notes_models.g.dart';

/// A sermon/worship service recording session
@HiveType(typeId: 20)
class SermonSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final List<String> transcriptSegmentIds;

  @HiveField(4)
  final List<String> annotatedVerseIds;

  @HiveField(5)
  String? notes;

  @HiveField(6)
  final int totalDurationMs;

  @HiveField(7)
  bool isComplete;

  SermonSession({
    required this.id,
    required this.title,
    required this.date,
    List<String>? transcriptSegmentIds,
    List<String>? annotatedVerseIds,
    this.notes,
    this.totalDurationMs = 0,
    this.isComplete = false,
  })  : transcriptSegmentIds = transcriptSegmentIds ?? [],
        annotatedVerseIds = annotatedVerseIds ?? [];

  Duration get totalDuration => Duration(milliseconds: totalDurationMs);

  SermonSession copyWith({
    String? id,
    String? title,
    DateTime? date,
    List<String>? transcriptSegmentIds,
    List<String>? annotatedVerseIds,
    String? notes,
    int? totalDurationMs,
    bool? isComplete,
  }) {
    return SermonSession(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      transcriptSegmentIds: transcriptSegmentIds ?? this.transcriptSegmentIds,
      annotatedVerseIds: annotatedVerseIds ?? this.annotatedVerseIds,
      notes: notes ?? this.notes,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

/// A segment of transcribed text
@HiveType(typeId: 21)
class TranscriptSegment extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String sessionId;

  @HiveField(2)
  final String text;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final int offsetFromStartMs;

  @HiveField(5)
  final List<String> detectedVerseRefs;

  TranscriptSegment({
    required this.id,
    required this.sessionId,
    required this.text,
    required this.timestamp,
    this.offsetFromStartMs = 0,
    List<String>? detectedVerseRefs,
  }) : detectedVerseRefs = detectedVerseRefs ?? [];

  Duration get offsetFromStart => Duration(milliseconds: offsetFromStartMs);
}

/// A detected Scripture reference with full verse text
@HiveType(typeId: 22)
class AnnotatedVerse extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String sessionId;

  @HiveField(2)
  final String reference;

  @HiveField(3)
  final String verseText;

  @HiveField(4)
  final String context;

  @HiveField(5)
  final int mentionedAtMs;

  @HiveField(6)
  String? userNote;

  AnnotatedVerse({
    required this.id,
    required this.sessionId,
    required this.reference,
    required this.verseText,
    required this.context,
    this.mentionedAtMs = 0,
    this.userNote,
  });

  Duration get mentionedAt => Duration(milliseconds: mentionedAtMs);
}

/// State for an active recording session
class ActiveSessionState {
  final SermonSession session;
  final List<TranscriptSegment> segments;
  final List<AnnotatedVerse> verses;
  final bool isListening;
  final bool isPaused;
  final Duration elapsed;

  const ActiveSessionState({
    required this.session,
    this.segments = const [],
    this.verses = const [],
    this.isListening = false,
    this.isPaused = false,
    this.elapsed = Duration.zero,
  });

  ActiveSessionState copyWith({
    SermonSession? session,
    List<TranscriptSegment>? segments,
    List<AnnotatedVerse>? verses,
    bool? isListening,
    bool? isPaused,
    Duration? elapsed,
  }) {
    return ActiveSessionState(
      session: session ?? this.session,
      segments: segments ?? this.segments,
      verses: verses ?? this.verses,
      isListening: isListening ?? this.isListening,
      isPaused: isPaused ?? this.isPaused,
      elapsed: elapsed ?? this.elapsed,
    );
  }
}
