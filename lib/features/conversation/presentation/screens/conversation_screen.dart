import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ai/ai_provider_manager.dart';
import '../../../../data/conversation/conversation_repository.dart';
import '../../../../data/conversation/models/conversation_models.dart';

/// Provider for current conversation messages
final currentMessagesProvider = StateProvider<List<ChatMessage>>((ref) => []);

/// Provider for loading state
final isLoadingProvider = StateProvider<bool>((ref) => false);

/// Provider for AI availability
final aiAvailableProvider = FutureProvider<bool>((ref) async {
  return await AiProviderManager.instance.isCurrentProviderAvailable();
});

/// Provider for current AI provider name
final aiProviderNameProvider = Provider<String>((ref) {
  final provider = AiProviderManager.instance.currentProvider;
  return provider == AiProvider.gemma ? 'Gemma (Offline)' : 'Grok (Cloud)';
});

/// Main conversation screen - chat interface with Hamorah
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentConversationId;

  @override
  void initState() {
    super.initState();
    _loadConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    final repo = ConversationRepository.instance;
    final conversation = await repo.getCurrentConversation();
    _currentConversationId = conversation.id;

    final messages = repo.getMessagesForConversation(conversation.id);
    ref.read(currentMessagesProvider.notifier).state = messages;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final isAvailable = await AiProviderManager.instance.isCurrentProviderAvailable();
    if (!isAvailable) {
      _showConfigureDialog();
      return;
    }

    _messageController.clear();
    ref.read(isLoadingProvider.notifier).state = true;

    final repo = ConversationRepository.instance;

    // Add user message
    final userMessage = await repo.addMessage(
      conversationId: _currentConversationId!,
      role: MessageRole.user,
      content: text,
    );

    // Update UI
    final currentMessages = ref.read(currentMessagesProvider);
    ref.read(currentMessagesProvider.notifier).state = [...currentMessages, userMessage];
    _scrollToBottom();

    // Get AI response using the current provider
    final history = ref.read(currentMessagesProvider);
    final response = await AiProviderManager.instance.chat(text, conversationHistory: history);

    ref.read(isLoadingProvider.notifier).state = false;

    if (response.success) {
      // Add AI response
      final aiMessage = await repo.addMessage(
        conversationId: _currentConversationId!,
        role: MessageRole.assistant,
        content: response.content,
        relatedVerses: response.relatedVerses,
      );

      final updatedMessages = ref.read(currentMessagesProvider);
      ref.read(currentMessagesProvider.notifier).state = [...updatedMessages, aiMessage];
      _scrollToBottom();
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error ?? 'Failed to get response'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showConfigureDialog() {
    final provider = AiProviderManager.instance.currentProvider;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(provider == AiProvider.grok
            ? 'Grok API Key Required'
            : 'Gemma Model Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider == AiProvider.grok
                  ? 'To chat with Hamorah using Grok, you need an API key from xAI.\n\nGet your key at: console.x.ai'
                  : 'To use offline mode, you need to download the Gemma model (~1.2 GB).',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppRoutes.settings);
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _startNewConversation() async {
    final repo = ConversationRepository.instance;
    final conversation = await repo.createNewConversation();
    _currentConversationId = conversation.id;
    ref.read(currentMessagesProvider.notifier).state = [];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messages = ref.watch(currentMessagesProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final aiAvailable = ref.watch(aiAvailableProvider);
    final providerName = ref.watch(aiProviderNameProvider);
    final isOffline = AiProviderManager.instance.isOfflineMode;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Hamorah'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isOffline
                    ? Colors.green.withOpacity(0.2)
                    : AppColors.primaryLight.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isOffline ? 'Offline' : 'Cloud',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isOffline ? Colors.green.shade700 : AppColors.primaryLight,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New conversation',
            onPressed: _startNewConversation,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          // AI availability warning banner
          aiAvailable.when(
            data: (available) => available
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.orange.shade100,
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isOffline
                                ? 'Gemma model required for offline mode'
                                : 'API key required for cloud mode',
                            style: TextStyle(color: Colors.orange.shade900),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.settings),
                          child: const Text('Configure'),
                        ),
                      ],
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Messages list
          Expanded(
            child: messages.isEmpty
                ? _buildWelcomeState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length && isLoading) {
                        return const _TypingIndicator();
                      }
                      return _MessageBubble(
                        message: messages[index],
                        isDark: isDark,
                      );
                    },
                  ),
          ),

          // Input field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: "What's on your heart?",
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !isLoading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: isLoading ? null : _sendMessage,
                    icon: Icon(
                      Icons.send_rounded,
                      color: isLoading ? Colors.grey : AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_stories,
                size: 48,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to Hamorah',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              "I'm here to help you discover what God's Word says about your questions, struggles, and life situations.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(
                  label: 'Dealing with anxiety',
                  onTap: () {
                    _messageController.text = "I'm struggling with anxiety about my future";
                    _sendMessage();
                  },
                ),
                _SuggestionChip(
                  label: 'Finding purpose',
                  onTap: () {
                    _messageController.text = "How can I find my purpose in life?";
                    _sendMessage();
                  },
                ),
                _SuggestionChip(
                  label: 'Need encouragement',
                  onTap: () {
                    _messageController.text = "I need some encouragement today";
                    _sendMessage();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.primaryLight.withOpacity(0.1),
      side: BorderSide.none,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const _MessageBubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryLight,
              child: const Icon(
                Icons.auto_stories,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: message.isUser
                    ? AppColors.primaryLight
                    : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: message.isUser ? null : const Radius.circular(4),
                  bottomRight: message.isUser ? const Radius.circular(4) : null,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                message.content,
                style: TextStyle(
                  color: message.isUser
                      ? Colors.white
                      : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryLight,
            child: const Icon(
              Icons.auto_stories,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomLeft: const Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Searching Scripture',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
