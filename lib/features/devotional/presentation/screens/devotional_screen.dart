import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/devotional_providers.dart';
import '../widgets/verse_reflection_card.dart';

class DevotionalScreen extends ConsumerStatefulWidget {
  const DevotionalScreen({super.key});

  @override
  ConsumerState<DevotionalScreen> createState() => _DevotionalScreenState();
}

class _DevotionalScreenState extends ConsumerState<DevotionalScreen> {
  @override
  void initState() {
    super.initState();
    // Load today's devotional
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(devotionalNotifierProvider.notifier).loadTodaysDevotional();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(devotionalNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Daily Devotional',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Icon(
                        Icons.wb_sunny_outlined,
                        size: 48,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('EEEE, MMMM d').format(DateTime.now()),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showSettings(context),
              ),
            ],
          ),

          // Content
          if (state.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.devotional != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Theme tag
                    if (state.devotional!.theme != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getThemeIcon(state.devotional!.theme!),
                              size: 16,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              state.devotional!.theme!,
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Verse Card
                    VerseReflectionCard(devotional: state.devotional!),

                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ref.read(devotionalNotifierProvider.notifier).getNewVerse();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Different Verse'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              // TODO: Open verse in Bible reader
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Opening ${state.devotional!.verseReference}...'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.menu_book),
                            label: const Text('Read in Bible'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Reflection Questions
                    Text(
                      'Reflection Questions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ReflectionQuestion(
                      number: 1,
                      question: 'What does this passage reveal about God\'s character?',
                    ),
                    _ReflectionQuestion(
                      number: 2,
                      question: 'How does this apply to your life today?',
                    ),
                    _ReflectionQuestion(
                      number: 3,
                      question: 'What is one action you can take based on this truth?',
                    ),

                    const SizedBox(height: 32),

                    // Prayer
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.volunteer_activism,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Prayer',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Take a moment to talk to God about what you\'ve read. Thank Him for His Word and ask Him to help you apply it today.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            )
          else
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wb_sunny_outlined,
                      size: 64,
                      color: theme.colorScheme.primary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No devotional loaded',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () {
                        ref.read(devotionalNotifierProvider.notifier).loadTodaysDevotional();
                      },
                      child: const Text('Load Devotional'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getThemeIcon(String theme) {
    switch (theme.toLowerCase()) {
      case 'trust':
        return Icons.shield;
      case 'hope':
        return Icons.star;
      case 'courage':
        return Icons.flash_on;
      case 'love':
        return Icons.favorite;
      case 'peace':
        return Icons.spa;
      case 'joy':
        return Icons.celebration;
      case 'wisdom':
        return Icons.psychology;
      case 'faith':
        return Icons.church;
      case 'prayer':
        return Icons.volunteer_activism;
      case 'strength':
        return Icons.fitness_center;
      case 'comfort':
        return Icons.healing;
      case 'grace':
        return Icons.auto_awesome;
      case 'forgiveness':
        return Icons.handshake;
      case 'guidance':
        return Icons.explore;
      default:
        return Icons.book;
    }
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _DevotionalSettingsSheet(),
    );
  }
}

class _ReflectionQuestion extends StatelessWidget {
  final int number;
  final String question;

  const _ReflectionQuestion({required this.number, required this.question});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primaryContainer,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              question,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _DevotionalSettingsSheet extends ConsumerWidget {
  const _DevotionalSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(devotionalNotifierProvider);
    final prefs = state.prefs;
    final notifier = ref.read(devotionalNotifierProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Devotional Settings',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),

                // Reminders toggle
                SwitchListTile(
                  title: const Text('Daily Reminders'),
                  subtitle: Text(
                    prefs.enabled
                        ? 'Reminder at ${prefs.reminderTimeString}'
                        : 'Get reminded to read your devotional',
                  ),
                  value: prefs.enabled,
                  onChanged: (value) async {
                    if (value) {
                      await notifier.enableReminders(prefs.reminderHour, prefs.reminderMinute);
                    } else {
                      await notifier.disableReminders();
                    }
                  },
                ),

                // Time picker
                if (prefs.enabled) ...[
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Reminder Time'),
                    subtitle: Text(prefs.reminderTimeString),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: prefs.reminderHour,
                          minute: prefs.reminderMinute,
                        ),
                      );
                      if (time != null) {
                        await notifier.updateReminderTime(time.hour, time.minute);
                      }
                    },
                  ),
                ],

                const Divider(),

                // AI reflection toggle
                SwitchListTile(
                  title: const Text('Include AI Reflection'),
                  subtitle: const Text('Generate a personalized reflection with each verse'),
                  value: prefs.includeReflection,
                  onChanged: (value) {
                    notifier.toggleReflection(value);
                  },
                ),

                const SizedBox(height: 24),

                // Test notification button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final notifications = ref.read(notificationServiceProvider);
                      await notifications.showTestNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Test notification sent!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Test Notification'),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}
