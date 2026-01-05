import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/pastors_notes/models/pastors_notes_models.dart';
import '../../../../data/pastors_notes/pastors_notes_repository.dart';
import '../../providers/pastors_notes_providers.dart';
import '../widgets/verse_chip.dart';

/// Screen for viewing a completed sermon session
class SessionDetailScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider(widget.sessionId));

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Session Not Found')),
            body: const Center(child: Text('This session could not be found.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(session.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editSession(session),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'export':
                      _exportSession(session);
                      break;
                    case 'delete':
                      _deleteSession(session);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.share),
                        SizedBox(width: 8),
                        Text('Export'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Transcript'),
                Tab(text: 'Verses'),
                Tab(text: 'Notes'),
              ],
              indicatorColor: AppColors.primaryLight,
              labelColor: AppColors.primaryLight,
            ),
          ),
          body: Column(
            children: [
              // Session info header
              _SessionInfoHeader(session: session),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _TranscriptTab(sessionId: widget.sessionId),
                    _VersesTab(sessionId: widget.sessionId),
                    _NotesTab(session: session),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  void _editSession(SermonSession session) {
    final controller = TextEditingController(text: session.title);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Title'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Session Title',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                session.title = newTitle;
                final repo = ref.read(pastorsNotesRepositoryProvider);
                await repo.updateSession(session);
                ref.invalidate(sessionProvider(widget.sessionId));
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _exportSession(SermonSession session) {
    final repo = ref.read(pastorsNotesRepositoryProvider);
    final transcript = repo.getFullTranscript(session.id);
    final verses = repo.getVersesForSession(session.id);

    final buffer = StringBuffer();
    buffer.writeln('# ${session.title}');
    buffer.writeln('Date: ${DateFormat.yMMMd().format(session.date)}');
    buffer.writeln('');
    buffer.writeln('## Transcript');
    buffer.writeln(transcript);
    buffer.writeln('');
    buffer.writeln('## Scripture References');
    for (final verse in verses) {
      buffer.writeln('### ${verse.reference}');
      buffer.writeln(verse.verseText);
      if (verse.userNote != null) {
        buffer.writeln('Note: ${verse.userNote}');
      }
      buffer.writeln('');
    }
    if (session.notes != null) {
      buffer.writeln('## Personal Notes');
      buffer.writeln(session.notes);
    }

    // For now, just copy to clipboard / show in dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export'),
        content: SingleChildScrollView(
          child: Text(buffer.toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _deleteSession(SermonSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session?'),
        content: Text('Are you sure you want to delete "${session.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(pastorsNotesRepositoryProvider);
              await repo.deleteSession(session.id);
              ref.invalidate(sessionsProvider);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Session deleted')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SessionInfoHeader extends StatelessWidget {
  final SermonSession session;

  const _SessionInfoHeader({required this.session});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();
    final timeFormat = DateFormat.jm();
    final duration = session.totalDuration;
    final durationStr = duration.inMinutes > 0
        ? '${duration.inMinutes}m ${duration.inSeconds % 60}s'
        : '${duration.inSeconds}s';

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primaryLight.withOpacity(0.05),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '${dateFormat.format(session.date)} at ${timeFormat.format(session.date)}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const Spacer(),
          Icon(Icons.timer, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            durationStr,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentLight.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book, size: 14, color: AppColors.accentLight),
                const SizedBox(width: 4),
                Text(
                  '${session.annotatedVerseIds.length}',
                  style: TextStyle(
                    color: AppColors.accentLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptTab extends ConsumerWidget {
  final String sessionId;

  const _TranscriptTab({required this.sessionId});

  String _formatOffset(Duration offset) {
    final minutes = offset.inMinutes;
    final seconds = offset.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segmentsAsync = ref.watch(sessionSegmentsProvider(sessionId));

    return segmentsAsync.when(
      data: (segments) {
        if (segments.isEmpty) {
          return const Center(
            child: Text('No transcript available'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: segments.length,
          itemBuilder: (context, index) {
            final segment = segments[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      _formatOffset(segment.offsetFromStart),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                            fontFamily: 'monospace',
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(segment.text),
                        if (segment.detectedVerseRefs.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 4,
                              children: segment.detectedVerseRefs.map((ref) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentLight.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    ref,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.accentLight,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _VersesTab extends ConsumerWidget {
  final String sessionId;

  const _VersesTab({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versesAsync = ref.watch(sessionVersesProvider(sessionId));

    return versesAsync.when(
      data: (verses) {
        if (verses.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No Scripture references detected'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: verses.length,
          itemBuilder: (context, index) {
            final verse = verses[index];
            return VerseCard(
              reference: verse.reference,
              verseText: verse.verseText,
              context: verse.context,
              note: verse.userNote,
              mentionedAt: verse.mentionedAt,
              onAddNote: () => _addNoteToVerse(context, ref, verse),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _addNoteToVerse(BuildContext context, WidgetRef ref, AnnotatedVerse verse) {
    final controller = TextEditingController(text: verse.userNote ?? '');

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Note on ${verse.reference}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Your thoughts on this verse...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  verse.userNote = controller.text.trim();
                  final repo = ref.read(pastorsNotesRepositoryProvider);
                  await repo.updateAnnotatedVerse(verse);
                  ref.invalidate(sessionVersesProvider(sessionId));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Note'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NotesTab extends ConsumerStatefulWidget {
  final SermonSession session;

  const _NotesTab({required this.session});

  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.session.notes ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'Add your personal notes about this sermon...',
                  border: OutlineInputBorder(),
                ),
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _controller.text = widget.session.notes ?? '';
                      setState(() => _isEditing = false);
                    },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      widget.session.notes = _controller.text.trim();
                      final repo = ref.read(pastorsNotesRepositoryProvider);
                      await repo.updateSession(widget.session);
                      ref.invalidate(sessionProvider(widget.session.id));
                      setState(() => _isEditing = false);
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final notes = widget.session.notes;
    if (notes == null || notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No personal notes yet'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.add),
              label: const Text('Add Notes'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            notes,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => setState(() => _isEditing = true),
            child: const Icon(Icons.edit),
          ),
        ),
      ],
    );
  }
}
