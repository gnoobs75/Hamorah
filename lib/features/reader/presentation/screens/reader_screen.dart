import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/bible/bible_repository.dart';
import '../../../../data/bible/models/bible_models.dart';
import '../../../../data/user/user_data_repository.dart';
import '../../../../data/user/models/user_data_models.dart';

/// State for the reader screen
class ReaderState {
  final int bookId;
  final int chapter;
  final String translation;

  const ReaderState({
    this.bookId = 43, // John
    this.chapter = 3,
    this.translation = 'KJV',
  });

  ReaderState copyWith({int? bookId, int? chapter, String? translation}) {
    return ReaderState(
      bookId: bookId ?? this.bookId,
      chapter: chapter ?? this.chapter,
      translation: translation ?? this.translation,
    );
  }
}

/// Provider for reader state
final readerStateProvider = StateProvider<ReaderState>((ref) => const ReaderState());

/// Provider to trigger UI refresh when user data changes
final userDataRefreshProvider = StateProvider<int>((ref) => 0);

/// Provider for current chapter data
final currentChapterProvider = FutureProvider<BibleChapter?>((ref) async {
  final state = ref.watch(readerStateProvider);
  final repository = ref.watch(bibleRepositoryProvider);

  try {
    return await repository.getChapter(state.bookId, state.chapter);
  } catch (e) {
    return null;
  }
});

/// Bible reader screen - read Scripture by book/chapter
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(readerStateProvider);
    final chapterAsync = ref.watch(currentChapterProvider);
    final repository = ref.watch(bibleRepositoryProvider);

    final book = repository.getBook(state.bookId);
    final bookName = book?.name ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: Text('$bookName ${state.chapter}'),
        actions: [
          // Translation selector
          TextButton(
            onPressed: _showTranslationPicker,
            child: Text(
              state.translation,
              style: TextStyle(
                color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Book/Chapter selector bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showBookPicker,
                    icon: const Icon(Icons.book_outlined, size: 18),
                    label: Text(bookName),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _showChapterPicker(book),
                  icon: const Icon(Icons.format_list_numbered, size: 18),
                  label: Text('Chapter ${state.chapter}'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scripture content
          Expanded(
            child: chapterAsync.when(
              data: (chapter) {
                if (chapter == null || chapter.verses.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildVerseList(chapter, isDark);
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => _buildErrorState(error.toString()),
            ),
          ),

          // Navigation buttons
          _buildNavigationBar(state, book),
        ],
      ),
    );
  }

  Widget _buildVerseList(BibleChapter chapter, bool isDark) {
    // Watch for user data changes
    ref.watch(userDataRefreshProvider);
    final userDataRepo = ref.read(userDataRepositoryProvider);
    final state = ref.read(readerStateProvider);

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: chapter.verses.length,
      itemBuilder: (context, index) {
        final verse = chapter.verses[index];
        final highlight = userDataRepo.getHighlight(
          state.bookId, state.chapter, verse.verse,
        );
        final isBookmarked = userDataRepo.isBookmarked(
          state.bookId, state.chapter, verse.verse,
        );

        return _VerseTile(
          verse: verse,
          isDark: isDark,
          highlight: highlight,
          isBookmarked: isBookmarked,
          onTap: () => _showVerseActions(verse),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No verses found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This chapter may not be loaded yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load chapter',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBar(ReaderState state, BibleBook? book) {
    final hasPrev = state.chapter > 1 || state.bookId > 1;
    final hasNext = (book != null && state.chapter < book.chapters) || state.bookId < 66;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: hasPrev ? _previousChapter : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
            TextButton.icon(
              onPressed: hasNext ? _nextChapter : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  void _previousChapter() {
    final state = ref.read(readerStateProvider);
    final repository = ref.read(bibleRepositoryProvider);

    if (state.chapter > 1) {
      ref.read(readerStateProvider.notifier).state = state.copyWith(
        chapter: state.chapter - 1,
      );
    } else if (state.bookId > 1) {
      final prevBook = repository.getBook(state.bookId - 1);
      if (prevBook != null) {
        ref.read(readerStateProvider.notifier).state = state.copyWith(
          bookId: prevBook.id,
          chapter: prevBook.chapters,
        );
      }
    }
  }

  void _nextChapter() {
    final state = ref.read(readerStateProvider);
    final repository = ref.read(bibleRepositoryProvider);
    final currentBook = repository.getBook(state.bookId);

    if (currentBook != null && state.chapter < currentBook.chapters) {
      ref.read(readerStateProvider.notifier).state = state.copyWith(
        chapter: state.chapter + 1,
      );
    } else if (state.bookId < 66) {
      ref.read(readerStateProvider.notifier).state = state.copyWith(
        bookId: state.bookId + 1,
        chapter: 1,
      );
    }
  }

  void _showTranslationPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Translation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _TranslationOption('KJV', 'King James Version', true, () {
              Navigator.pop(context);
            }),
            _TranslationOption('NIV', 'New International Version (Premium)', false, null),
            _TranslationOption('ESV', 'English Standard Version (Premium)', false, null),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showBookPicker() {
    final repository = ref.read(bibleRepositoryProvider);
    final books = repository.getAllBooks();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Book',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  final isSelected = book.id == ref.read(readerStateProvider).bookId;

                  // Add testament headers
                  Widget? header;
                  if (index == 0) {
                    header = _buildSectionHeader('Old Testament');
                  } else if (index == 39) {
                    header = _buildSectionHeader('New Testament');
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (header != null) header,
                      ListTile(
                        title: Text(book.name),
                        subtitle: Text('${book.chapters} chapters'),
                        leading: isSelected
                            ? Icon(Icons.check_circle, color: AppColors.primaryLight)
                            : const Icon(Icons.book_outlined),
                        onTap: () {
                          ref.read(readerStateProvider.notifier).state = ReaderState(
                            bookId: book.id,
                            chapter: 1,
                          );
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Colors.grey.withOpacity(0.1),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.primaryLight,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showChapterPicker(BibleBook? book) {
    if (book == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${book.name} - Select Chapter',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(book.chapters, (index) {
                final chapter = index + 1;
                final isSelected = chapter == ref.read(readerStateProvider).chapter;

                return InkWell(
                  onTap: () {
                    ref.read(readerStateProvider.notifier).state =
                        ref.read(readerStateProvider).copyWith(chapter: chapter);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryLight
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$chapter',
                      style: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight: isSelected ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showVerseActions(BibleVerse verse) {
    final state = ref.read(readerStateProvider);
    final book = ref.read(bibleRepositoryProvider).getBook(state.bookId);
    final userDataRepo = ref.read(userDataRepositoryProvider);
    final isBookmarked = userDataRepo.isBookmarked(state.bookId, state.chapter, verse.verse);
    final existingHighlight = userDataRepo.getHighlight(state.bookId, state.chapter, verse.verse);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${book?.name ?? ''} ${state.chapter}:${verse.verse}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionButton(
                  existingHighlight != null ? Icons.format_color_reset : Icons.format_color_fill,
                  existingHighlight != null ? 'Remove' : 'Highlight',
                  () async {
                    Navigator.pop(ctx);
                    if (existingHighlight != null) {
                      await userDataRepo.removeHighlight(existingHighlight.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Highlight removed')),
                      );
                    } else {
                      _showHighlightColorPicker(verse, book?.name ?? '');
                    }
                    // Refresh UI
                    ref.read(userDataRefreshProvider.notifier).state++;
                  },
                ),
                _ActionButton(Icons.note_add_outlined, 'Note', () {
                  Navigator.pop(ctx);
                  _showNoteEditor(verse, book?.name ?? '');
                }),
                _ActionButton(Icons.chat_outlined, 'Ask', () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ask Hamorah coming soon')),
                  );
                }),
                _ActionButton(
                  isBookmarked ? Icons.bookmark_remove : Icons.bookmark_add_outlined,
                  isBookmarked ? 'Unbookmark' : 'Bookmark',
                  () async {
                    Navigator.pop(ctx);
                    if (isBookmarked) {
                      await userDataRepo.removeBookmarkByVerse(
                        state.bookId, state.chapter, verse.verse,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bookmark removed')),
                      );
                    } else {
                      await userDataRepo.addBookmark(
                        bookId: state.bookId,
                        chapter: state.chapter,
                        verse: verse.verse,
                        verseText: verse.text,
                        bookName: book?.name ?? '',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bookmark added')),
                      );
                    }
                    // Refresh UI
                    ref.read(userDataRefreshProvider.notifier).state++;
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showHighlightColorPicker(BibleVerse verse, String bookName) {
    final state = ref.read(readerStateProvider);
    final userDataRepo = ref.read(userDataRepositoryProvider);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose highlight color',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: HighlightColor.values.map((color) {
                return InkWell(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await userDataRepo.addHighlight(
                      bookId: state.bookId,
                      chapter: state.chapter,
                      verse: verse.verse,
                      verseText: verse.text,
                      bookName: bookName,
                      color: color,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Highlighted in ${color.name}')),
                    );
                    // Refresh UI
                    ref.read(userDataRefreshProvider.notifier).state++;
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color(color.colorValue),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showNoteEditor(BibleVerse verse, String bookName) {
    final state = ref.read(readerStateProvider);
    final userDataRepo = ref.read(userDataRepositoryProvider);
    final existingNote = userDataRepo.getNote(state.bookId, state.chapter, verse.verse);
    final controller = TextEditingController(text: existingNote?.content ?? '');

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
                  'Note on $bookName ${state.chapter}:${verse.verse}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (existingNote != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await userDataRepo.removeNote(existingNote.id);
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
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Write your note here...',
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
                      bookId: state.bookId,
                      chapter: state.chapter,
                      verse: verse.verse,
                      bookName: bookName,
                      content: content,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Note saved')),
                    );
                  } else {
                    Navigator.pop(ctx);
                  }
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

class _VerseTile extends StatelessWidget {
  final BibleVerse verse;
  final bool isDark;
  final Highlight? highlight;
  final bool isBookmarked;
  final VoidCallback onTap;

  const _VerseTile({
    required this.verse,
    required this.isDark,
    required this.onTap,
    this.highlight,
    this.isBookmarked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: highlight != null
              ? Color(highlight!.color.colorValue).withOpacity(0.5)
              : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${verse.verse} ',
                      style: AppTypography.verseNumberStyle(isDark: isDark),
                    ),
                    TextSpan(
                      text: verse.text,
                      style: AppTypography.scriptureStyle(isDark: isDark),
                    ),
                  ],
                ),
              ),
            ),
            if (isBookmarked)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.bookmark,
                  size: 16,
                  color: AppColors.primaryLight,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TranslationOption extends StatelessWidget {
  final String code;
  final String name;
  final bool isAvailable;
  final VoidCallback? onTap;

  const _TranslationOption(this.code, this.name, this.isAvailable, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: isAvailable
          ? Icon(Icons.check_circle, color: AppColors.primaryLight)
          : const Icon(Icons.lock_outline, color: Colors.grey),
      title: Text(code),
      subtitle: Text(name),
      enabled: isAvailable,
      onTap: onTap,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primaryLight),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
