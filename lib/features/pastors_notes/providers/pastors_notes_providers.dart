import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/scripture/verse_detector_service.dart';
import '../../../core/speech/speech_recognition_service.dart';
import '../../../data/bible/bible_repository.dart';
import '../../../data/pastors_notes/models/pastors_notes_models.dart';
import '../../../data/pastors_notes/pastors_notes_repository.dart';

/// Provider for all sermon sessions
final sessionsProvider = FutureProvider<List<SermonSession>>((ref) async {
  final repo = ref.watch(pastorsNotesRepositoryProvider);
  return repo.getAllSessions();
});

/// Provider for a single session by ID
final sessionProvider = FutureProvider.family<SermonSession?, String>((ref, sessionId) async {
  final repo = ref.watch(pastorsNotesRepositoryProvider);
  return repo.getSession(sessionId);
});

/// Provider for segments of a session
final sessionSegmentsProvider = FutureProvider.family<List<TranscriptSegment>, String>((ref, sessionId) async {
  final repo = ref.watch(pastorsNotesRepositoryProvider);
  return repo.getSegmentsForSession(sessionId);
});

/// Provider for annotated verses of a session
final sessionVersesProvider = FutureProvider.family<List<AnnotatedVerse>, String>((ref, sessionId) async {
  final repo = ref.watch(pastorsNotesRepositoryProvider);
  return repo.getVersesForSession(sessionId);
});

/// Active session state notifier
class ActiveSessionNotifier extends StateNotifier<ActiveSessionState?> {
  final PastorsNotesRepository _repository;
  final BibleRepository _bibleRepository;
  final SpeechRecognitionService _speechService;
  final VerseDetectorService _verseDetector;

  Timer? _elapsedTimer;
  DateTime? _sessionStartTime;
  StreamSubscription<SpeechResult>? _speechSubscription;
  String _currentPartialText = '';

  ActiveSessionNotifier({
    required PastorsNotesRepository repository,
    required BibleRepository bibleRepository,
  })  : _repository = repository,
        _bibleRepository = bibleRepository,
        _speechService = SpeechRecognitionService.instance,
        _verseDetector = VerseDetectorService.instance,
        super(null);

  /// Start a new recording session
  Future<bool> startSession({String? title}) async {
    // Initialize speech recognition
    final speechAvailable = await _speechService.initialize();
    if (!speechAvailable) {
      debugPrint('Speech recognition not available');
      return false;
    }

    // Create new session
    final session = await _repository.createSession(title: title);

    _sessionStartTime = DateTime.now();
    state = ActiveSessionState(
      session: session,
      isListening: true,
    );

    // Start the elapsed timer
    _startElapsedTimer();

    // Subscribe to speech results
    _speechSubscription?.cancel();
    _speechSubscription = _speechService.results.listen(_onSpeechResult);

    // Start listening
    final started = await _speechService.startListening();
    if (!started) {
      state = state?.copyWith(isListening: false);
      return false;
    }

    return true;
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state != null && _sessionStartTime != null) {
        final elapsed = DateTime.now().difference(_sessionStartTime!);
        state = state!.copyWith(elapsed: elapsed);
      }
    });
  }

  void _onSpeechResult(SpeechResult result) async {
    if (state == null) return;

    if (result.isFinal) {
      // Save the final segment
      await _saveSegment(result.text);
      _currentPartialText = '';
    } else {
      // Update partial text display
      _currentPartialText = result.text;
    }
  }

  Future<void> _saveSegment(String text) async {
    if (state == null || text.trim().isEmpty) return;

    final elapsed = state!.elapsed;

    // Detect verse references
    final references = _verseDetector.detectReferences(text);
    final verseRefs = references.map((r) => r.reference).toList();

    // Add segment to repository
    final segment = await _repository.addSegment(
      sessionId: state!.session.id,
      text: text,
      offsetFromStartMs: elapsed.inMilliseconds,
      detectedVerseRefs: verseRefs,
    );

    // Add to state
    state = state!.copyWith(
      segments: [...state!.segments, segment],
    );

    // Process detected verses
    for (final ref in references) {
      await _processDetectedVerse(ref, text, elapsed);
    }
  }

  Future<void> _processDetectedVerse(
    DetectedReference reference,
    String sourceText,
    Duration mentionedAt,
  ) async {
    if (state == null) return;

    // Get the verse text from Bible database
    final verseText = await _verseDetector.getVerseText(_bibleRepository, reference);
    if (verseText == null) return;

    // Extract context from transcript
    final context = _verseDetector.extractContext(sourceText, reference);

    // Add annotated verse
    final annotatedVerse = await _repository.addAnnotatedVerse(
      sessionId: state!.session.id,
      reference: reference.reference,
      verseText: verseText,
      context: context,
      mentionedAtMs: mentionedAt.inMilliseconds,
    );

    // Add to state
    state = state!.copyWith(
      verses: [...state!.verses, annotatedVerse],
    );
  }

  /// Pause the recording
  Future<void> pauseSession() async {
    if (state == null) return;

    await _speechService.stopListening();
    _elapsedTimer?.cancel();

    state = state!.copyWith(
      isListening: false,
      isPaused: true,
    );
  }

  /// Resume the recording
  Future<void> resumeSession() async {
    if (state == null || !state!.isPaused) return;

    _startElapsedTimer();
    await _speechService.startListening();

    state = state!.copyWith(
      isListening: true,
      isPaused: false,
    );
  }

  /// Stop and save the session
  Future<SermonSession?> stopSession() async {
    if (state == null) return null;

    // Stop listening
    await _speechService.stopListening();
    _elapsedTimer?.cancel();
    _speechSubscription?.cancel();

    // Save any remaining partial text
    if (_currentPartialText.isNotEmpty) {
      await _saveSegment(_currentPartialText);
    }

    // Complete the session
    await _repository.completeSession(
      state!.session.id,
      state!.elapsed.inMilliseconds,
    );

    final completedSession = _repository.getSession(state!.session.id);
    state = null;
    _sessionStartTime = null;
    _currentPartialText = '';

    return completedSession;
  }

  /// Cancel the session without saving
  Future<void> cancelSession() async {
    if (state == null) return;

    await _speechService.cancelListening();
    _elapsedTimer?.cancel();
    _speechSubscription?.cancel();

    // Delete the session
    await _repository.deleteSession(state!.session.id);

    state = null;
    _sessionStartTime = null;
    _currentPartialText = '';
  }

  /// Add a manual note to the current session
  Future<void> addNote(String note) async {
    if (state == null) return;

    final session = state!.session;
    session.notes = (session.notes ?? '') + '\n$note';
    await _repository.updateSession(session);

    state = state!.copyWith(session: session);
  }

  /// Get current partial text being recognized
  String get currentPartialText => _currentPartialText;

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _speechSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for active recording session
final activeSessionProvider = StateNotifierProvider<ActiveSessionNotifier, ActiveSessionState?>((ref) {
  final repository = ref.watch(pastorsNotesRepositoryProvider);
  final bibleRepository = ref.watch(bibleRepositoryProvider);

  return ActiveSessionNotifier(
    repository: repository,
    bibleRepository: bibleRepository,
  );
});

/// Provider for speech recognition availability
final speechAvailableProvider = FutureProvider<bool>((ref) async {
  return SpeechRecognitionService.instance.isAvailable;
});

/// Provider for session search
final sessionSearchProvider = FutureProvider.family<List<SermonSession>, String>((ref, query) async {
  final repo = ref.watch(pastorsNotesRepositoryProvider);
  if (query.isEmpty) {
    return repo.getAllSessions();
  }
  return repo.searchSessions(query);
});

/// Provider for verse search across sessions
final verseSearchProvider = FutureProvider.family<List<SermonSession>, String>((ref, reference) async {
  final repo = ref.watch(pastorsNotesRepositoryProvider);
  return repo.searchByVerse(reference);
});
