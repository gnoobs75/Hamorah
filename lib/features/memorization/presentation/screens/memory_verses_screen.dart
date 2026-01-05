import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/memorization/models/memorization_models.dart';
import '../../providers/memorization_providers.dart';

class MemoryVersesScreen extends ConsumerWidget {
  const MemoryVersesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(memorizationStatsProvider);
    final allVerses = ref.watch(allMemoryVersesProvider);
    final dueVerses = ref.watch(dueVersesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memorization'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // TODO: Show review history
            },
            tooltip: 'Review History',
          ),
        ],
      ),
      body: allVerses.isEmpty
          ? _EmptyState()
          : CustomScrollView(
              slivers: [
                // Stats Header
                SliverToBoxAdapter(
                  child: _StatsHeader(stats: stats),
                ),

                // Practice Button
                if (dueVerses.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        onPressed: () => context.push('/memorization/practice'),
                        icon: const Icon(Icons.play_arrow),
                        label: Text('Practice ${dueVerses.length} Due Verses'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ),

                // Verses List
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Your Verses',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),

                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final verse = allVerses[index];
                      return _VerseCard(verse: verse);
                    },
                    childCount: allVerses.length,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to add verse screen or show verse picker
          _showAddVerseDialog(context, ref);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Verse'),
      ),
    );
  }

  void _showAddVerseDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Verse to Memorize'),
        content: const Text(
          'To add a verse for memorization, go to the Bible reader, long-press on a verse, and select "Memorize".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/reader');
            },
            child: const Text('Go to Reader'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Verses Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start memorizing Scripture by adding verses from the Bible reader.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.go('/reader'),
              icon: const Icon(Icons.menu_book),
              label: const Text('Go to Bible Reader'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final MemorizationStats stats;

  const _StatsHeader({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                icon: Icons.library_books,
                value: '${stats.totalVerses}',
                label: 'Total',
              ),
              _StatItem(
                icon: Icons.schedule,
                value: '${stats.dueCount}',
                label: 'Due',
                color: stats.dueCount > 0 ? Colors.orange : null,
              ),
              _StatItem(
                icon: Icons.check_circle,
                value: '${stats.masteredCount}',
                label: 'Mastered',
                color: Colors.green,
              ),
              _StatItem(
                icon: Icons.local_fire_department,
                value: '${stats.streak}',
                label: 'Streak',
                color: Colors.deepOrange,
              ),
            ],
          ),
          if (stats.totalVerses > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stats.averageMastery / 100,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.surface.withOpacity(0.3),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${stats.averageMastery.round()}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Average Mastery',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, color: color ?? theme.colorScheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _VerseCard extends ConsumerWidget {
  final MemoryVerse verse;

  const _VerseCard({required this.verse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () {
          // TODO: Show verse detail
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      verse.reference,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _StatusChip(verse: verse),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                verse.verseText,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MasteryIndicator(level: verse.masteryLevel),
                  const Spacer(),
                  if (verse.isDueForReview && !verse.mastered)
                    TextButton.icon(
                      onPressed: () {
                        // Start practice with just this verse
                        ref.read(practiceSessionProvider.notifier).startSession([verse]);
                        context.push('/memorization/practice');
                      },
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Practice'),
                    ),
                  PopupMenuButton<String>(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'reset',
                        child: ListTile(
                          leading: Icon(Icons.refresh),
                          title: Text('Reset Progress'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Remove', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'reset') {
                        ref.read(memorizationNotifierProvider.notifier).resetVerse(verse.id);
                      } else if (value == 'delete') {
                        _confirmDelete(context, ref);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Verse?'),
        content: Text('Remove "${verse.reference}" from your memorization list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ref.read(memorizationNotifierProvider.notifier).deleteVerse(verse.id);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final MemoryVerse verse;

  const _StatusChip({required this.verse});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    if (verse.mastered) {
      color = Colors.green;
      text = 'Mastered';
    } else if (verse.repetitions == 0) {
      color = Colors.blue;
      text = 'New';
    } else if (verse.isDueForReview) {
      color = Colors.orange;
      text = 'Due';
    } else {
      color = Colors.grey;
      text = 'Learning';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MasteryIndicator extends StatelessWidget {
  final int level;

  const _MasteryIndicator({required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: level / 100,
              minHeight: 4,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(_getColor()),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$level%',
          style: TextStyle(
            fontSize: 12,
            color: _getColor(),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getColor() {
    if (level >= 80) return Colors.green;
    if (level >= 50) return Colors.orange;
    return Colors.grey;
  }
}
