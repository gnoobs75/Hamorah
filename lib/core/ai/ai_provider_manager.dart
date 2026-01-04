import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/conversation/models/conversation_models.dart';
import 'hamorah_ai_service.dart';
import 'gemma_ai_service.dart';

/// AI Provider types
enum AiProvider {
  grok,   // Cloud-based Grok API
  gemma,  // On-device Gemma model
}

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

  /// Is using offline mode (Gemma)
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
        return GemmaAiService.instance.isModelDownloaded;
    }
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
        return await GemmaAiService.instance.chat(
          userMessage,
          conversationHistory: conversationHistory,
        );
    }
  }

  /// Get provider display name
  String getProviderName(AiProvider provider) {
    switch (provider) {
      case AiProvider.grok:
        return 'Grok (Cloud)';
      case AiProvider.gemma:
        return 'Gemma (Offline)';
    }
  }

  /// Get provider description
  String getProviderDescription(AiProvider provider) {
    switch (provider) {
      case AiProvider.grok:
        return 'Uses xAI Grok API - requires internet and API key';
      case AiProvider.gemma:
        return 'On-device AI - works offline, ~1.2GB download';
    }
  }

  /// Check if Grok is configured
  Future<bool> isGrokConfigured() async {
    return await HamorahAiService.instance.hasApiKey();
  }

  /// Check if Gemma is downloaded
  bool isGemmaDownloaded() {
    return GemmaAiService.instance.isModelDownloaded;
  }

  /// Get status info for each provider
  Future<Map<AiProvider, Map<String, dynamic>>> getProvidersStatus() async {
    return {
      AiProvider.grok: {
        'name': 'Grok (Cloud)',
        'description': 'xAI Grok API - powerful cloud AI',
        'isConfigured': await HamorahAiService.instance.hasApiKey(),
        'requiresInternet': true,
      },
      AiProvider.gemma: {
        'name': 'Gemma (Offline)',
        'description': 'On-device AI - works without internet',
        'isConfigured': GemmaAiService.instance.isModelDownloaded,
        'isLoaded': GemmaAiService.instance.isInitialized,
        'requiresInternet': false,
        'modelSize': '~1.2 GB',
      },
    };
  }
}
