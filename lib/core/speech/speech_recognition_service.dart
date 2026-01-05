import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Result from speech recognition
class SpeechResult {
  final String text;
  final bool isFinal;
  final double confidence;

  const SpeechResult({
    required this.text,
    this.isFinal = false,
    this.confidence = 0.0,
  });
}

/// Service for handling speech-to-text recognition
class SpeechRecognitionService {
  static SpeechRecognitionService? _instance;
  static SpeechRecognitionService get instance {
    _instance ??= SpeechRecognitionService._();
    return _instance!;
  }

  SpeechRecognitionService._();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  final StreamController<SpeechResult> _resultsController =
      StreamController<SpeechResult>.broadcast();

  /// Stream of speech recognition results
  Stream<SpeechResult> get results => _resultsController.stream;

  /// Whether the service is currently listening
  bool get isListening => _isListening;

  /// Whether speech recognition is available on this device
  Future<bool> get isAvailable async {
    if (!_isInitialized) {
      await initialize();
    }
    return _isInitialized;
  }

  /// Initialize the speech recognition service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Check and request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('Microphone permission not granted');
        return false;
      }

      // Initialize speech to text
      _isInitialized = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
        debugLogging: kDebugMode,
      );

      if (_isInitialized) {
        debugPrint('Speech recognition initialized');
        final locales = await _speech.locales();
        debugPrint('Available locales: ${locales.length}');
      } else {
        debugPrint('Speech recognition not available on this device');
      }

      return _isInitialized;
    } catch (e) {
      debugPrint('Error initializing speech recognition: $e');
      return false;
    }
  }

  /// Start listening for speech
  Future<bool> startListening({
    String? localeId,
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return false;
    }

    if (_isListening) {
      debugPrint('Already listening');
      return true;
    }

    try {
      _isListening = true;

      await _speech.listen(
        onResult: _onResult,
        listenFor: listenFor ?? const Duration(minutes: 30),
        pauseFor: pauseFor ?? const Duration(seconds: 3),
        localeId: localeId ?? 'en_US',
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );

      debugPrint('Started listening');
      return true;
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      _isListening = false;
      return false;
    }
  }

  /// Stop listening for speech
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
      debugPrint('Stopped listening');
    } catch (e) {
      debugPrint('Error stopping speech recognition: $e');
    }
  }

  /// Cancel listening without processing final results
  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
      _isListening = false;
      debugPrint('Cancelled listening');
    } catch (e) {
      debugPrint('Error cancelling speech recognition: $e');
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    final speechResult = SpeechResult(
      text: result.recognizedWords,
      isFinal: result.finalResult,
      confidence: result.confidence,
    );

    _resultsController.add(speechResult);

    if (kDebugMode) {
      debugPrint(
        'Speech result: "${result.recognizedWords}" '
        '(final: ${result.finalResult}, confidence: ${result.confidence})',
      );
    }
  }

  void _onError(dynamic error) {
    debugPrint('Speech recognition error: $error');

    // Auto-restart on certain errors if we're supposed to be listening
    if (_isListening) {
      Future.delayed(const Duration(seconds: 1), () {
        if (_isListening) {
          startListening();
        }
      });
    }
  }

  void _onStatus(String status) {
    debugPrint('Speech recognition status: $status');

    // Handle status changes
    if (status == 'done' && _isListening) {
      // Restart listening if it stopped but we're supposed to keep listening
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isListening) {
          startListening();
        }
      });
    }
  }

  /// Get list of available locales
  Future<List<LocaleName>> getLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _speech.locales();
  }

  /// Dispose of resources
  void dispose() {
    _speech.stop();
    _resultsController.close();
  }
}

/// Provider-compatible wrapper for the speech service
class SpeechRecognitionNotifier extends ChangeNotifier {
  final SpeechRecognitionService _service = SpeechRecognitionService.instance;

  bool _isListening = false;
  String _currentText = '';
  bool _isAvailable = false;

  bool get isListening => _isListening;
  String get currentText => _currentText;
  bool get isAvailable => _isAvailable;

  StreamSubscription<SpeechResult>? _subscription;

  Future<void> initialize() async {
    _isAvailable = await _service.initialize();
    notifyListeners();
  }

  Future<bool> startListening({Function(SpeechResult)? onResult}) async {
    if (!_isAvailable) {
      await initialize();
      if (!_isAvailable) return false;
    }

    _subscription?.cancel();
    _subscription = _service.results.listen((result) {
      _currentText = result.text;
      notifyListeners();
      onResult?.call(result);
    });

    final success = await _service.startListening();
    _isListening = success;
    notifyListeners();
    return success;
  }

  Future<void> stopListening() async {
    await _service.stopListening();
    _isListening = false;
    _subscription?.cancel();
    _subscription = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
