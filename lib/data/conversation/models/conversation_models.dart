import 'package:hive/hive.dart';

part 'conversation_models.g.dart';

/// Role of a message sender
enum MessageRole {
  user,
  assistant,
  system,
}

/// A single message in a conversation
@HiveType(typeId: 10)
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int roleIndex; // MessageRole index

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  List<String>? relatedVerses; // Scripture references mentioned

  @HiveField(5)
  String? debugInfoJson; // JSON-encoded debug info for assistant messages

  ChatMessage({
    required this.id,
    required this.roleIndex,
    required this.content,
    required this.timestamp,
    this.relatedVerses,
    this.debugInfoJson,
  });

  MessageRole get role => MessageRole.values[roleIndex];

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get hasDebugInfo => debugInfoJson != null && debugInfoJson!.isNotEmpty;

  Map<String, dynamic> toApiFormat() {
    return {
      'role': role == MessageRole.user ? 'user' : 'assistant',
      'content': content,
    };
  }
}

/// A conversation with Hamorah
@HiveType(typeId: 11)
class Conversation extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  DateTime updatedAt;

  @HiveField(4)
  List<String> messageIds;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    List<String>? messageIds,
  }) : messageIds = messageIds ?? [];
}

/// Debug info for AI requests
class AiDebugInfo {
  final String provider;       // 'grok', 'llamafile', 'gemma'
  final String model;          // Specific model name
  final String rawPrompt;      // Full prompt sent to model
  final DateTime timestamp;
  final int? promptTokens;
  final int? responseTokens;
  final Duration? responseTime;

  AiDebugInfo({
    required this.provider,
    required this.model,
    required this.rawPrompt,
    DateTime? timestamp,
    this.promptTokens,
    this.responseTokens,
    this.responseTime,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('=== AI Debug Info ===');
    buffer.writeln('Provider: $provider');
    buffer.writeln('Model: $model');
    buffer.writeln('Timestamp: $timestamp');
    if (promptTokens != null) buffer.writeln('Prompt tokens: $promptTokens');
    if (responseTokens != null) buffer.writeln('Response tokens: $responseTokens');
    if (responseTime != null) buffer.writeln('Response time: ${responseTime!.inMilliseconds}ms');
    buffer.writeln('');
    buffer.writeln('=== Raw Prompt ===');
    buffer.writeln(rawPrompt);
    return buffer.toString();
  }
}

/// Response from AI service
class AiResponse {
  final String content;
  final List<String> relatedVerses;
  final bool success;
  final String? error;
  final AiDebugInfo? debugInfo;

  AiResponse({
    required this.content,
    this.relatedVerses = const [],
    this.success = true,
    this.error,
    this.debugInfo,
  });

  factory AiResponse.error(String message, {AiDebugInfo? debugInfo}) {
    return AiResponse(
      content: '',
      success: false,
      error: message,
      debugInfo: debugInfo,
    );
  }
}
