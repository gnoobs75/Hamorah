import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../../data/conversation/models/conversation_models.dart';

/// On-device AI Service - handles local LLM inference
/// Uses TinyLlama 1.1B (public, no auth required)
class GemmaAiService {
  static GemmaAiService? _instance;
  InferenceModel? _model;
  dynamic _chat; // Chat type from flutter_gemma
  bool _isInitialized = false;
  bool _isModelDownloaded = false;

  // TinyLlama 1.1B - public model, no authentication required
  static const String _modelFileName = 'TinyLlama-1.1B-Chat-v1.0_multi-prefill-seq_q8_ekv1280.task';

  GemmaAiService._();

  static GemmaAiService get instance {
    _instance ??= GemmaAiService._();
    return _instance!;
  }

  /// Model download URL - TinyLlama 1.1B quantized (public, ~1.15 GB)
  static const String _modelUrl =
      'https://huggingface.co/litert-community/TinyLlama-1.1B-Chat-v1.0/resolve/main/TinyLlama-1.1B-Chat-v1.0_multi-prefill-seq_q8_ekv1280.task';

  /// Check if model is downloaded
  bool get isModelDownloaded => _isModelDownloaded;

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the Gemma service
  Future<void> initialize() async {
    try {
      // Initialize FlutterGemma
      await FlutterGemma.initialize();

      // Check if model is installed
      _isModelDownloaded = await FlutterGemma.isModelInstalled(_modelFileName);
      debugPrint('Gemma model downloaded: $_isModelDownloaded');
    } catch (e) {
      debugPrint('Error initializing Gemma: $e');
      _isModelDownloaded = false;
    }
  }

  /// Download the Gemma model
  /// Returns a stream of download progress (0.0 to 1.0)
  Stream<double> downloadModel() async* {
    try {
      debugPrint('Starting Gemma model download...');

      double currentProgress = 0;
      final completer = Completer<void>();

      FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromNetwork(_modelUrl).withProgress((progress) {
        currentProgress = progress / 100.0;
      }).install().then((_) {
        _isModelDownloaded = true;
        completer.complete();
      }).catchError((e) {
        completer.completeError(e);
      });

      // Yield progress updates
      while (!completer.isCompleted) {
        yield currentProgress;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Wait for completion
      await completer.future;

      debugPrint('Gemma model download complete');
      yield 1.0;
    } catch (e) {
      debugPrint('Error downloading Gemma model: $e');
      rethrow;
    }
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
        debugPrint('Gemma model loaded');
      }
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error loading Gemma model: $e');
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
      debugPrint('Gemma model unloaded');
    } catch (e) {
      debugPrint('Error unloading Gemma model: $e');
    }
  }

  /// Delete the downloaded model (mark as not downloaded)
  Future<void> deleteModel() async {
    await unloadModel();
    // Note: flutter_gemma doesn't have a deleteModel method
    // The model file would need to be manually deleted
    _isModelDownloaded = false;
    debugPrint('Gemma model marked as deleted');
  }

  /// Send a message to Gemma and get a response
  Future<AiResponse> chat(
    String userMessage, {
    List<ChatMessage>? conversationHistory,
  }) async {
    if (!_isModelDownloaded) {
      return AiResponse.error(
        'Gemma model not downloaded. Please download it in Settings.',
      );
    }

    try {
      // Load model if needed
      if (!_isInitialized || _model == null) {
        final loaded = await loadModel();
        if (!loaded) {
          return AiResponse.error('Failed to load Gemma model.');
        }
      }

      // Create chat if needed
      _chat ??= await _model!.createChat(temperature: 0.7);

      // Build the prompt with system context
      final prompt = _buildPrompt(userMessage, conversationHistory);

      debugPrint('Sending to Gemma: ${prompt.substring(0, prompt.length.clamp(0, 100))}...');

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
        return AiResponse.error('Gemma returned an empty response.');
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
      debugPrint('Gemma chat error: $e');
      return AiResponse.error('Gemma error: ${e.toString()}');
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
