import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/reading_plans/models/reading_plan_models.dart';
import '../../providers/reading_plan_providers.dart';

class PlanDetailScreen extends ConsumerWidget {
  final String planId;

  const PlanDetailScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planData = ref.watch(planWithProgressProvider(planId));
    final plan = planData.plan;
    final progress = planData.progress;

    if (plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Plan not found')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                plan.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 8)],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getCategoryIcon(plan.category),
                    size: 80,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ),

          // Plan Info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.calendar_today,
                    label: '${plan.totalDays} days',
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.category,
                    label: PlanCategory.fromId(plan.category).displayName,
                  ),
                ],
              ),
            ),
          ),

          // Progress Section
          if (progress != null) ...[
            SliverToBoxAdapter(
              child: _ProgressSection(plan: plan, progress: progress),
            ),
          ],

          // Start/Resume Button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _ActionButton(plan: plan, progress: progress),
            ),
          ),

          // Days List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Daily Readings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  if (progress != null)
                    Text(
                      '${progress.completedDays.length}/${plan.totalDays} completed',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),

          // Days List
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final day = plan.days[index];
                final isCompleted = progress?.isDayCompleted(day.dayNumber) ?? false;
                final isCurrent = progress?.currentDay == day.dayNumber;

                return _DayTile(
                  day: day,
                  isCompleted: isCompleted,
                  isCurrent: isCurrent,
                  onTap: () => context.push('/reading-plans/$planId/day/${day.dayNumber}'),
                );
              },
              childCount: plan.days.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'whole-bible':
        return Icons.auto_stories;
      case 'new-testament':
        return Icons.menu_book;
      case 'old-testament':
        return Icons.history_edu;
      case 'gospels':
        return Icons.favorite;
      case 'psalms':
        return Icons.music_note;
      case 'topical':
        return Icons.topic;
      default:
        return Icons.book;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final ReadingPlan plan;
  final UserPlanProgress progress;

  const _ProgressSection({required this.plan, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressPercent = progress.getProgressPercent(plan.totalDays);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Progress',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${progress.completedDays.length} of ${plan.totalDays} days completed',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: progressPercent,
                      strokeWidth: 6,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Text(
                    '${(progressPercent * 100).round()}%',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatColumn(
                icon: Icons.local_fire_department,
                value: '${progress.streakCount}',
                label: 'Day Streak',
                color: Colors.orange,
              ),
              _StatColumn(
                icon: Icons.today,
                value: '${progress.currentDay}',
                label: 'Current Day',
                color: theme.colorScheme.primary,
              ),
              _StatColumn(
                icon: Icons.hourglass_bottom,
                value: '${progress.getDaysRemaining(plan.totalDays)}',
                label: 'Days Left',
                color: theme.colorScheme.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatColumn({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ActionButton extends ConsumerWidget {
  final ReadingPlan plan;
  final UserPlanProgress? progress;

  const _ActionButton({required this.plan, required this.progress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(readingPlanNotifierProvider.notifier);

    if (progress == null) {
      // Not started yet
      return FilledButton.icon(
        onPressed: () async {
          await notifier.startPlan(plan.id);
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start This Plan'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
      );
    }

    if (progress!.isComplete(plan.totalDays)) {
      // Completed
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                await notifier.resetProgress(progress!.id);
              },
              icon: const Icon(Icons.replay),
              label: const Text('Restart Plan'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      );
    }

    if (!progress!.isActive) {
      // Paused
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () async {
                await notifier.resumePlan(progress!.id);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume Plan'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _showOptionsMenu(context, ref),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      );
    }

    // Active
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push('/reading-plans/${plan.id}/day/${progress!.currentDay}'),
            icon: const Icon(Icons.menu_book),
            label: Text("Continue Day ${progress!.currentDay}"),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _showOptionsMenu(context, ref),
          icon: const Icon(Icons.more_vert),
        ),
      ],
    );
  }

  void _showOptionsMenu(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(readingPlanNotifierProvider.notifier);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress!.isActive)
              ListTile(
                leading: const Icon(Icons.pause),
                title: const Text('Pause Plan'),
                onTap: () {
                  Navigator.pop(context);
                  notifier.pausePlan(progress!.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.replay),
              title: const Text('Reset Progress'),
              onTap: () {
                Navigator.pop(context);
                _showResetConfirmation(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove Plan', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Progress?'),
        content: const Text('This will clear all your progress and start the plan from day 1.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(readingPlanNotifierProvider.notifier).resetProgress(progress!.id);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Plan?'),
        content: const Text('This will remove your progress for this plan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ref.read(readingPlanNotifierProvider.notifier).deleteProgress(progress!.id);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final ReadingDay day;
  final bool isCompleted;
  final bool isCurrent;
  final VoidCallback onTap;

  const _DayTile({
    required this.day,
    required this.isCompleted,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCompleted
              ? theme.colorScheme.primary
              : isCurrent
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
        ),
        child: Center(
          child: isCompleted
              ? Icon(Icons.check, color: theme.colorScheme.onPrimary, size: 20)
              : Text(
                  '${day.dayNumber}',
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? theme.colorScheme.primary : null,
                  ),
                ),
        ),
      ),
      title: Text(
        day.passagesDisplay,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          decoration: isCompleted ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: day.theme != null
          ? Text(
              day.theme!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            )
          : null,
      trailing: isCurrent
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'TODAY',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : const Icon(Icons.chevron_right),
    );
  }
}
