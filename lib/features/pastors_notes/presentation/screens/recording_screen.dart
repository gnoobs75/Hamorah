import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/pastors_notes_providers.dart';
import '../widgets/transcript_display.dart';
import '../widgets/verse_chip.dart';

/// Screen for recording a sermon session
class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  bool _isStarting = false;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() => _isStarting = true);

    final notifier = ref.read(activeSessionProvider.notifier);
    final success = await notifier.startSession();

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start recording. Please check microphone permissions.'),
          backgroundColor: Colors.red,
        ),
      );
      context.pop();
    }

    if (mounted) {
      setState(() => _isStarting = false);
    }
  }

  Future<void> _stopRecording() async {
    final notifier = ref.read(activeSessionProvider.notifier);
    final session = await notifier.stopSession();

    if (session != null && mounted) {
      ref.invalidate(sessionsProvider);
      context.go('/pastors-notes/${session.id}');
    } else if (mounted) {
      context.pop();
    }
  }

  Future<void> _pauseRecording() async {
    final notifier = ref.read(activeSessionProvider.notifier);
    await notifier.pauseSession();
  }

  Future<void> _resumeRecording() async {
    final notifier = ref.read(activeSessionProvider.notifier);
    await notifier.resumeSession();
  }

  Future<void> _cancelRecording() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Recording?'),
        content: const Text('All recorded content will be lost. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Recording'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Recording'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final notifier = ref.read(activeSessionProvider.notifier);
      await notifier.cancelSession();
      context.pop();
    }
  }

  void _addNote() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Quick Note',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter your note...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final note = _noteController.text.trim();
                if (note.isNotEmpty) {
                  ref.read(activeSessionProvider.notifier).addNote(note);
                  _noteController.clear();
                }
                Navigator.pop(ctx);
              },
              child: const Text('Add Note'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);

    if (_isStarting) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Starting recording...'),
            ],
          ),
        ),
      );
    }

    if (activeSession == null) {
      return const Scaffold(
        body: Center(
          child: Text('No active session'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancelRecording,
        ),
        title: Text(activeSession.session.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add),
            onPressed: _addNote,
            tooltip: 'Add Note',
          ),
        ],
      ),
      body: Column(
        children: [
          // Timer and status
          Container(
            padding: const EdgeInsets.all(16),
            color: activeSession.isListening
                ? AppColors.primaryLight.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  activeSession.isListening ? Icons.mic : Icons.mic_off,
                  color: activeSession.isListening ? AppColors.primaryLight : Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _formatDuration(activeSession.elapsed),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: activeSession.isListening ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    activeSession.isListening
                        ? 'LISTENING'
                        : activeSession.isPaused
                            ? 'PAUSED'
                            : 'STOPPED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Detected verses
          if (activeSession.verses.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: activeSession.verses.length,
                itemBuilder: (context, index) {
                  final verse = activeSession.verses[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: VerseChip(
                      reference: verse.reference,
                      onTap: () => _showVerseDetail(verse.reference, verse.verseText),
                    ),
                  );
                },
              ),
            ),

          // Transcript display
          Expanded(
            child: TranscriptDisplay(
              segments: activeSession.segments,
              currentPartialText: ref.read(activeSessionProvider.notifier).currentPartialText,
            ),
          ),

          // Control buttons
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Pause/Resume button
                FloatingActionButton(
                  heroTag: 'pause',
                  onPressed: activeSession.isListening
                      ? _pauseRecording
                      : _resumeRecording,
                  backgroundColor: Colors.orange,
                  child: Icon(
                    activeSession.isListening
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                ),

                // Stop button
                FloatingActionButton.large(
                  heroTag: 'stop',
                  onPressed: _stopRecording,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.stop, size: 32),
                ),

                // Note button
                FloatingActionButton(
                  heroTag: 'note',
                  onPressed: _addNote,
                  backgroundColor: AppColors.secondaryLight,
                  child: const Icon(Icons.note_add),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVerseDetail(String reference, String verseText) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reference,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primaryLight,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              verseText,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
