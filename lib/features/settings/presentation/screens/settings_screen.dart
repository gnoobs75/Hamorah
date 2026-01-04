import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/ai/hamorah_ai_service.dart';
import '../../../../core/ai/gemma_ai_service.dart';
import '../../../../core/ai/ai_provider_manager.dart';
import '../../../../data/user/user_data_repository.dart';
import '../../../../data/conversation/conversation_repository.dart';
import '../../../../data/bible/bible_database.dart';
import '../../../../data/bible/bible_download_service.dart';
import '../../../../data/bible/models/bible_models.dart';

/// Provider for API key status
final apiKeyStatusProvider = FutureProvider<bool>((ref) async {
  return await HamorahAiService.instance.hasApiKey();
});

/// Provider for translations
final translationsProvider = FutureProvider<List<BibleTranslation>>((ref) async {
  return await BibleDatabase.instance.getTranslations();
});

/// Provider for current AI provider
final aiProviderProvider = StateProvider<AiProvider>((ref) {
  return AiProviderManager.instance.currentProvider;
});

/// Settings screen - privacy, appearance, translations, AI
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _darkMode = false;
  String? _downloadingTranslation;
  double _downloadProgress = 0;
  bool _isDownloadingGemma = false;
  double _gemmaProgress = 0;

  @override
  Widget build(BuildContext context) {
    final hasApiKey = ref.watch(apiKeyStatusProvider);
    final translations = ref.watch(translationsProvider);
    final currentProvider = ref.watch(aiProviderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          // AI Provider section
          _SectionHeader('AI Provider', Icons.psychology_outlined),
          _buildAiProviderSection(currentProvider, hasApiKey),

          const Divider(height: 32),

          // Bible Translations section
          _SectionHeader('Bible Translations', Icons.menu_book_outlined),
          translations.when(
            data: (trans) => _buildTranslationsSection(trans),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading translations: $e'),
            ),
          ),

          const Divider(height: 32),

          // Privacy section
          _SectionHeader('Privacy', Icons.lock_outline),
          _SettingsTile(
            icon: Icons.visibility_outlined,
            title: 'View My Data',
            subtitle: 'See all data stored on your device',
            trailing: const Icon(Icons.chevron_right),
            onTap: _showDataView,
          ),
          _SettingsTile(
            icon: Icons.delete_sweep_outlined,
            title: 'Clear Conversations',
            subtitle: 'Delete all chat history',
            trailing: const Icon(Icons.chevron_right),
            onTap: _confirmClearConversations,
          ),
          _SettingsTile(
            icon: Icons.delete_outline,
            title: 'Delete All Data',
            subtitle: 'Permanently remove all app data',
            trailing: const Icon(Icons.chevron_right),
            onTap: _confirmDeleteData,
            isDestructive: true,
          ),

          const Divider(height: 32),

          // Appearance section
          _SectionHeader('Appearance', Icons.palette_outlined),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            subtitle: 'Easier reading at night',
            trailing: Switch(
              value: _darkMode,
              onChanged: (value) => setState(() => _darkMode = value),
              activeColor: AppColors.primaryLight,
            ),
          ),

          const Divider(height: 32),

          // About section
          _SectionHeader('About', Icons.info_outline),
          _SettingsTile(
            icon: Icons.auto_stories,
            title: 'About Hamorah',
            subtitle: 'Version 1.0.0',
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAbout,
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we protect your data',
            trailing: const Icon(Icons.chevron_right),
            onTap: _showPrivacyPolicy,
          ),

          const SizedBox(height: 32),

          // Privacy promise
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.primaryLight, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Your Privacy Promise',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All your data is stored locally on your device. With Gemma offline mode, even your AI conversations stay completely private.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAiProviderSection(AiProvider currentProvider, AsyncValue<bool> hasApiKey) {
    final gemmaService = GemmaAiService.instance;

    return Column(
      children: [
        // Grok option
        RadioListTile<AiProvider>(
          title: const Text('Grok (Cloud)'),
          subtitle: hasApiKey.when(
            data: (has) => Text(
              has ? 'API key configured' : 'Requires API key',
              style: TextStyle(
                color: has ? Colors.green : Colors.orange,
              ),
            ),
            loading: () => const Text('Checking...'),
            error: (_, __) => const Text('Error'),
          ),
          secondary: const Icon(Icons.cloud_outlined),
          value: AiProvider.grok,
          groupValue: currentProvider,
          onChanged: (value) async {
            if (value != null) {
              await AiProviderManager.instance.setProvider(value);
              ref.read(aiProviderProvider.notifier).state = value;
            }
          },
        ),
        hasApiKey.when(
          data: (has) => Padding(
            padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
            child: OutlinedButton.icon(
              onPressed: () => _showApiKeyDialog(has),
              icon: Icon(has ? Icons.edit : Icons.add),
              label: Text(has ? 'Update API Key' : 'Add API Key'),
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const Divider(indent: 72),

        // Offline AI option
        RadioListTile<AiProvider>(
          title: const Text('TinyLlama (Offline)'),
          subtitle: Text(
            gemmaService.isModelDownloaded
                ? 'Model ready (~1.15 GB)'
                : 'Model not downloaded',
            style: TextStyle(
              color: gemmaService.isModelDownloaded ? Colors.green : Colors.orange,
            ),
          ),
          secondary: const Icon(Icons.offline_bolt_outlined),
          value: AiProvider.gemma,
          groupValue: currentProvider,
          onChanged: gemmaService.isModelDownloaded
              ? (value) async {
                  if (value != null) {
                    await AiProviderManager.instance.setProvider(value);
                    ref.read(aiProviderProvider.notifier).state = value;
                  }
                }
              : null,
        ),

        // Model download/delete button
        Padding(
          padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
          child: gemmaService.isModelDownloaded
              ? OutlinedButton.icon(
                  onPressed: () => _confirmDeleteModel(),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Delete Model', style: TextStyle(color: Colors.red)),
                )
              : _isDownloadingGemma
                  ? Column(
                      children: [
                        LinearProgressIndicator(value: _gemmaProgress),
                        const SizedBox(height: 8),
                        Text('Downloading: ${(_gemmaProgress * 100).toInt()}%'),
                      ],
                    )
                  : ElevatedButton.icon(
                      onPressed: _downloadGemma,
                      icon: const Icon(Icons.download),
                      label: const Text('Download TinyLlama (~1.15 GB)'),
                    ),
        ),
      ],
    );
  }

  Widget _buildTranslationsSection(List<BibleTranslation> translations) {
    return Column(
      children: translations.map((trans) {
        final isDownloading = _downloadingTranslation == trans.id;

        return ListTile(
          leading: Icon(
            trans.isDownloaded ? Icons.check_circle : Icons.cloud_download_outlined,
            color: trans.isDownloaded ? Colors.green : null,
          ),
          title: Text(trans.name),
          subtitle: Text(
            trans.isDownloaded
                ? '${trans.verseCount} verses'
                : trans.isPublicDomain
                    ? 'Public domain - tap to download'
                    : 'Licensed',
          ),
          trailing: isDownloading
              ? SizedBox(
                  width: 100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LinearProgressIndicator(value: _downloadProgress),
                      const SizedBox(height: 4),
                      Text('${(_downloadProgress * 100).toInt()}%',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                )
              : trans.isDownloaded
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDeleteTranslation(trans),
                    )
                  : IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: trans.isPublicDomain
                          ? () => _downloadTranslation(trans.id)
                          : null,
                    ),
        );
      }).toList(),
    );
  }

  Future<void> _downloadTranslation(String translationId) async {
    setState(() {
      _downloadingTranslation = translationId;
      _downloadProgress = 0;
    });

    try {
      await BibleDownloadService.instance.downloadTranslation(
        translationId,
        onProgress: (current, total, message) {
          setState(() {
            _downloadProgress = current / total;
          });
        },
      );

      ref.invalidate(translationsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$translationId downloaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _downloadingTranslation = null;
        _downloadProgress = 0;
      });
    }
  }

  Future<void> _downloadGemma() async {
    setState(() {
      _isDownloadingGemma = true;
      _gemmaProgress = 0;
    });

    try {
      await for (final progress in GemmaAiService.instance.downloadModel()) {
        setState(() {
          _gemmaProgress = progress;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gemma model downloaded successfully')),
        );
        setState(() {}); // Refresh UI
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gemma download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isDownloadingGemma = false;
        _gemmaProgress = 0;
      });
    }
  }

  void _confirmDeleteModel() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Offline Model?'),
        content: const Text(
          'This will delete the downloaded TinyLlama model (~1.15 GB). '
          'You can re-download it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await GemmaAiService.instance.deleteModel();

              // Switch to Grok if currently using Gemma
              if (AiProviderManager.instance.currentProvider == AiProvider.gemma) {
                await AiProviderManager.instance.setProvider(AiProvider.grok);
                ref.read(aiProviderProvider.notifier).state = AiProvider.grok;
              }

              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Offline model deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTranslation(BibleTranslation trans) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${trans.abbreviation}?'),
        content: Text(
          'This will delete the ${trans.name}. You can re-download it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await BibleDownloadService.instance.deleteTranslation(trans.id);
              ref.invalidate(translationsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${trans.abbreviation} deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(bool hasExisting) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hasExisting ? 'Update API Key' : 'Add API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Grok API key from xAI to enable cloud AI conversations.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Get your key at: console.x.ai',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'xai-...',
                border: const OutlineInputBorder(),
                suffixIcon: hasExisting
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          await HamorahAiService.instance.clearApiKey();
                          ref.invalidate(apiKeyStatusProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('API key removed')),
                          );
                        },
                      )
                    : null,
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final key = controller.text.trim();
              if (key.isNotEmpty) {
                await HamorahAiService.instance.saveApiKey(key);
                ref.invalidate(apiKeyStatusProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API key saved')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDataView() {
    final userRepo = UserDataRepository.instance;
    final convRepo = ConversationRepository.instance;

    final bookmarks = userRepo.getAllBookmarks().length;
    final highlights = userRepo.getAllHighlights().length;
    final notes = userRepo.getAllNotes().length;
    final conversations = convRepo.getAllConversations().length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DataRow('Bookmarks', bookmarks),
            _DataRow('Highlights', highlights),
            _DataRow('Notes', notes),
            _DataRow('Conversations', conversations),
            const SizedBox(height: 16),
            const Text(
              'All data is stored locally on your device.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmClearConversations() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversations?'),
        content: const Text(
          'This will permanently delete all your conversations with Hamorah.\n\n'
          'Your bookmarks, highlights, and notes will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ConversationRepository.instance.clearAll();
              if (context.mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Conversations cleared')),
              );
            },
            child: Text(
              'Clear',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text(
          'This will permanently delete:\n'
          '• All conversations\n'
          '• All bookmarks and highlights\n'
          '• All notes\n'
          '• Your API key\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await UserDataRepository.instance.clearAll();
              await ConversationRepository.instance.clearAll();
              await HamorahAiService.instance.clearApiKey();
              ref.invalidate(apiKeyStatusProvider);
              if (context.mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data deleted')),
              );
            },
            child: Text(
              'Delete Everything',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Hamorah',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2024 Hamorah\nThe Teacher - Your guide to Scripture',
      children: [
        const SizedBox(height: 16),
        const Text(
          'Hamorah is like having a wise, patient Bible teacher in your pocket - '
          'one who never tells you what to do, but always helps you discover '
          "what God's Word says about your life.",
        ),
      ],
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Hamorah Privacy Policy\n\n'
            '1. Local-First Data Storage\n'
            'All your data (conversations, bookmarks, highlights, notes) is stored '
            'locally on your device.\n\n'
            '2. AI Communications\n'
            '• Grok Mode: Messages sent to xAI\'s Grok API for responses.\n'
            '• Gemma Mode: All AI processing happens on your device - completely private.\n\n'
            '3. Your API Key\n'
            'Your Grok API key is stored securely using platform-native secure storage.\n\n'
            '4. No Tracking\n'
            'We do not collect analytics, track usage, or share any data.\n\n'
            '5. Your Control\n'
            'Delete all your data anytime from Settings.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final int count;

  const _DataRow(this.label, this.count);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            count.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryLight),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red.shade700 : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red.shade700 : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
