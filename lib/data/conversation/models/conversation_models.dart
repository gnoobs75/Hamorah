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

  ChatMessage({
    required this.id,
    required this.roleIndex,
    required this.content,
    required this.timestamp,
    this.relatedVerses,
  });

  MessageRole get role => MessageRole.values[roleIndex];

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;

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

/// Response from AI service
class AiResponse {
  final String content;
  final List<String> relatedVerses;
  final bool success;
  final String? error;

  AiResponse({
    required this.content,
    this.relatedVerses = const [],
    this.success = true,
    this.error,
  });

  factory AiResponse.error(String message) {
    return AiResponse(
      content: '',
      success: false,
      error: message,
    );
  }
}
