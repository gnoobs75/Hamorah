import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../../data/conversation/models/conversation_models.dart';
import 'model_download_service.dart';

/// Check if running on a supported platform for on-device AI
bool get isOfflineAiSupported => Platform.isAndroid || Platform.isIOS;

/// On-device AI Service - handles local LLM inference
/// Uses TinyLlama 1.1B (public, no auth required)
class GemmaAiService {
  static GemmaAiService? _instance;
  InferenceModel? _model;
  dynamic _chat; // Chat type from flutter_gemma
  bool _isInitialized = false;
  bool _isModelDownloaded = false;

  GemmaAiService._();

  static GemmaAiService get instance {
    _instance ??= GemmaAiService._();
    return _instance!;
  }

  /// Check if model is downloaded
  bool get isModelDownloaded => _isModelDownloaded;

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the Gemma service
  Future<void> initialize() async {
    // Check platform support
    if (!isOfflineAiSupported) {
      debugPrint('Offline AI not supported on this platform (Windows/macOS/Linux)');
      debugPrint('Use Grok cloud AI instead, or build for Android/iOS for offline mode');
      _isModelDownloaded = false;
      return;
    }

    try {
      // Initialize FlutterGemma
      await FlutterGemma.initialize();

      // Check if model is downloaded using our custom service
      _isModelDownloaded = await ModelDownloadService.instance.isModelDownloaded();
      debugPrint('TinyLlama model downloaded: $_isModelDownloaded');

      // If downloaded, install from file path
      if (_isModelDownloaded) {
        await _installFromFile();
      }
    } catch (e) {
      debugPrint('Error initializing Gemma: $e');
      _isModelDownloaded = false;
    }
  }

  /// Install model from our custom download location
  Future<void> _installFromFile() async {
    try {
      final modelPath = await ModelDownloadService.instance.getModelPath();
      debugPrint('Installing model from: $modelPath');

      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromFile(modelPath).install();

      debugPrint('Model installed from file successfully');
    } catch (e) {
      debugPrint('Error installing model from file: $e');
      // Model might already be installed, continue
    }
  }

  /// Download the model using our custom service
  /// Returns a stream of download progress (0.0 to 1.0)
  Stream<double> downloadModel() async* {
    if (!isOfflineAiSupported) {
      throw UnsupportedError(
        'Offline AI is only available on Android and iOS. '
        'Please use Grok (cloud) mode on Windows/macOS/Linux.',
      );
    }

    try {
      debugPrint('Starting TinyLlama model download...');

      // Use our custom download service
      await for (final progress in ModelDownloadService.instance.downloadModel()) {
        yield progress;

        if (progress >= 1.0) {
          _isModelDownloaded = true;
          // Install from the downloaded file
          await _installFromFile();
        } else if (progress < 0) {
          // Download cancelled
          return;
        }
      }

      debugPrint('TinyLlama model download complete');
    } catch (e) {
      debugPrint('Error downloading TinyLlama model: $e');
      rethrow;
    }
  }

  /// Cancel ongoing download
  void cancelDownload() {
    ModelDownloadService.instance.cancelDownload();
  }

  /// Load the model into memory
  Future<bool> loadModel() async {
    if (!_isModelDownloaded) {
      debugPrint('Cannot load model - not downloaded');
      return false;
    }

    try {
      if (_model == null) {
        _model = await FlutterGemma.getActiveModel(maxTokens: 1024);
        debugPrint('TinyLlama model loaded');
      }
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error loading TinyLlama model: $e');
      return false;
    }
  }

  /// Unload the model from memory
  Future<void> unloadModel() async {
    try {
      if (_chat != null) {
        await _chat!.close();
        _chat = null;
      }
      if (_model != null) {
        await _model!.close();
        _model = null;
      }
      _isInitialized = false;
      debugPrint('TinyLlama model unloaded');
    } catch (e) {
      debugPrint('Error unloading TinyLlama model: $e');
    }
  }

  /// Delete the downloaded model
  Future<void> deleteModel() async {
    await unloadModel();
    await ModelDownloadService.instance.deleteModel();
    _isModelDownloaded = false;
    debugPrint('TinyLlama model deleted');
  }

  /// Send a message and get a response
  Future<AiResponse> chat(
    String userMessage, {
    List<ChatMessage>? conversationHistory,
  }) async {
    if (!_isModelDownloaded) {
      return AiResponse.error(
        'TinyLlama model not downloaded. Please download it in Settings.',
      );
    }

    try {
      // Load model if needed
      if (!_isInitialized || _model == null) {
        final loaded = await loadModel();
        if (!loaded) {
          return AiResponse.error('Failed to load TinyLlama model.');
        }
      }

      // Create chat if needed
      _chat ??= await _model!.createChat(temperature: 0.7);

      // Build the prompt with system context
      final prompt = _buildPrompt(userMessage, conversationHistory);

      debugPrint('Sending to TinyLlama: ${prompt.substring(0, prompt.length.clamp(0, 100))}...');

      // Add user query and generate response
      await _chat!.addQueryChunk(Message.text(text: prompt, isUser: true));

      // Collect response tokens
      final buffer = StringBuffer();
      await for (final response in _chat!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          buffer.write(response.token);
        }
      }

      final content = buffer.toString().trim();

      if (content.isEmpty) {
        return AiResponse.error('TinyLlama returned an empty response.');
      }

      // Extract verse references from response
      final versePattern = RegExp(
        r'(\d?\s?[A-Z][a-z]+)\s+(\d+):(\d+(?:-\d+)?)',
        caseSensitive: false,
      );
      final matches = versePattern.allMatches(content);
      final relatedVerses = matches.map((m) => m.group(0)!).toList();

      return AiResponse(
        content: content,
        relatedVerses: relatedVerses,
      );
    } catch (e) {
      debugPrint('TinyLlama chat error: $e');
      return AiResponse.error('TinyLlama error: ${e.toString()}');
    }
  }

  /// Build the prompt with Hamorah persona and context
  String _buildPrompt(String userMessage, List<ChatMessage>? history) {
    final buffer = StringBuffer();

    // Add system prompt (condensed for on-device model)
    buffer.writeln('''
You are Hamorah, a wise and empathetic Bible teacher. Your role is to:
- Help users find relevant Scripture for their situations
- Explain how Biblical passages apply to their lives
- Be warm, caring, and non-judgmental

IMPORTANT RULES:
1. ONLY provide Scripture references and explanations
2. NEVER give personal advice or tell users what to do
3. Quote Bible verses in this format: "Book Chapter:Verse - 'Quote...'"
4. Stay non-denominational and focus on Scripture

---
''');

    // Add recent history (limited for context length)
    if (history != null && history.isNotEmpty) {
      final recentHistory = history.length > 4
          ? history.sublist(history.length - 4)
          : history;

      for (final msg in recentHistory) {
        if (msg.role == MessageRole.user) {
          buffer.writeln('User: ${msg.content}');
        } else if (msg.role == MessageRole.assistant) {
          buffer.writeln('Hamorah: ${msg.content}');
        }
      }
      buffer.writeln();
    }

    // Add current message
    buffer.writeln('User: $userMessage');
    buffer.writeln();
    buffer.writeln('Hamorah:');

    return buffer.toString();
  }

  /// Get model info
  Map<String, dynamic> getModelInfo() {
    return {
      'name': 'TinyLlama 1.1B',
      'size': '~1.15 GB',
      'isDownloaded': _isModelDownloaded,
      'isLoaded': _isInitialized,
    };
  }
}
