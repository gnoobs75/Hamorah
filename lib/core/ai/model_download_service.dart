import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Custom model download service for Windows compatibility
/// Bypasses flutter_gemma's internal downloader which has issues on Windows
class ModelDownloadService {
  static ModelDownloadService? _instance;
  Dio? _dio;
  CancelToken? _cancelToken;

  ModelDownloadService._();

  static ModelDownloadService get instance {
    _instance ??= ModelDownloadService._();
    return _instance!;
  }

  /// TinyLlama 1.1B model info
  static const String modelFileName = 'TinyLlama-1.1B-Chat-v1.0_multi-prefill-seq_q8_ekv1280.task';
  static const String modelUrl =
      'https://huggingface.co/litert-community/TinyLlama-1.1B-Chat-v1.0/resolve/main/TinyLlama-1.1B-Chat-v1.0_multi-prefill-seq_q8_ekv1280.task';
  static const int expectedSizeBytes = 1234567890; // ~1.15 GB approximate

  /// Get the model directory path
  Future<String> getModelDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final modelDir = Directory(p.join(appDir.path, 'models'));
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir.path;
  }

  /// Get the full path to the model file
  Future<String> getModelPath() async {
    final dir = await getModelDirectory();
    return p.join(dir, modelFileName);
  }

  /// Check if model is downloaded
  Future<bool> isModelDownloaded() async {
    try {
      final path = await getModelPath();
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        // Model should be at least 1GB
        return size > 1000000000;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking model: $e');
      return false;
    }
  }

  /// Get downloaded model size in bytes
  Future<int> getModelSize() async {
    try {
      final path = await getModelPath();
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Download the model with progress callback
  /// Returns a stream of progress (0.0 to 1.0)
  Stream<double> downloadModel() async* {
    final path = await getModelPath();
    final file = File(path);
    final tempPath = '$path.downloading';
    final tempFile = File(tempPath);

    debugPrint('Downloading model to: $path');

    _dio = Dio();
    _cancelToken = CancelToken();

    // Check if we have a partial download to resume
    int startByte = 0;
    if (await tempFile.exists()) {
      startByte = await tempFile.length();
      debugPrint('Resuming download from byte: $startByte');
    }

    try {
      final response = await _dio!.download(
        modelUrl,
        tempPath,
        cancelToken: _cancelToken,
        deleteOnError: false,
        options: Options(
          headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
          responseType: ResponseType.stream,
        ),
        onReceiveProgress: (received, total) {
          // This callback is used internally by Dio
        },
      );

      // Dio's download doesn't give us progress easily, so let's use a different approach
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        debugPrint('Download cancelled');
        yield -1.0;
        return;
      }
      debugPrint('Initial download attempt failed: $e');
    }

    // Use streaming download for better progress tracking
    _dio = Dio();
    _cancelToken = CancelToken();

    try {
      // First, get the file size
      final headResponse = await _dio!.head(modelUrl);
      final contentLength = int.tryParse(
        headResponse.headers.value('content-length') ?? '0'
      ) ?? 0;

      debugPrint('Model size: ${(contentLength / 1024 / 1024).toStringAsFixed(2)} MB');

      // Download with progress
      final response = await _dio!.get<ResponseBody>(
        modelUrl,
        cancelToken: _cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
        ),
      );

      final sink = tempFile.openWrite();
      int received = 0;

      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        received += chunk.length;

        if (contentLength > 0) {
          yield received / contentLength;
        }
      }

      await sink.close();

      // Verify download
      final downloadedSize = await tempFile.length();
      debugPrint('Downloaded: ${(downloadedSize / 1024 / 1024).toStringAsFixed(2)} MB');

      if (contentLength > 0 && downloadedSize < contentLength * 0.99) {
        throw Exception('Download incomplete: $downloadedSize / $contentLength');
      }

      // Move temp file to final location
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(path);

      debugPrint('Model download complete: $path');
      yield 1.0;

    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        debugPrint('Download cancelled');
        yield -1.0;
        return;
      }
      debugPrint('Download error: $e');
      rethrow;
    } finally {
      _dio = null;
      _cancelToken = null;
    }
  }

  /// Cancel ongoing download
  void cancelDownload() {
    _cancelToken?.cancel('User cancelled');
    _cancelToken = null;
    _dio = null;
  }

  /// Delete the downloaded model
  Future<void> deleteModel() async {
    try {
      final path = await getModelPath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Model deleted: $path');
      }

      // Also delete any temp files
      final tempFile = File('$path.downloading');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (e) {
      debugPrint('Error deleting model: $e');
    }
  }
}
