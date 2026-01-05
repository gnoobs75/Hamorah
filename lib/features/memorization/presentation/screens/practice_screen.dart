import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/memorization/models/memorization_models.dart';
import '../../providers/memorization_providers.dart';
import '../widgets/flashcard_widget.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  @override
  void initState() {
    super.initState();
    // Start session if not already started
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(practiceSessionProvider);
      if (session == null) {
        final dueVerses = ref.read(dueVersesProvider);
        if (dueVerses.isNotEmpty) {
          ref.read(practiceSessionProvider.notifier).startSession(dueVerses);
        } else {
          // No due verses, use all verses
          final allVerses = ref.read(allMemoryVersesProvider);
          if (allVerses.isNotEmpty) {
            ref.read(practiceSessionProvider.notifier).startSession(allVerses);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(practiceSessionProvider);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice')),
        body: const Center(child: Text('No verses to practice')),
      );
    }

    if (session.isComplete) {
      return _CompletionScreen(session: session);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${session.currentIndex + 1} / ${session.verses.length}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmExit(context),
        ),
        actions: [
          // Mode selector
          PopupMenuButton<PracticeMode>(
            icon: const Icon(Icons.tune),
            tooltip: 'Practice Mode',
            onSelected: (mode) {
              ref.read(practiceSessionProvider.notifier).changeMode(mode);
            },
            itemBuilder: (context) => PracticeMode.values.map((mode) {
              return PopupMenuItem(
                value: mode,
                child: ListTile(
                  leading: Icon(
                    mode == session.mode ? Icons.check : null,
                  ),
                  title: Text(mode.title),
                  subtitle: Text(mode.description, style: const TextStyle(fontSize: 12)),
                  contentPadding: EdgeInsets.zero,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: session.progress,
            minHeight: 4,
          ),

          // Main content
          Expanded(
            child: _buildPracticeContent(session),
          ),

          // Response buttons
          if (session.showingAnswer)
            _ResponseButtons()
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () {
                  ref.read(practiceSessionProvider.notifier).showAnswer();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Show Answer'),
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPracticeContent(PracticeSessionState session) {
    final verse = session.currentVerse;
    if (verse == null) return const SizedBox.shrink();

    switch (session.mode) {
      case PracticeMode.flashcard:
        return FlashcardWidget(
          verse: verse,
          showAnswer: session.showingAnswer,
        );
      case PracticeMode.fillBlank:
        return _FillBlankWidget(
          verse: verse,
          showAnswer: session.showingAnswer,
        );
      case PracticeMode.firstLetters:
        return _FirstLettersWidget(
          verse: verse,
          showAnswer: session.showingAnswer,
        );
      case PracticeMode.typing:
        return _TypingWidget(
          verse: verse,
          showAnswer: session.showingAnswer,
        );
    }
  }

  void _confirmExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Practice?'),
        content: const Text('Your progress in this session will be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(practiceSessionProvider.notifier).endSession();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}

class _ResponseButtons extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: ResponseQuality.values.map((quality) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _ResponseButton(
                quality: quality,
                onTap: () {
                  ref.read(practiceSessionProvider.notifier).processResponse(quality);
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ResponseButton extends StatelessWidget {
  final ResponseQuality quality;
  final VoidCallback onTap;

  const _ResponseButton({required this.quality, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _getColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _getColor().withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              quality.label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getColor(),
              ),
            ),
            Text(
              quality.description,
              style: TextStyle(
                fontSize: 10,
                color: _getColor().withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getColor() {
    switch (quality) {
      case ResponseQuality.again:
        return Colors.red;
      case ResponseQuality.hard:
        return Colors.orange;
      case ResponseQuality.good:
        return Colors.blue;
      case ResponseQuality.easy:
        return Colors.green;
    }
  }
}

class _CompletionScreen extends ConsumerWidget {
  final PracticeSessionState session;

  const _CompletionScreen({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accuracy = session.verses.isNotEmpty
        ? (session.correctCount / session.verses.length * 100).round()
        : 0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.celebration,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Practice Complete!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              _StatRow(
                label: 'Verses Reviewed',
                value: '${session.verses.length}',
                icon: Icons.library_books,
              ),
              _StatRow(
                label: 'Correct',
                value: '${session.correctCount}',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              _StatRow(
                label: 'Accuracy',
                value: '$accuracy%',
                icon: Icons.analytics,
                color: accuracy >= 80 ? Colors.green : (accuracy >= 50 ? Colors.orange : Colors.red),
              ),
              _StatRow(
                label: 'Time',
                value: _formatDuration(session.elapsed),
                icon: Icons.timer,
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: () async {
                  await ref.read(practiceSessionProvider.notifier).endSession();
                  if (context.mounted) Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}m ${seconds}s';
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

// Fill in the blank widget
class _FillBlankWidget extends StatelessWidget {
  final MemoryVerse verse;
  final bool showAnswer;

  const _FillBlankWidget({required this.verse, required this.showAnswer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words = verse.verseText.split(' ');
    final blankIndices = _getBlankIndices(words.length);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            verse.reference,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 4,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: words.asMap().entries.map((entry) {
              final isBlank = blankIndices.contains(entry.key);
              if (isBlank && !showAnswer) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.primary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '_____',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                );
              }
              return Text(
                entry.value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isBlank ? FontWeight.bold : FontWeight.normal,
                  color: isBlank ? theme.colorScheme.primary : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<int> _getBlankIndices(int totalWords) {
    if (totalWords <= 3) return [totalWords ~/ 2];
    final blankCount = (totalWords * 0.3).round().clamp(2, 5);
    final indices = <int>[];
    final step = totalWords ~/ blankCount;
    for (var i = 0; i < blankCount; i++) {
      indices.add((step * i + step ~/ 2).clamp(0, totalWords - 1));
    }
    return indices;
  }
}

// First letters widget
class _FirstLettersWidget extends StatelessWidget {
  final MemoryVerse verse;
  final bool showAnswer;

  const _FirstLettersWidget({required this.verse, required this.showAnswer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words = verse.verseText.split(' ');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            verse.reference,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          if (!showAnswer)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: words.map((word) {
                final firstLetter = word.isNotEmpty ? word[0].toUpperCase() : '';
                return Text(
                  '$firstLetter...',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                );
              }).toList(),
            )
          else
            Text(
              verse.verseText,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

// Typing widget
class _TypingWidget extends StatefulWidget {
  final MemoryVerse verse;
  final bool showAnswer;

  const _TypingWidget({required this.verse, required this.showAnswer});

  @override
  State<_TypingWidget> createState() => _TypingWidgetState();
}

class _TypingWidgetState extends State<_TypingWidget> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.verse.reference,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          if (!widget.showAnswer) ...[
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Type the verse from memory...',
                border: OutlineInputBorder(),
              ),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your answer:',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(_controller.text),
                    const Divider(height: 24),
                    Text(
                      'Correct verse:',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.verse.verseText,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
