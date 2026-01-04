import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';

import '../../data/conversation/models/conversation_models.dart';

/// Llamafile service for local LLM inference on desktop
/// Downloads and runs a self-contained llamafile executable
class LlamafileService {
  static LlamafileService? _instance;
  static const int _port = 8065; // Avoid common ports
  static const String _baseUrl = 'http://127.0.0.1:$_port';

  // TinyLlama llamafile - small and fast for testing
  static const String _llamafileUrl =
      'https://huggingface.co/jartine/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/TinyLlama-1.1B-Chat-v1.0.Q4_K_M.llamafile';
  static const String _llamafileName = 'tinyllama.llamafile';
  static const int _fileSizeBytes = 911000000; // ~911 MB

  Process? _serverProcess;
  bool _isDownloaded = false;
  bool _isRunning = false;

  LlamafileService._();

  static LlamafileService get instance {
    _instance ??= LlamafileService._();
    return _instance!;
  }

  bool get isDownloaded => _isDownloaded;
  bool get isRunning => _isRunning;
  bool get isReady => _isDownloaded && _isRunning;

  /// Get the llamafile directory
  Future<String> _getDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'llamafile'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// Get llamafile path
  Future<String> _getLlamafilePath() async {
    final dir = await _getDirectory();
    // On Windows, rename to .exe for execution
    final filename = Platform.isWindows ? 'tinyllama.exe' : _llamafileName;
    return p.join(dir, filename);
  }

  /// Initialize - check if downloaded and start server
  Future<void> initialize() async {
    try {
      final path = await _getLlamafilePath();
      final file = File(path);

      if (await file.exists()) {
        final size = await file.length();
        _isDownloaded = size > 100000000; // At least 100MB
        debugPrint('Llamafile downloaded: $_isDownloaded (${size ~/ 1000000} MB)');

        if (_isDownloaded) {
          // Try to start the server
          await startServer();
        }
      } else {
        debugPrint('Llamafile not found at: $path');
        _isDownloaded = false;
      }
    } catch (e) {
      debugPrint('Error initializing LlamafileService: $e');
    }
  }

  /// Download the llamafile
  Stream<double> download() async* {
    final dio = Dio();
    final path = await _getLlamafilePath();
    final controller = StreamController<double>();

    try {
      debugPrint('Downloading llamafile from: $_llamafileUrl');
      debugPrint('Saving to: $path');

      // Start download with progress tracking
      dio.download(
        _llamafileUrl,
        path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            controller.add(progress.clamp(0.0, 0.99));
          }
        },
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 30),
        ),
      ).then((_) {
        controller.add(1.0);
        controller.close();
      }).catchError((e) {
        controller.addError(e);
        controller.close();
      });

      // Yield progress from controller
      await for (final progress in controller.stream) {
        yield progress;
      }

      _isDownloaded = true;
      debugPrint('Llamafile download complete');

      // Make executable on Unix
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', path]);
      }

      // Start the server
      await startServer();

    } catch (e) {
      debugPrint('Error downloading llamafile: $e');
      rethrow;
    }
  }

  /// Start the llamafile server
  Future<bool> startServer() async {
    if (_isRunning) return true;
    if (!_isDownloaded) return false;

    try {
      final path = await _getLlamafilePath();
      debugPrint('Starting llamafile server: $path');

      // Kill any existing process on our port
      await _killExistingServer();

      // Start the server process
      _serverProcess = await Process.start(
        path,
        [
          '--server',
          '--port', '$_port',
          '--host', '127.0.0.1',
          '-c', '2048', // Context size
          '-ngl', '0', // CPU only for compatibility
        ],
        mode: ProcessStartMode.detached,
      );

      // Wait for server to be ready
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (await _checkServer()) {
          _isRunning = true;
          debugPrint('Llamafile server started on port $_port');
          return true;
        }
      }

      debugPrint('Llamafile server failed to start within timeout');
      return false;
    } catch (e) {
      debugPrint('Error starting llamafile server: $e');
      return false;
    }
  }

  /// Check if server is responding
  Future<bool> _checkServer() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
      ).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Kill existing server on our port
  Future<void> _killExistingServer() async {
    try {
      if (Platform.isWindows) {
        // Find and kill process using our port
        final result = await Process.run('netstat', ['-ano']);
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          if (line.contains(':$_port')) {
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.isNotEmpty) {
              final pid = parts.last;
              await Process.run('taskkill', ['/F', '/PID', pid]);
            }
          }
        }
      } else {
        await Process.run('pkill', ['-f', 'tinyllama']);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Stop the server
  Future<void> stopServer() async {
    try {
      _serverProcess?.kill();
      _serverProcess = null;
      await _killExistingServer();
      _isRunning = false;
      debugPrint('Llamafile server stopped');
    } catch (e) {
      debugPrint('Error stopping server: $e');
    }
  }

  /// Build a human-readable prompt string for debugging
  String _buildDebugPrompt(List<Map<String, String>> messages) {
    final buffer = StringBuffer();
    for (final msg in messages) {
      final role = msg['role']!;
      final content = msg['content']!;
      buffer.writeln('[$role]');
      buffer.writeln(content);
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Chat with the model (OpenAI-compatible API)
  Future<AiResponse> chat(
    String userMessage, {
    List<ChatMessage>? conversationHistory,
  }) async {
    final startTime = DateTime.now();

    if (!_isDownloaded) {
      return AiResponse.error(
        'Please download the AI model first in Settings.',
      );
    }

    if (!_isRunning) {
      final started = await startServer();
      if (!started) {
        return AiResponse.error(
          'Failed to start AI server. Please try again.',
        );
      }
    }

    try {
      final messages = _buildMessages(userMessage, conversationHistory);
      final rawPrompt = _buildDebugPrompt(messages);

      debugPrint('Sending to llamafile: ${userMessage.substring(0, userMessage.length.clamp(0, 50))}...');

      final response = await http.post(
        Uri.parse('$_baseUrl/v1/chat/completions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messages': messages,
          'max_tokens': 512,
          'temperature': 0.7,
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 60));

      final responseTime = DateTime.now().difference(startTime);

      if (response.statusCode != 200) {
        return AiResponse.error(
          'AI error: ${response.statusCode}',
          debugInfo: AiDebugInfo(
            provider: 'Llamafile',
            model: 'TinyLlama-1.1B-Chat-v1.0-Q4_K_M',
            rawPrompt: rawPrompt,
            responseTime: responseTime,
          ),
        );
      }

      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'] as String? ?? '';

      // Extract token usage if available
      final usage = data['usage'] as Map<String, dynamic>?;
      final promptTokens = usage?['prompt_tokens'] as int?;
      final responseTokens = usage?['completion_tokens'] as int?;

      if (content.isEmpty) {
        return AiResponse.error(
          'AI returned an empty response.',
          debugInfo: AiDebugInfo(
            provider: 'Llamafile',
            model: 'TinyLlama-1.1B-Chat-v1.0-Q4_K_M',
            rawPrompt: rawPrompt,
            responseTime: responseTime,
          ),
        );
      }

      // Extract verse references
      final versePattern = RegExp(
        r'(\d?\s?[A-Z][a-z]+)\s+(\d+):(\d+(?:-\d+)?)',
        caseSensitive: false,
      );
      final matches = versePattern.allMatches(content);
      final relatedVerses = matches.map((m) => m.group(0)!).toList();

      return AiResponse(
        content: content.trim(),
        relatedVerses: relatedVerses,
        debugInfo: AiDebugInfo(
          provider: 'Llamafile',
          model: 'TinyLlama-1.1B-Chat-v1.0-Q4_K_M',
          rawPrompt: rawPrompt,
          promptTokens: promptTokens,
          responseTokens: responseTokens,
          responseTime: responseTime,
        ),
      );
    } catch (e) {
      debugPrint('Llamafile chat error: $e');
      return AiResponse.error('AI error: ${e.toString()}');
    }
  }

  /// Build messages array for OpenAI-compatible API
  List<Map<String, String>> _buildMessages(
    String userMessage,
    List<ChatMessage>? history,
  ) {
    final messages = <Map<String, String>>[];

    // System prompt
    messages.add({
      'role': 'system',
      'content': '''You are Hamorah, a wise and empathetic Bible teacher. Your role is to:
- Help users find relevant Scripture for their situations
- Explain how Biblical passages apply to their lives
- Be warm, caring, and non-judgmental

IMPORTANT RULES:
1. ONLY provide Scripture references and explanations
2. NEVER give personal advice or tell users what to do
3. Quote Bible verses in this format: "Book Chapter:Verse - 'Quote...'"
4. Stay non-denominational and focus on Scripture''',
    });

    // Add conversation history
    if (history != null && history.isNotEmpty) {
      final recentHistory = history.length > 4
          ? history.sublist(history.length - 4)
          : history;

      for (final msg in recentHistory) {
        messages.add({
          'role': msg.role == MessageRole.user ? 'user' : 'assistant',
          'content': msg.content,
        });
      }
    }

    // Add current message
    messages.add({
      'role': 'user',
      'content': userMessage,
    });

    return messages;
  }

  /// Delete the llamafile
  Future<void> delete() async {
    await stopServer();
    try {
      final path = await _getLlamafilePath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      _isDownloaded = false;
      debugPrint('Llamafile deleted');
    } catch (e) {
      debugPrint('Error deleting llamafile: $e');
    }
  }

  /// Get model info
  Map<String, dynamic> getModelInfo() {
    return {
      'name': 'TinyLlama (Llamafile)',
      'size': '~911 MB',
      'isDownloaded': _isDownloaded,
      'isRunning': _isRunning,
      'isLoaded': _isRunning,
    };
  }
}
