import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/reading_plans/models/reading_plan_models.dart';
import '../../../../data/reading_plans/reading_plan_repository.dart';
import '../../providers/reading_plan_providers.dart';

class DailyReadingScreen extends ConsumerStatefulWidget {
  final String planId;
  final int dayNumber;

  const DailyReadingScreen({
    super.key,
    required this.planId,
    required this.dayNumber,
  });

  @override
  ConsumerState<DailyReadingScreen> createState() => _DailyReadingScreenState();
}

class _DailyReadingScreenState extends ConsumerState<DailyReadingScreen> {
  final PageController _pageController = PageController();
  int _currentPassageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planProvider(widget.planId));
    final progress = ref.watch(planProgressProvider(widget.planId));

    if (plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Plan not found')),
      );
    }

    if (widget.dayNumber < 1 || widget.dayNumber > plan.days.length) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Day not found')),
      );
    }

    final day = plan.days[widget.dayNumber - 1];
    final isCompleted = progress?.isDayCompleted(widget.dayNumber) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Day ${widget.dayNumber}'),
            Text(
              plan.name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (progress != null && !isCompleted)
            TextButton.icon(
              onPressed: () => _markComplete(progress),
              icon: const Icon(Icons.check),
              label: const Text('Complete'),
            ),
          if (isCompleted)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.check_circle, color: Colors.green),
            ),
        ],
      ),
      body: Column(
        children: [
          // Day Info Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (day.theme != null) ...[
                  Text(
                    day.theme!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                  const SizedBox(height: 8),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: day.passages.asMap().entries.map((entry) {
                    final index = entry.key;
                    final passage = entry.value;
                    final isActive = index == _currentPassageIndex;

                    return ActionChip(
                      label: Text(passage),
                      backgroundColor: isActive
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      labelStyle: isActive
                          ? TextStyle(color: Theme.of(context).colorScheme.onPrimary)
                          : null,
                      onPressed: () {
                        setState(() => _currentPassageIndex = index);
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Passage Content
          Expanded(
            child: day.passages.length > 1
                ? PageView.builder(
                    controller: _pageController,
                    itemCount: day.passages.length,
                    onPageChanged: (index) {
                      setState(() => _currentPassageIndex = index);
                    },
                    itemBuilder: (context, index) {
                      return _PassageContent(passage: day.passages[index]);
                    },
                  )
                : _PassageContent(passage: day.passages.first),
          ),

          // Navigation
          if (day.passages.length > 1)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  day.passages.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentPassageIndex
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _BottomNavigation(
        planId: widget.planId,
        dayNumber: widget.dayNumber,
        totalDays: plan.totalDays,
        isCompleted: isCompleted,
        progress: progress,
      ),
    );
  }

  void _markComplete(UserPlanProgress progress) {
    ref.read(readingPlanNotifierProvider.notifier).completeDay(
          progress.id,
          widget.dayNumber,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Day ${widget.dayNumber} completed!'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // TODO: Implement undo
          },
        ),
      ),
    );
  }
}

class _PassageContent extends StatelessWidget {
  final String passage;

  const _PassageContent({required this.passage});

  @override
  Widget build(BuildContext context) {
    // TODO: Integrate with Bible repository to fetch actual verses
    // For now, show a placeholder with instructions

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  passage,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reading Instructions',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Open your Bible or tap the button below to read $passage in the Bible reader.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Navigate to Bible reader with this passage
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opening Bible reader...'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open in Bible Reader'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Devotional content placeholder
          Text(
            'Reflection',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Take a moment to reflect on what you read. Consider:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _ReflectionPoint(
            number: 1,
            text: 'What does this passage teach about God?',
          ),
          _ReflectionPoint(
            number: 2,
            text: 'What does it teach about humanity?',
          ),
          _ReflectionPoint(
            number: 3,
            text: 'How can you apply this to your life today?',
          ),
        ],
      ),
    );
  }
}

class _ReflectionPoint extends StatelessWidget {
  final int number;
  final String text;

  const _ReflectionPoint({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigation extends ConsumerWidget {
  final String planId;
  final int dayNumber;
  final int totalDays;
  final bool isCompleted;
  final UserPlanProgress? progress;

  const _BottomNavigation({
    required this.planId,
    required this.dayNumber,
    required this.totalDays,
    required this.isCompleted,
    required this.progress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canGoPrevious = dayNumber > 1;
    final canGoNext = dayNumber < totalDays;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (canGoPrevious)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DailyReadingScreen(
                        planId: planId,
                        dayNumber: dayNumber - 1,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
              )
            else
              const SizedBox(width: 100),
            const Spacer(),
            if (!isCompleted && progress != null)
              FilledButton(
                onPressed: () {
                  ref.read(readingPlanNotifierProvider.notifier).completeDay(
                        progress!.id,
                        dayNumber,
                      );
                  if (canGoNext) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DailyReadingScreen(
                          planId: planId,
                          dayNumber: dayNumber + 1,
                        ),
                      ),
                    );
                  } else {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Congratulations! You completed the plan!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Text(canGoNext ? 'Complete & Next' : 'Complete Plan'),
              ),
            const Spacer(),
            if (canGoNext)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DailyReadingScreen(
                        planId: planId,
                        dayNumber: dayNumber + 1,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
              )
            else
              const SizedBox(width: 100),
          ],
        ),
      ),
    );
  }
}
