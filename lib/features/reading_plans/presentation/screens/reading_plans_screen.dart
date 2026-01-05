import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/reading_plans/models/reading_plan_models.dart';
import '../../providers/reading_plan_providers.dart';
import '../widgets/plan_card.dart';

class ReadingPlansScreen extends ConsumerWidget {
  const ReadingPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allPlans = ref.watch(allPlansProvider);
    final activeProgress = ref.watch(activeProgressProvider);
    final todaysReadings = ref.watch(todaysReadingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Plans'),
      ),
      body: allPlans.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No reading plans available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                // Today's Readings Section
                if (todaysReadings.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        "Today's Reading",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: todaysReadings.length,
                        itemBuilder: (context, index) {
                          final reading = todaysReadings[index];
                          return _TodayReadingCard(
                            plan: reading.plan,
                            progress: reading.progress,
                            day: reading.day,
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: Divider(height: 32)),
                ],

                // Active Plans Section
                if (activeProgress.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Your Active Plans',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final progress = activeProgress[index];
                        final plan = ref.watch(planProvider(progress.planId));
                        if (plan == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ActivePlanCard(plan: plan, progress: progress),
                        );
                      },
                      childCount: activeProgress.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],

                // Browse Plans Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Browse Plans',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),

                // Plans by Category
                ..._buildPlansByCategory(context, ref, allPlans),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  List<Widget> _buildPlansByCategory(BuildContext context, WidgetRef ref, List<ReadingPlan> allPlans) {
    final categories = <String, List<ReadingPlan>>{};

    for (final plan in allPlans) {
      categories.putIfAbsent(plan.category, () => []).add(plan);
    }

    final widgets = <Widget>[];

    for (final entry in categories.entries) {
      final categoryName = PlanCategory.fromId(entry.key).displayName;

      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              categoryName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
        ),
      );

      widgets.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final plan = entry.value[index];
              final progress = ref.watch(planProgressProvider(plan.id));
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: PlanCard(
                  plan: plan,
                  progress: progress,
                  onTap: () => context.push('/reading-plans/${plan.id}'),
                ),
              );
            },
            childCount: entry.value.length,
          ),
        ),
      );
    }

    return widgets;
  }
}

class _TodayReadingCard extends StatelessWidget {
  final ReadingPlan plan;
  final UserPlanProgress progress;
  final ReadingDay day;

  const _TodayReadingCard({
    required this.plan,
    required this.progress,
    required this.day,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: InkWell(
        onTap: () => context.push('/reading-plans/${plan.id}/day/${day.dayNumber}'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.today,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Day ${day.dayNumber} of ${plan.totalDays}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                plan.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                day.passagesDisplay,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              if (day.theme != null)
                Text(
                  day.theme!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActivePlanCard extends StatelessWidget {
  final ReadingPlan plan;
  final UserPlanProgress progress;

  const ActivePlanCard({
    super.key,
    required this.plan,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressPercent = progress.getProgressPercent(plan.totalDays);

    return Card(
      child: InkWell(
        onTap: () => context.push('/reading-plans/${plan.id}'),
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
                      plan.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (progress.streakCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            '${progress.streakCount}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressPercent,
                        minHeight: 8,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(progressPercent * 100).round()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Day ${progress.currentDay} of ${plan.totalDays} • ${progress.getDaysRemaining(plan.totalDays)} days left',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
