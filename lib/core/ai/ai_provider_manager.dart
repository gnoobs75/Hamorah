import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/conversation/models/conversation_models.dart';
import 'hamorah_ai_service.dart';
import 'gemma_ai_service.dart';
import 'llamafile_service.dart';

/// AI Provider types
enum AiProvider {
  grok,   // Cloud-based Grok API
  gemma,  // On-device AI (Gemma on mobile, llama.cpp on desktop)
}

/// Check if running on desktop
bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// Check if running on mobile
bool get _isMobile => Platform.isAndroid || Platform.isIOS;

/// Manager for switching between AI providers
class AiProviderManager {
  static const String _providerKey = 'ai_provider';
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static AiProviderManager? _instance;
  AiProvider _currentProvider = AiProvider.grok;

  AiProviderManager._();

  static AiProviderManager get instance {
    _instance ??= AiProviderManager._();
    return _instance!;
  }

  /// Current provider
  AiProvider get currentProvider => _currentProvider;

  /// Is using offline mode
  bool get isOfflineMode => _currentProvider == AiProvider.gemma;

  /// Initialize and load saved preference
  Future<void> initialize() async {
    try {
      final saved = await _storage.read(key: _providerKey);
      if (saved == 'gemma') {
        _currentProvider = AiProvider.gemma;
      } else {
        _currentProvider = AiProvider.grok;
      }
      debugPrint('AI Provider initialized: $_currentProvider');
    } catch (e) {
      debugPrint('Error loading AI provider preference: $e');
      _currentProvider = AiProvider.grok;
    }
  }

  /// Set the AI provider
  Future<void> setProvider(AiProvider provider) async {
    _currentProvider = provider;
    await _storage.write(
      key: _providerKey,
      value: provider == AiProvider.gemma ? 'gemma' : 'grok',
    );
    debugPrint('AI Provider set to: $provider');
  }

  /// Check if the current provider is available
  Future<bool> isCurrentProviderAvailable() async {
    switch (_currentProvider) {
      case AiProvider.grok:
        return await HamorahAiService.instance.hasApiKey();
      case AiProvider.gemma:
        return isOfflineModelReady();
    }
  }

  /// Check if offline model is ready (platform-specific)
  bool isOfflineModelReady() {
    if (_isDesktop) {
      return LlamafileService.instance.isReady;
    } else if (_isMobile) {
      return GemmaAiService.instance.isModelDownloaded;
    }
    return false;
  }

  /// Send a message using the current provider
  Future<AiResponse> chat(
    String userMessage, {
    List<ChatMessage>? conversationHistory,
  }) async {
    switch (_currentProvider) {
      case AiProvider.grok:
        return await HamorahAiService.instance.chat(
          userMessage,
          conversationHistory: conversationHistory,
        );
      case AiProvider.gemma:
        // Use platform-appropriate service
        if (_isDesktop) {
          return await LlamafileService.instance.chat(
            userMessage,
            conversationHistory: conversationHistory,
          );
        } else {
          return await GemmaAiService.instance.chat(
            userMessage,
            conversationHistory: conversationHistory,
          );
        }
    }
  }

  /// Get provider display name
  String getProviderName(AiProvider provider) {
    switch (provider) {
      case AiProvider.grok:
        return 'Grok (Cloud)';
      case AiProvider.gemma:
        if (_isDesktop) {
          return 'TinyLlama (Offline)';
        }
        return 'Gemma (Offline)';
    }
  }

  /// Get provider description
  String getProviderDescription(AiProvider provider) {
    switch (provider) {
      case AiProvider.grok:
        return 'Uses xAI Grok API - requires internet and API key';
      case AiProvider.gemma:
        if (_isDesktop) {
          return 'On-device AI using Llamafile - works offline, ~911MB download';
        }
        return 'On-device AI - works offline, ~1.2GB download';
    }
  }

  /// Check if Grok is configured
  Future<bool> isGrokConfigured() async {
    return await HamorahAiService.instance.hasApiKey();
  }

  /// Check if offline model is downloaded
  bool isOfflineModelDownloaded() {
    if (_isDesktop) {
      return LlamafileService.instance.isDownloaded;
    } else if (_isMobile) {
      return GemmaAiService.instance.isModelDownloaded;
    }
    return false;
  }

  /// Check if llamafile server is running (desktop only)
  bool isLlamafileRunning() {
    if (_isDesktop) {
      return LlamafileService.instance.isRunning;
    }
    return false;
  }

  /// Get offline model info
  Map<String, dynamic> getOfflineModelInfo() {
    if (_isDesktop) {
      return LlamafileService.instance.getModelInfo();
    } else if (_isMobile) {
      return GemmaAiService.instance.getModelInfo();
    }
    return {'name': 'Not available', 'isDownloaded': false};
  }

  /// Download offline model (returns progress stream)
  Stream<double> downloadOfflineModel() {
    if (_isDesktop) {
      return LlamafileService.instance.download();
    } else if (_isMobile) {
      return GemmaAiService.instance.downloadModel();
    }
    return Stream.value(0.0);
  }

  /// Delete offline model
  Future<void> deleteOfflineModel() async {
    if (_isDesktop) {
      await LlamafileService.instance.delete();
    } else if (_isMobile) {
      await GemmaAiService.instance.deleteModel();
    }
  }

  /// Get status info for each provider
  Future<Map<AiProvider, Map<String, dynamic>>> getProvidersStatus() async {
    final offlineInfo = getOfflineModelInfo();

    return {
      AiProvider.grok: {
        'name': 'Grok (Cloud)',
        'description': 'xAI Grok API - powerful cloud AI',
        'isConfigured': await HamorahAiService.instance.hasApiKey(),
        'requiresInternet': true,
      },
      AiProvider.gemma: {
        'name': _isDesktop ? 'TinyLlama (Offline)' : 'Gemma (Offline)',
        'description': 'On-device AI - works without internet',
        'isConfigured': isOfflineModelReady(),
        'isRunning': offlineInfo['isRunning'] ?? false,
        'isDownloaded': offlineInfo['isDownloaded'] ?? false,
        'requiresInternet': false,
        'modelSize': offlineInfo['size'] ?? 'Unknown',
      },
    };
  }
}
