import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bible/models/bible_models.dart';

/// State of the TTS player
enum TtsState {
  stopped,
  playing,
  paused,
  continued,
}

/// Service for text-to-speech functionality
///
/// TTS requires flutter_tts package which needs NuGet on Windows.
/// To enable:
/// 1. Install NuGet: winget install Microsoft.NuGet
/// 2. Uncomment flutter_tts in pubspec.yaml
/// 3. Run flutter pub get
class TtsService {
  static TtsService? _instance;
  static TtsService get instance {
    _instance ??= TtsService._();
    return _instance!;
  }

  TtsService._();

  bool _isInitialized = false;
  bool _isSupported = false;

  TtsState _state = TtsState.stopped;
  double _rate = 1.0;

  final _stateController = StreamController<TtsState>.broadcast();
  final _progressController = StreamController<int>.broadcast();

  List<BibleVerse>? _currentVerses;
  int _currentVerseIndex = 0;

  Stream<TtsState> get stateStream => _stateController.stream;
  Stream<int> get progressStream => _progressController.stream;
  TtsState get state => _state;
  bool get isPlaying => _state == TtsState.playing;
  bool get isSupported => _isSupported;
  double get rate => _rate;
  int get currentVerseIndex => _currentVerseIndex;

  Future<bool> initialize() async {
    if (_isInitialized) return _isSupported;

    // TTS is disabled in this build (flutter_tts commented out)
    // To enable on Windows: install NuGet and uncomment flutter_tts in pubspec.yaml
    debugPrint('TTS disabled - flutter_tts not included in build');
    _isInitialized = true;
    _isSupported = false;
    return false;
  }

  Future<List<dynamic>> getVoices() async => [];
  Future<List<dynamic>> getLanguages() async => [];
  Future<void> setVoice(String voice) async {}
  Future<void> setRate(double rate) async { _rate = rate.clamp(0.25, 2.0); }
  Future<void> setPitch(double pitch) async {}
  Future<void> setVolume(double volume) async {}

  Future<void> speak(String text) async {
    debugPrint('TTS disabled: "$text"');
  }

  Future<void> speakChapter({
    required List<BibleVerse> verses,
    required String bookName,
    required int chapter,
    int startFromVerse = 0,
  }) async {
    debugPrint('TTS disabled: $bookName $chapter');
  }

  Future<void> stop() async {
    _state = TtsState.stopped;
    _stateController.add(_state);
    _currentVerses = null;
    _currentVerseIndex = 0;
  }

  Future<void> pause() async {
    _state = TtsState.paused;
    _stateController.add(_state);
  }

  Future<void> resume() async {}
  void previousVerse() {}
  void nextVerse() {}
  void jumpToVerse(int index) {}

  void dispose() {
    _stateController.close();
    _progressController.close();
  }
}

final ttsServiceProvider = Provider<TtsService>((ref) => TtsService.instance);

final ttsStateProvider = StreamProvider<TtsState>((ref) {
  return ref.watch(ttsServiceProvider).stateStream;
});

final ttsProgressProvider = StreamProvider<int>((ref) {
  return ref.watch(ttsServiceProvider).progressStream;
});

class AudioPlayerState {
  final bool isPlaying;
  final bool isPaused;
  final int currentVerseIndex;
  final int totalVerses;
  final double rate;
  final String? bookName;
  final int? chapter;
  final bool isSupported;

  const AudioPlayerState({
    this.isPlaying = false,
    this.isPaused = false,
    this.currentVerseIndex = 0,
    this.totalVerses = 0,
    this.rate = 1.0,
    this.bookName,
    this.chapter,
    this.isSupported = false,
  });

  AudioPlayerState copyWith({
    bool? isPlaying,
    bool? isPaused,
    int? currentVerseIndex,
    int? totalVerses,
    double? rate,
    String? bookName,
    int? chapter,
    bool? isSupported,
  }) {
    return AudioPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      currentVerseIndex: currentVerseIndex ?? this.currentVerseIndex,
      totalVerses: totalVerses ?? this.totalVerses,
      rate: rate ?? this.rate,
      bookName: bookName ?? this.bookName,
      chapter: chapter ?? this.chapter,
      isSupported: isSupported ?? this.isSupported,
    );
  }
}

class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  final TtsService _tts;

  AudioPlayerNotifier(this._tts) : super(const AudioPlayerState(isSupported: false)) {
    _tts.stateStream.listen((ttsState) {
      state = state.copyWith(
        isPlaying: ttsState == TtsState.playing,
        isPaused: ttsState == TtsState.paused,
      );
    });
    _tts.progressStream.listen((index) {
      state = state.copyWith(currentVerseIndex: index);
    });
  }

  Future<void> playChapter({
    required List<BibleVerse> verses,
    required String bookName,
    required int chapter,
    int startFromVerse = 0,
  }) async {
    if (!_tts.isSupported) return;
    state = state.copyWith(
      totalVerses: verses.length,
      currentVerseIndex: startFromVerse,
      bookName: bookName,
      chapter: chapter,
    );
    await _tts.speakChapter(
      verses: verses,
      bookName: bookName,
      chapter: chapter,
      startFromVerse: startFromVerse,
    );
  }

  Future<void> pause() async => await _tts.pause();
  Future<void> resume() async => await _tts.resume();
  Future<void> stop() async {
    await _tts.stop();
    state = const AudioPlayerState(isSupported: false);
  }
  void previous() => _tts.previousVerse();
  void next() => _tts.nextVerse();
  Future<void> setRate(double rate) async {
    await _tts.setRate(rate);
    state = state.copyWith(rate: rate);
  }
}

final audioPlayerProvider = StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>((ref) {
  return AudioPlayerNotifier(ref.watch(ttsServiceProvider));
});
