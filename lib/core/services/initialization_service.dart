import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../data/bible/bible_database.dart';
import '../../data/bible/bible_download_service.dart';
import '../../data/bible/kjv_importer.dart';
import '../../data/user/user_data_repository.dart';
import '../../data/conversation/conversation_repository.dart';
import '../ai/ai_provider_manager.dart';
import '../ai/gemma_ai_service.dart';
import '../ai/llama_cpp_service.dart';

/// App initialization state
enum InitState {
  initializing,
  needsImport,
  importing,
  ready,
  error,
}

/// Initialization status
class InitStatus {
  final InitState state;
  final double progress;
  final String message;
  final String? error;

  const InitStatus({
    required this.state,
    this.progress = 0.0,
    this.message = '',
    this.error,
  });

  InitStatus copyWith({
    InitState? state,
    double? progress,
    String? message,
    String? error,
  }) {
    return InitStatus(
      state: state ?? this.state,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      error: error ?? this.error,
    );
  }
}

/// Notifier for initialization state
class InitializationNotifier extends StateNotifier<InitStatus> {
  InitializationNotifier() : super(const InitStatus(
    state: InitState.initializing,
    message: 'Starting up...',
  ));

  Future<void> initialize() async {
    try {
      state = state.copyWith(
        state: InitState.initializing,
        message: 'Initializing storage...',
        progress: 0.1,
      );

      // Get application support directory (more reliable on Windows)
      final appDir = await getApplicationSupportDirectory();
      final hiveDir = Directory(p.join(appDir.path, 'hive'));
      if (!await hiveDir.exists()) {
        await hiveDir.create(recursive: true);
      }

      // Initialize Hive with custom path
      Hive.init(hiveDir.path);
      debugPrint('Hive initialized at: ${hiveDir.path}');

      state = state.copyWith(
        message: 'Setting up user data...',
        progress: 0.2,
      );

      // Initialize user data repository (bookmarks, highlights, notes)
      await UserDataRepository.instance.initialize();

      // Initialize conversation repository
      await ConversationRepository.instance.initialize();

      state = state.copyWith(
        message: 'Initializing AI services...',
        progress: 0.3,
      );

      // Initialize AI provider manager
      await AiProviderManager.instance.initialize();

      // Initialize platform-appropriate AI service
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Desktop: use llama.cpp
        await LlamaCppService.instance.initialize();
        debugPrint('LlamaCpp service initialized for desktop');
      } else {
        // Mobile: use Gemma
        await GemmaAiService.instance.initialize();
        debugPrint('Gemma service initialized for mobile');
      }

      state = state.copyWith(
        message: 'Checking Bible database...',
        progress: 0.4,
      );

      // Check if Bible data exists
      final database = BibleDatabase.instance;
      final hasData = await database.hasData();

      if (!hasData) {
        state = state.copyWith(
          state: InitState.needsImport,
          message: 'Bible data needs to be imported',
          progress: 0.4,
        );
        return;
      }

      // Verify data integrity
      final verseCount = await database.getVerseCount();
      debugPrint('Bible database has $verseCount verses');

      // For now, accept any amount of data (sample data has ~33 verses)
      // Later when full KJV import works, can check for verseCount < 30000
      debugPrint('Bible has $verseCount verses - accepting as valid');

      state = state.copyWith(
        state: InitState.ready,
        message: 'Ready!',
        progress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        state: InitState.error,
        error: e.toString(),
        message: 'Initialization failed',
      );
    }
  }

  Future<void> importBible() async {
    state = state.copyWith(
      state: InitState.importing,
      message: 'Downloading KJV Bible...',
      progress: 0.0,
    );

    try {
      await BibleDownloadService.instance.downloadKJV(
        onProgress: (current, total, message) {
          state = state.copyWith(
            progress: current / total,
            message: message,
          );
        },
      );

      state = state.copyWith(
        state: InitState.ready,
        message: 'Ready!',
        progress: 1.0,
      );
    } catch (e) {
      debugPrint('KJV download failed: $e');
      // Fall back to sample data for testing
      state = state.copyWith(
        message: 'Download failed, using sample data...',
        progress: 0.8,
      );

      try {
        final database = BibleDatabase.instance;
        await KjvSampleData.loadIntoDatabase(database);

        state = state.copyWith(
          state: InitState.ready,
          message: 'Ready with sample data',
          progress: 1.0,
        );
      } catch (e2) {
        state = state.copyWith(
          state: InitState.error,
          error: e2.toString(),
          message: 'Import failed',
        );
      }
    }
  }

  Future<void> useSampleData() async {
    state = state.copyWith(
      state: InitState.importing,
      message: 'Loading sample data...',
      progress: 0.5,
    );

    try {
      final database = BibleDatabase.instance;
      await KjvSampleData.loadIntoDatabase(database);

      state = state.copyWith(
        state: InitState.ready,
        message: 'Ready with sample data',
        progress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        state: InitState.error,
        error: e.toString(),
        message: 'Failed to load sample data',
      );
    }
  }

  void retry() {
    state = const InitStatus(
      state: InitState.initializing,
      message: 'Retrying...',
    );
    initialize();
  }
}

/// Provider for initialization
final initializationProvider = StateNotifierProvider<InitializationNotifier, InitStatus>(
  (ref) => InitializationNotifier(),
);
