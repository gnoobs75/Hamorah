import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';

import '../../data/conversation/models/conversation_models.dart';

// Windows API for setting DLL search directory
typedef SetDllDirectoryNative = Int32 Function(Pointer<Utf16> lpPathName);
typedef SetDllDirectoryDart = int Function(Pointer<Utf16> lpPathName);

/// Check if running on a desktop platform (Windows/macOS/Linux)
bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// Desktop AI Service using llama.cpp
/// Supports Windows, macOS, and Linux
class LlamaCppService {
  static LlamaCppService? _instance;
  Llama? _llama;
  bool _isInitialized = false;
  bool _isModelDownloaded = false;
  bool _isLibraryDownloaded = false;

  // TinyLlama 1.1B GGUF model - small and fast
  static const String modelFileName = 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
  static const String modelUrl =
      'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
  static const int modelSizeBytes = 669000000; // ~669 MB

  // llama.cpp library
  static const String _llamaCppVersion = 'b7626'; // Latest stable version
  static String get _libraryFileName {
    if (Platform.isWindows) return 'llama.dll';
    if (Platform.isMacOS) return 'libllama.dylib';
    return 'libllama.so';
  }

  static String get _llamaCppDownloadUrl {
    if (Platform.isWindows) {
      return 'https://github.com/ggml-org/llama.cpp/releases/download/$_llamaCppVersion/llama-$_llamaCppVersion-bin-win-cpu-x64.zip';
    }
    if (Platform.isMacOS) {
      return 'https://github.com/ggml-org/llama.cpp/releases/download/$_llamaCppVersion/llama-$_llamaCppVersion-bin-macos-arm64.zip';
    }
    // Linux
    return 'https://github.com/ggml-org/llama.cpp/releases/download/$_llamaCppVersion/llama-$_llamaCppVersion-bin-linux-x64.zip';
  }

  LlamaCppService._();

  static LlamaCppService get instance {
    _instance ??= LlamaCppService._();
    return _instance!;
  }

  bool get isModelDownloaded => _isModelDownloaded;
  bool get isInitialized => _isInitialized;
  bool get isLibraryDownloaded => _isLibraryDownloaded;

  /// Get the models directory
  Future<String> getModelsDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final modelsDir = Directory(p.join(appDir.path, 'llama_models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir.path;
  }

  /// Get the library directory
  Future<String> getLibraryDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final libDir = Directory(p.join(appDir.path, 'llama_lib'));
    if (!await libDir.exists()) {
      await libDir.create(recursive: true);
    }
    return libDir.path;
  }

  /// Get model file path
  Future<String> getModelPath() async {
    final dir = await getModelsDirectory();
    return p.join(dir, modelFileName);
  }

  /// Get library file path
  Future<String> getLibraryPath() async {
    final dir = await getLibraryDirectory();
    return p.join(dir, _libraryFileName);
  }

  /// Initialize the service
  Future<void> initialize() async {
    if (!isDesktopPlatform) {
      debugPrint('LlamaCppService only supports desktop platforms');
      return;
    }

    try {
      // Check if library is downloaded
      final libPath = await getLibraryPath();
      _isLibraryDownloaded = await File(libPath).exists();
      debugPrint('llama.cpp library downloaded: $_isLibraryDownloaded');

      // Check if model is downloaded
      final modelPath = await getModelPath();
      final modelFile = File(modelPath);
      if (await modelFile.exists()) {
        final size = await modelFile.length();
        _isModelDownloaded = size > 100000000; // At least 100MB
      }
      debugPrint('TinyLlama GGUF model downloaded: $_isModelDownloaded');

      // Set library path if both are ready
      if (_isLibraryDownloaded && _isModelDownloaded) {
        Llama.libraryPath = libPath;
        debugPrint('llama.cpp library path set: $libPath');
      }
    } catch (e) {
      debugPrint('Error initializing LlamaCppService: $e');
    }
  }

  /// Download the llama.cpp library
  Stream<double> downloadLibrary() async* {
    final dio = Dio();
    final libDir = await getLibraryDirectory();
    final zipPath = p.join(libDir, 'llama.zip');

    try {
      debugPrint('Downloading llama.cpp from: $_llamaCppDownloadUrl');

      // Download the zip file
      await dio.download(
        _llamaCppDownloadUrl,
        zipPath,
        onReceiveProgress: (received, total) {
          // Progress will be yielded below
        },
      );

      yield 0.5; // 50% - download complete

      // Extract the library file
      debugPrint('Extracting llama.cpp library...');
      await _extractLibrary(zipPath, libDir);

      yield 0.9;

      // Clean up zip file
      await File(zipPath).delete();

      _isLibraryDownloaded = true;
      final libPath = await getLibraryPath();
      Llama.libraryPath = libPath;

      debugPrint('llama.cpp library ready at: $libPath');
      yield 1.0;
    } catch (e) {
      debugPrint('Error downloading llama.cpp: $e');
      rethrow;
    }
  }

  /// Extract library from zip
  Future<void> _extractLibrary(String zipPath, String destDir) async {
    // Use PowerShell on Windows, unzip on others
    if (Platform.isWindows) {
      final result = await Process.run('powershell', [
        '-Command',
        'Expand-Archive -Path "$zipPath" -DestinationPath "$destDir" -Force'
      ]);
      if (result.exitCode != 0) {
        throw Exception('Failed to extract: ${result.stderr}');
      }

      // List all extracted files for debugging
      final extractedDir = Directory(destDir);
      debugPrint('Extracted files in $destDir:');

      // Copy ALL DLLs to the lib directory (llama.dll may depend on ggml.dll, etc.)
      bool foundLlamaDll = false;
      await for (final entity in extractedDir.list(recursive: true)) {
        if (entity is File) {
          final fileName = p.basename(entity.path).toLowerCase();
          debugPrint('  Found: ${entity.path}');

          if (fileName.endsWith('.dll')) {
            final targetPath = p.join(destDir, p.basename(entity.path));
            if (entity.path != targetPath) {
              await entity.copy(targetPath);
              debugPrint('  Copied DLL to: $targetPath');
            }

            if (fileName == 'llama.dll' || fileName == 'libllama.dll') {
              foundLlamaDll = true;
              // Also copy to expected name if different
              final expectedPath = p.join(destDir, _libraryFileName);
              if (entity.path != expectedPath && targetPath != expectedPath) {
                await entity.copy(expectedPath);
                debugPrint('  Copied as: $expectedPath');
              }
            }
          }
        }
      }

      if (!foundLlamaDll) {
        debugPrint('WARNING: llama.dll not found in extracted files!');
      }
    } else {
      final result = await Process.run('unzip', ['-o', zipPath, '-d', destDir]);
      if (result.exitCode != 0) {
        throw Exception('Failed to extract: ${result.stderr}');
      }

      // Similar logic for Unix
      final extractedDir = Directory(destDir);
      await for (final entity in extractedDir.list(recursive: true)) {
        if (entity is File) {
          final fileName = p.basename(entity.path).toLowerCase();
          if (fileName.endsWith('.so') || fileName.endsWith('.dylib')) {
            final targetPath = p.join(destDir, p.basename(entity.path));
            if (entity.path != targetPath) {
              await entity.copy(targetPath);
            }
          }
        }
      }
    }
  }

  /// Download the GGUF model
  Stream<double> downloadModel() async* {
    final dio = Dio();
    final modelPath = await getModelPath();

    try {
      debugPrint('Downloading TinyLlama GGUF from: $modelUrl');
      debugPrint('Saving to: $modelPath');

      final response = await dio.download(
        modelUrl,
        modelPath,
        onReceiveProgress: (received, total) {
          // Progress handled via stream
        },
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
        ),
      );

      // Stream progress during download
      final file = File(modelPath);
      int lastReported = 0;

      while (true) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await file.exists()) {
          final size = await file.length();
          final progress = size / modelSizeBytes;
          if (size > lastReported) {
            lastReported = size;
            yield progress.clamp(0.0, 0.99);
          }
          if (size >= modelSizeBytes * 0.99) break;
        }
      }

      _isModelDownloaded = true;
      debugPrint('TinyLlama GGUF download complete');
      yield 1.0;
    } catch (e) {
      debugPrint('Error downloading model: $e');
      rethrow;
    }
  }

  /// Download both library and model
  Stream<double> downloadAll() async* {
    // Download library first (smaller)
    if (!_isLibraryDownloaded) {
      debugPrint('Downloading llama.cpp library...');
      await for (final progress in downloadLibrary()) {
        yield progress * 0.1; // 0-10%
      }
    }

    // Then download model
    if (!_isModelDownloaded) {
      debugPrint('Downloading TinyLlama model...');
      await for (final progress in downloadModel()) {
        yield 0.1 + (progress * 0.9); // 10-100%
      }
    }

    yield 1.0;
  }

  /// Load the model
  Future<bool> loadModel() async {
    if (!_isModelDownloaded || !_isLibraryDownloaded) {
      debugPrint('Cannot load - library or model not downloaded');
      return false;
    }

    try {
      final libPath = await getLibraryPath();
      final libDir = await getLibraryDirectory();
      final modelPath = await getModelPath();

      debugPrint('Loading llama.cpp from: $libPath');
      debugPrint('Loading model from: $modelPath');

      // On Windows, set the DLL search directory so dependencies can be found
      if (Platform.isWindows) {
        _setDllDirectory(libDir);
      }

      Llama.libraryPath = libPath;
      _llama = Llama(modelPath);

      _isInitialized = true;
      debugPrint('LlamaCpp model loaded successfully');
      return true;
    } catch (e) {
      debugPrint('Error loading LlamaCpp model: $e');
      return false;
    }
  }

  /// Set DLL search directory on Windows
  void _setDllDirectory(String path) {
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final setDllDirectory = kernel32.lookupFunction<
          SetDllDirectoryNative, SetDllDirectoryDart>('SetDllDirectoryW');

      final pathPtr = path.toNativeUtf16();
      final result = setDllDirectory(pathPtr);
      calloc.free(pathPtr);

      if (result != 0) {
        debugPrint('SetDllDirectory succeeded for: $path');
      } else {
        debugPrint('SetDllDirectory failed for: $path');
      }
    } catch (e) {
      debugPrint('Error setting DLL directory: $e');
    }
  }

  /// Unload the model
  Future<void> unloadModel() async {
    try {
      _llama?.dispose();
      _llama = null;
      _isInitialized = false;
      debugPrint('LlamaCpp model unloaded');
    } catch (e) {
      debugPrint('Error unloading model: $e');
    }
  }

  /// Delete downloaded files
  Future<void> deleteModel() async {
    await unloadModel();
    try {
      final modelPath = await getModelPath();
      final modelFile = File(modelPath);
      if (await modelFile.exists()) {
        await modelFile.delete();
      }
      _isModelDownloaded = false;
      debugPrint('Model deleted');
    } catch (e) {
      debugPrint('Error deleting model: $e');
    }
  }

  /// Chat with the model
  Future<AiResponse> chat(
    String userMessage, {
    List<ChatMessage>? conversationHistory,
  }) async {
    if (!_isModelDownloaded || !_isLibraryDownloaded) {
      return AiResponse.error(
        'Please download the AI model first in Settings.',
      );
    }

    try {
      // Load model if needed
      if (!_isInitialized || _llama == null) {
        final loaded = await loadModel();
        if (!loaded) {
          return AiResponse.error('Failed to load AI model.');
        }
      }

      // Build prompt
      final prompt = _buildPrompt(userMessage, conversationHistory);
      debugPrint('Sending to LlamaCpp: ${prompt.substring(0, prompt.length.clamp(0, 100))}...');

      // Generate response in isolate to avoid blocking UI
      final response = await _generateInIsolate(prompt);

      if (response.isEmpty) {
        return AiResponse.error('AI returned an empty response.');
      }

      // Extract verse references
      final versePattern = RegExp(
        r'(\d?\s?[A-Z][a-z]+)\s+(\d+):(\d+(?:-\d+)?)',
        caseSensitive: false,
      );
      final matches = versePattern.allMatches(response);
      final relatedVerses = matches.map((m) => m.group(0)!).toList();

      return AiResponse(
        content: response,
        relatedVerses: relatedVerses,
      );
    } catch (e) {
      debugPrint('LlamaCpp chat error: $e');
      return AiResponse.error('AI error: ${e.toString()}');
    }
  }

  /// Generate response (runs in isolate for non-blocking)
  Future<String> _generateInIsolate(String prompt) async {
    // For now, run synchronously but in small chunks
    // TODO: Use proper isolate for better performance
    _llama!.setPrompt(prompt);

    final buffer = StringBuffer();
    int tokenCount = 0;
    const maxTokens = 512;

    while (tokenCount < maxTokens) {
      final (token, done) = _llama!.getNext();
      buffer.write(token);
      tokenCount++;

      if (done) break;

      // Yield to UI every few tokens
      if (tokenCount % 10 == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    return buffer.toString().trim();
  }

  /// Build the prompt with Hamorah persona
  String _buildPrompt(String userMessage, List<ChatMessage>? history) {
    final buffer = StringBuffer();

    // TinyLlama uses ChatML format
    buffer.writeln('<|system|>');
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
</s>''');

    // Add recent history
    if (history != null && history.isNotEmpty) {
      final recentHistory = history.length > 4
          ? history.sublist(history.length - 4)
          : history;

      for (final msg in recentHistory) {
        if (msg.role == MessageRole.user) {
          buffer.writeln('<|user|>');
          buffer.writeln(msg.content);
          buffer.writeln('</s>');
        } else if (msg.role == MessageRole.assistant) {
          buffer.writeln('<|assistant|>');
          buffer.writeln(msg.content);
          buffer.writeln('</s>');
        }
      }
    }

    // Add current message
    buffer.writeln('<|user|>');
    buffer.writeln(userMessage);
    buffer.writeln('</s>');
    buffer.writeln('<|assistant|>');

    return buffer.toString();
  }

  /// Get model info
  Map<String, dynamic> getModelInfo() {
    return {
      'name': 'TinyLlama 1.1B (GGUF)',
      'size': '~669 MB',
      'isModelDownloaded': _isModelDownloaded,
      'isLibraryDownloaded': _isLibraryDownloaded,
      'isLoaded': _isInitialized,
    };
  }
}
