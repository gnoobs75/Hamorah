import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'models/conversation_models.dart';

const _uuid = Uuid();

/// Repository for managing conversations with Hamorah
class ConversationRepository {
  static const String _messagesBox = 'chat_messages';
  static const String _conversationsBox = 'conversations';
  static const String _currentConversationKey = 'current_conversation_id';

  // Singleton
  static ConversationRepository? _instance;
  static ConversationRepository get instance {
    _instance ??= ConversationRepository._();
    return _instance!;
  }

  ConversationRepository._();

  Box<ChatMessage>? _messages;
  Box<Conversation>? _conversations;
  Box<String>? _settings;

  bool _initialized = false;

  /// Initialize Hive boxes
  Future<void> initialize() async {
    if (_initialized) return;

    // Register adapters
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(ConversationAdapter());
    }

    // Open boxes
    _messages = await Hive.openBox<ChatMessage>(_messagesBox);
    _conversations = await Hive.openBox<Conversation>(_conversationsBox);
    _settings = await Hive.openBox<String>('conversation_settings');

    _initialized = true;
    debugPrint('ConversationRepository initialized');
  }

  /// Get or create current conversation
  Future<Conversation> getCurrentConversation() async {
    final currentId = _settings?.get(_currentConversationKey);

    if (currentId != null) {
      final conversation = _conversations?.get(currentId);
      if (conversation != null) {
        return conversation;
      }
    }

    // Create new conversation
    return await createNewConversation();
  }

  /// Create a new conversation
  Future<Conversation> createNewConversation({String? title}) async {
    final conversation = Conversation(
      id: _uuid.v4(),
      title: title ?? 'New Conversation',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _conversations?.put(conversation.id, conversation);
    await _settings?.put(_currentConversationKey, conversation.id);

    debugPrint('Created new conversation: ${conversation.id}');
    return conversation;
  }

  /// Get all conversations
  List<Conversation> getAllConversations() {
    final conversations = _conversations?.values.toList() ?? [];
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  /// Get messages for a conversation
  List<ChatMessage> getMessagesForConversation(String conversationId) {
    final conversation = _conversations?.get(conversationId);
    if (conversation == null) return [];

    final messages = <ChatMessage>[];
    for (final messageId in conversation.messageIds) {
      final message = _messages?.get(messageId);
      if (message != null) {
        messages.add(message);
      }
    }

    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  /// Add a message to the current conversation
  Future<ChatMessage> addMessage({
    required String conversationId,
    required MessageRole role,
    required String content,
    List<String>? relatedVerses,
    String? debugInfoJson,
  }) async {
    final message = ChatMessage(
      id: _uuid.v4(),
      roleIndex: role.index,
      content: content,
      timestamp: DateTime.now(),
      relatedVerses: relatedVerses,
      debugInfoJson: debugInfoJson,
    );

    await _messages?.put(message.id, message);

    // Add to conversation
    final conversation = _conversations?.get(conversationId);
    if (conversation != null) {
      conversation.messageIds.add(message.id);
      conversation.updatedAt = DateTime.now();

      // Update title based on first user message
      if (conversation.title == 'New Conversation' && role == MessageRole.user) {
        conversation.title = _generateTitle(content);
      }

      await conversation.save();
    }

    return message;
  }

  /// Generate a title from the first message
  String _generateTitle(String content) {
    // Take first 40 characters, try to break at word boundary
    if (content.length <= 40) return content;

    final truncated = content.substring(0, 40);
    final lastSpace = truncated.lastIndexOf(' ');
    if (lastSpace > 20) {
      return '${truncated.substring(0, lastSpace)}...';
    }
    return '$truncated...';
  }

  /// Switch to a different conversation
  Future<void> switchToConversation(String conversationId) async {
    await _settings?.put(_currentConversationKey, conversationId);
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    final conversation = _conversations?.get(conversationId);
    if (conversation != null) {
      // Delete all messages
      for (final messageId in conversation.messageIds) {
        await _messages?.delete(messageId);
      }
      await _conversations?.delete(conversationId);

      // If this was current, clear current
      if (_settings?.get(_currentConversationKey) == conversationId) {
        await _settings?.delete(_currentConversationKey);
      }
    }
  }

  /// Clear all conversations
  Future<void> clearAll() async {
    await _messages?.clear();
    await _conversations?.clear();
    await _settings?.delete(_currentConversationKey);
    debugPrint('Cleared all conversations');
  }
}

/// Provider for conversation repository
final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository.instance;
});
