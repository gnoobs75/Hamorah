import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/tts_service.dart';
import '../../../../data/bible/models/bible_models.dart';

/// Floating audio controls widget
class AudioControls extends ConsumerWidget {
  const AudioControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);

    if (!playerState.isPlaying && !playerState.isPaused) {
      return const SizedBox.shrink();
    }

    return _AudioControlsBar(playerState: playerState);
  }
}

class _AudioControlsBar extends ConsumerWidget {
  final AudioPlayerState playerState;

  const _AudioControlsBar({required this.playerState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(audioPlayerProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress indicator
            if (playerState.totalVerses > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      'Verse ${playerState.currentVerseIndex + 1}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (playerState.currentVerseIndex + 1) / playerState.totalVerses,
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${playerState.totalVerses}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Speed button
                PopupMenuButton<double>(
                  icon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${playerState.rate}x',
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  onSelected: (rate) => notifier.setRate(rate),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 0.5, child: Text('0.5x')),
                    const PopupMenuItem(value: 0.75, child: Text('0.75x')),
                    const PopupMenuItem(value: 1.0, child: Text('1.0x')),
                    const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                    const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                    const PopupMenuItem(value: 2.0, child: Text('2.0x')),
                  ],
                ),

                const Spacer(),

                // Previous
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: playerState.currentVerseIndex > 0
                      ? () => notifier.previous()
                      : null,
                ),

                // Play/Pause
                IconButton(
                  icon: Icon(
                    playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 32,
                  ),
                  onPressed: () {
                    if (playerState.isPlaying) {
                      notifier.pause();
                    } else {
                      notifier.resume();
                    }
                  },
                ),

                // Next
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: playerState.currentVerseIndex < playerState.totalVerses - 1
                      ? () => notifier.next()
                      : null,
                ),

                const Spacer(),

                // Stop
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: () => notifier.stop(),
                ),
              ],
            ),

            // Chapter info
            if (playerState.bookName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${playerState.bookName} ${playerState.chapter}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mini audio player for app bar
class MiniAudioPlayer extends ConsumerWidget {
  const MiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);

    if (!playerState.isPlaying && !playerState.isPaused) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(audioPlayerProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              playerState.isPlaying ? Icons.pause_circle : Icons.play_circle,
              color: theme.colorScheme.primary,
            ),
            onPressed: () {
              if (playerState.isPlaying) {
                notifier.pause();
              } else {
                notifier.resume();
              }
            },
          ),
          IconButton(
            icon: Icon(
              Icons.stop_circle,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () => notifier.stop(),
          ),
        ],
      ),
    );
  }
}

/// Audio play button for starting playback
class AudioPlayButton extends ConsumerWidget {
  final List<BibleVerse> verses;
  final String bookName;
  final int chapter;
  final int? startFromVerse;

  const AudioPlayButton({
    super.key,
    required this.verses,
    required this.bookName,
    required this.chapter,
    this.startFromVerse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);

    return IconButton(
      icon: Icon(
        playerState.isPlaying ? Icons.volume_up : Icons.play_circle_outline,
      ),
      tooltip: playerState.isPlaying ? 'Audio playing' : 'Listen to chapter',
      onPressed: playerState.isPlaying
          ? null
          : () {
              ref.read(audioPlayerProvider.notifier).playChapter(
                    verses: verses,
                    bookName: bookName,
                    chapter: chapter,
                    startFromVerse: startFromVerse ?? 0,
                  );
            },
    );
  }
}

/// Bottom sheet for audio settings
class AudioSettingsSheet extends ConsumerWidget {
  const AudioSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio Settings',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Speed slider
          Text(
            'Playback Speed: ${playerState.rate}x',
            style: theme.textTheme.titleSmall,
          ),
          Slider(
            value: playerState.rate,
            min: 0.5,
            max: 2.0,
            divisions: 6,
            label: '${playerState.rate}x',
            onChanged: (value) => notifier.setRate(value),
          ),

          const SizedBox(height: 16),

          // Speed presets
          Wrap(
            spacing: 8,
            children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((rate) {
              final isSelected = playerState.rate == rate;
              return ChoiceChip(
                label: Text('${rate}x'),
                selected: isSelected,
                onSelected: (_) => notifier.setRate(rate),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Show audio settings
void showAudioSettings(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (context) => const AudioSettingsSheet(),
  );
}
