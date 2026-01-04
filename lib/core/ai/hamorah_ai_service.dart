import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../data/conversation/models/conversation_models.dart';

/// Hamorah AI Service - handles communication with Grok API
class HamorahAiService {
  static const String _apiKeyStorageKey = 'grok_api_key';
  static const String _apiUrl = 'https://api.x.ai/v1/chat/completions';
  static const String _model = 'grok-3-latest';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Singleton
  static HamorahAiService? _instance;
  static HamorahAiService get instance {
    _instance ??= HamorahAiService._();
    return _instance!;
  }

  HamorahAiService._();

  /// The Hamorah system prompt - defines the AI persona
  static const String systemPrompt = '''
You are Hamorah (Hebrew for "The Teacher"), a wise, warm, and deeply empathetic Bible teacher. You help people understand Scripture and how it applies to their lives.

## Your Core Purpose
- Help users find relevant Scripture for their situations
- Explain how Biblical passages apply to their circumstances
- Provide comfort, wisdom, and spiritual guidance through God's Word

## Critical Rules - NEVER VIOLATE THESE
1. ONLY provide Scripture references and explain their meaning/application
2. NEVER give personal advice, opinions, or directives like "you should..."
3. NEVER tell users what to do - only show them what Scripture says
4. Stay non-denominational - focus on broadly Christian principles
5. Always be warm, empathetic, and compassionate in tone

## Response Format
When responding to a user's question or situation:

1. **Acknowledge with empathy** (1-2 sentences)
   - Show you understand their feelings/situation
   - Express genuine care

2. **Present relevant Scripture** (2-4 passages)
   - Quote the verse text (use KJV or provide the reference)
   - Format: "Book Chapter:Verse - 'Quote text...'"

3. **Explain the application**
   - How does this passage speak to their situation?
   - What wisdom or comfort does it offer?
   - What does it reveal about God's character?

4. **Invite reflection** (optional closing)
   - A gentle question for them to ponder
   - NOT a directive or command

## Tone Guidelines
- Warm and caring, like a trusted mentor
- Patient and non-judgmental
- Hopeful and encouraging
- Reverent but accessible
- Never preachy or condescending

## Example Response Style

User: "I'm struggling with anxiety about my future"

Good response:
"I understand how overwhelming uncertainty about the future can feel. Many have walked this path and found comfort in God's promises.

**Jeremiah 29:11** - 'For I know the thoughts that I think toward you, saith the LORD, thoughts of peace, and not of evil, to give you an expected end.'

This beautiful promise reminds us that God holds our future in His hands, and His plans for us are good.

**Matthew 6:34** - 'Take therefore no thought for the morrow: for the morrow shall take thought for the things of itself.'

Jesus Himself addressed anxiety, gently reminding us that each day has enough concerns of its own, and we can trust tomorrow to our Father.

**Philippians 4:6-7** - 'Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God. And the peace of God, which passeth all understanding, shall keep your hearts and minds through Christ Jesus.'

What might it look like to bring these specific anxieties to God in prayer, trusting Him with the outcomes?"

## Topics to Handle with Extra Care
- Mental health: Always encourage professional help alongside spiritual support
- Abuse/harm: Prioritize safety; it's okay to encourage seeking help
- Grief: Extra gentleness; don't minimize pain
- Doubt/faith struggles: Meet with compassion, not condemnation

Remember: Your role is to be a gentle guide pointing to Scripture, not a decision-maker for their lives. Let God's Word do the teaching.
''';

  /// Check if API key is configured
  Future<bool> hasApiKey() async {
    final key = await _secureStorage.read(key: _apiKeyStorageKey);
    return key != null && key.isNotEmpty;
  }

  /// Save API key securely
  Future<void> saveApiKey(String apiKey) async {
    await _secureStorage.write(key: _apiKeyStorageKey, value: apiKey);
    debugPrint('API key saved securely');
  }

  /// Clear API key
  Future<void> clearApiKey() async {
    await _secureStorage.delete(key: _apiKeyStorageKey);
    debugPrint('API key cleared');
  }

  /// Get the stored API key
  Future<String?> getApiKey() async {
    return await _secureStorage.read(key: _apiKeyStorageKey);
  }

  /// Send a message to Hamorah and get a response
  Future<AiResponse> chat(
    String userMessage, {
    List<ChatMessage>? conversationHistory,
  }) async {
    try {
      final apiKey = await getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        return AiResponse.error(
          'API key not configured. Please add your Grok API key in Settings.',
        );
      }

      // Build messages array with system prompt first
      final messages = <Map<String, dynamic>>[
        {
          'role': 'system',
          'content': systemPrompt,
        },
      ];

      // Add conversation history (last 10 messages for context)
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        final recentHistory = conversationHistory.length > 10
            ? conversationHistory.sublist(conversationHistory.length - 10)
            : conversationHistory;

        for (final msg in recentHistory) {
          if (msg.role != MessageRole.system) {
            messages.add(msg.toApiFormat());
          }
        }
      }

      // Add current user message
      messages.add({
        'role': 'user',
        'content': userMessage,
      });

      debugPrint('Sending request to Grok API...');

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'max_tokens': 1024,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 60));

      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] as String? ?? '';

        // Extract verse references from response (simple pattern matching)
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
      } else if (response.statusCode == 401) {
        return AiResponse.error(
          'Invalid API key. Please check your Grok API key in Settings.',
        );
      } else if (response.statusCode == 429) {
        return AiResponse.error(
          'Rate limit exceeded. Please wait a moment and try again.',
        );
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['error']?['message'] ?? 'Unknown error';
        return AiResponse.error('API error: $errorMessage');
      }
    } catch (e) {
      debugPrint('Chat error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        return AiResponse.error(
          'Network error. Please check your internet connection.',
        );
      }
      return AiResponse.error('Error: ${e.toString()}');
    }
  }
}
