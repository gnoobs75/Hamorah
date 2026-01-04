import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/ai/hamorah_ai_service.dart';
import '../../../../data/user/user_data_repository.dart';
import '../../../../data/conversation/conversation_repository.dart';

/// Provider for API key status
final apiKeyStatusProvider = FutureProvider<bool>((ref) async {
  return await HamorahAiService.instance.hasApiKey();
});

/// Settings screen - privacy, appearance, translations
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _darkMode = false;
  String _defaultTranslation = 'KJV';

  @override
  Widget build(BuildContext context) {
    final hasApiKey = ref.watch(apiKeyStatusProvider);

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
          // AI section
          _SectionHeader('AI & API', Icons.psychology_outlined),
          hasApiKey.when(
            data: (hasKey) => _SettingsTile(
              icon: Icons.key,
              title: 'Grok API Key',
              subtitle: hasKey ? 'Configured' : 'Not configured',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasKey)
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => _showApiKeyDialog(hasKey),
            ),
            loading: () => _SettingsTile(
              icon: Icons.key,
              title: 'Grok API Key',
              subtitle: 'Checking...',
              trailing: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => _SettingsTile(
              icon: Icons.key,
              title: 'Grok API Key',
              subtitle: 'Error checking status',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showApiKeyDialog(false),
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
          _SettingsTile(
            icon: Icons.text_fields,
            title: 'Text Size',
            subtitle: 'Adjust Scripture text size',
            trailing: const Icon(Icons.chevron_right),
            onTap: _showTextSizeDialog,
          ),

          const Divider(height: 32),

          // Bible section
          _SectionHeader('Bible', Icons.menu_book_outlined),
          _SettingsTile(
            icon: Icons.translate,
            title: 'Default Translation',
            subtitle: _defaultTranslation,
            trailing: const Icon(Icons.chevron_right),
            onTap: _showTranslationPicker,
          ),
          _SettingsTile(
            icon: Icons.download_outlined,
            title: 'Manage Translations',
            subtitle: 'Download or remove translations',
            trailing: const Icon(Icons.chevron_right),
            onTap: _showTranslationManager,
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
                    'Your API key is stored securely on your device. We never see or store your conversations on any server.',
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
              'Enter your Grok API key from xAI to enable AI conversations.',
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
              'All data is stored locally on your device and encrypted.',
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

  void _showTextSizeDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Text size settings coming soon')),
    );
  }

  void _showTranslationPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Default Translation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('KJV'),
              subtitle: const Text('King James Version'),
              leading: _defaultTranslation == 'KJV'
                  ? Icon(Icons.check_circle, color: AppColors.primaryLight)
                  : const Icon(Icons.radio_button_unchecked),
              onTap: () {
                setState(() => _defaultTranslation = 'KJV');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('NIV'),
              subtitle: const Text('New International Version (Coming soon)'),
              leading: const Icon(Icons.lock_outline, color: Colors.grey),
              enabled: false,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showTranslationManager() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Translation manager coming soon')),
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
            'locally on your device and encrypted.\n\n'
            '2. API Communications\n'
            'When you chat with Hamorah, your message is sent to xAI\'s Grok API '
            'to generate a response. We do not store these conversations on any server.\n\n'
            '3. Your API Key\n'
            'Your Grok API key is stored securely on your device using platform-native '
            'secure storage (Keychain on iOS, Keystore on Android).\n\n'
            '4. No Tracking\n'
            'We do not collect analytics, track your usage, or share any data with third parties.\n\n'
            '5. Your Control\n'
            'You can delete all your data at any time from Settings.',
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
