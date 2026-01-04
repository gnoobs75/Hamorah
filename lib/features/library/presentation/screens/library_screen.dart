import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/user/user_data_repository.dart';
import '../../../../data/user/models/user_data_models.dart';
import '../../../reader/presentation/screens/reader_screen.dart';

/// Library screen - bookmarks, highlights, notes
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Bookmarks'),
            Tab(text: 'Highlights'),
            Tab(text: 'Notes'),
          ],
          indicatorColor: AppColors.primaryLight,
          labelColor: AppColors.primaryLight,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BookmarksTab(),
          _HighlightsTab(),
          _NotesTab(),
        ],
      ),
    );
  }
}

class _BookmarksTab extends ConsumerWidget {
  const _BookmarksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for changes
    ref.watch(userDataRefreshProvider);
    final userDataRepo = ref.watch(userDataRepositoryProvider);
    final bookmarks = userDataRepo.getBookmarksSorted();

    if (bookmarks.isEmpty) {
      return const _EmptyTab(
        icon: Icons.bookmark_outline,
        title: 'No bookmarks yet',
        subtitle: 'Long-press any verse to bookmark it',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        return Dismissible(
          key: Key(bookmark.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) async {
            await userDataRepo.removeBookmark(bookmark.id);
            ref.read(userDataRefreshProvider.notifier).state++;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bookmark removed')),
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(Icons.bookmark, color: AppColors.primaryLight),
              title: Text(bookmark.reference),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bookmark.verseText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (bookmark.note != null && bookmark.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Note: ${bookmark.note}',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: AppColors.secondaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Navigate to verse
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Navigate to ${bookmark.reference}')),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _HighlightsTab extends ConsumerWidget {
  const _HighlightsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for changes
    ref.watch(userDataRefreshProvider);
    final userDataRepo = ref.watch(userDataRepositoryProvider);
    final highlights = userDataRepo.getAllHighlights();

    // Sort by date (newest first)
    highlights.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (highlights.isEmpty) {
      return const _EmptyTab(
        icon: Icons.format_color_fill,
        title: 'No highlights yet',
        subtitle: 'Long-press any verse to highlight it',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: highlights.length,
      itemBuilder: (context, index) {
        final highlight = highlights[index];
        final highlightColor = Color(highlight.color.colorValue);

        return Dismissible(
          key: Key(highlight.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) async {
            await userDataRepo.removeHighlight(highlight.id);
            ref.read(userDataRefreshProvider.notifier).state++;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Highlight removed')),
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: highlightColor, width: 4),
                ),
              ),
              child: ListTile(
                title: Text(highlight.reference),
                subtitle: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: highlightColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      highlight.verseText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Navigate to ${highlight.reference}')),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotesTab extends ConsumerWidget {
  const _NotesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for changes
    ref.watch(userDataRefreshProvider);
    final userDataRepo = ref.watch(userDataRepositoryProvider);
    final notes = userDataRepo.getNotesSorted();

    if (notes.isEmpty) {
      return const _EmptyTab(
        icon: Icons.note_outlined,
        title: 'No notes yet',
        subtitle: 'Add notes to verses as you study',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];

        return Dismissible(
          key: Key(note.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) async {
            await userDataRepo.removeNote(note.id);
            ref.read(userDataRefreshProvider.notifier).state++;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Note deleted')),
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(Icons.note, color: AppColors.secondaryLight),
              title: Text(note.reference),
              subtitle: Text(
                note.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showNoteDetail(context, ref, note, userDataRepo);
              },
            ),
          ),
        );
      },
    );
  }

  void _showNoteDetail(
    BuildContext context,
    WidgetRef ref,
    VerseNote note,
    UserDataRepository userDataRepo,
  ) {
    final controller = TextEditingController(text: note.content);

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Note on ${note.reference}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await userDataRepo.removeNote(note.id);
                    ref.read(userDataRefreshProvider.notifier).state++;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Note deleted')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Your note...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final content = controller.text.trim();
                  if (content.isNotEmpty) {
                    await userDataRepo.saveNote(
                      bookId: note.bookId,
                      chapter: note.chapter,
                      verse: note.verse,
                      bookName: note.bookName,
                      content: content,
                    );
                    ref.read(userDataRefreshProvider.notifier).state++;
                    if (ctx.mounted) Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Note updated')),
                    );
                  }
                },
                child: const Text('Save Changes'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }
}
