import 'package:flutter/material.dart';

import '../../../../data/reading_plans/models/reading_plan_models.dart';

class PlanCard extends StatelessWidget {
  final ReadingPlan plan;
  final UserPlanProgress? progress;
  final VoidCallback? onTap;

  const PlanCard({
    super.key,
    required this.plan,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasProgress = progress != null;
    final progressPercent = progress?.getProgressPercent(plan.totalDays) ?? 0.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient
            Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getCategoryColor(plan.category),
                    _getCategoryColor(plan.category).withOpacity(0.7),
                  ],
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(
                    _getCategoryIcon(plan.category),
                    color: Colors.white.withOpacity(0.8),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${plan.totalDays} days',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasProgress) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(progressPercent * 100).round()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.description,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasProgress) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressPercent,
                        minHeight: 6,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Day ${progress!.currentDay} of ${plan.totalDays}',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (progress!.streakCount > 0)
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                              const SizedBox(width: 2),
                              Text(
                                '${progress!.streakCount} day streak',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'whole-bible':
        return Colors.indigo;
      case 'new-testament':
        return Colors.blue;
      case 'old-testament':
        return Colors.brown;
      case 'gospels':
        return Colors.red;
      case 'psalms':
        return Colors.purple;
      case 'topical':
        return Colors.teal;
      default:
        return Colors.grey;
    }
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
