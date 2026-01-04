import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/bible/bible_repository.dart';
import '../../../../data/bible/models/bible_models.dart';

/// Provider for search query
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for search mode (semantic vs keyword)
final isSemanticSearchProvider = StateProvider<bool>((ref) => false);

/// Provider for search results
final searchResultsProvider = FutureProvider<List<VerseSearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];

  final repository = ref.watch(bibleRepositoryProvider);
  return repository.search(query, limit: 50);
});

/// Search screen - keyword and semantic search
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(searchQueryProvider.notifier).state = query;
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSemanticSearch = ref.watch(isSemanticSearchProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Scripture'),
      ),
      body: Column(
        children: [
          // Search input
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: isSemanticSearch
                        ? 'Search by meaning (coming soon)'
                        : 'Search by keyword (e.g., "love", "faith")',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                ),
                const SizedBox(height: 12),

                // Search mode toggle
                Row(
                  children: [
                    _SearchModeChip(
                      label: 'Keyword',
                      icon: Icons.text_fields,
                      isSelected: !isSemanticSearch,
                      onTap: () => ref.read(isSemanticSearchProvider.notifier).state = false,
                    ),
                    const SizedBox(width: 8),
                    _SearchModeChip(
                      label: 'By Meaning',
                      icon: Icons.psychology_outlined,
                      isSelected: isSemanticSearch,
                      onTap: () {
                        ref.read(isSemanticSearchProvider.notifier).state = true;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Semantic search coming soon with AI integration'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Results
          Expanded(
            child: resultsAsync.when(
              data: (results) {
                if (query.isEmpty) {
                  return _EmptyState(hasQuery: false);
                }
                if (results.isEmpty) {
                  return _EmptyState(hasQuery: true);
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    return _SearchResultCard(
                      result: results[index],
                      isDark: isDark,
                      searchQuery: query,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text('Search failed: $error'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SearchModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryLight.withOpacity(0.2),
      checkmarkColor: AppColors.primaryLight,
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final VerseSearchResult result;
  final bool isDark;
  final String searchQuery;

  const _SearchResultCard({
    required this.result,
    required this.isDark,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to verse in reader
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Navigate to ${result.reference}')),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    result.reference,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'KJV',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _HighlightedText(
                text: result.verse.text,
                highlight: searchQuery,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text widget that highlights the search query
class _HighlightedText extends StatelessWidget {
  final String text;
  final String highlight;
  final bool isDark;

  const _HighlightedText({
    required this.text,
    required this.highlight,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (highlight.isEmpty) {
      return Text(
        text,
        style: AppTypography.scriptureStyle(isDark: isDark, fontSize: 15),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerHighlight = highlight.toLowerCase();
    final spans = <TextSpan>[];

    int start = 0;
    int index = lowerText.indexOf(lowerHighlight);

    while (index != -1) {
      // Add text before match
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: AppTypography.scriptureStyle(isDark: isDark, fontSize: 15),
        ));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + highlight.length),
        style: AppTypography.scriptureStyle(isDark: isDark, fontSize: 15).copyWith(
          backgroundColor: AppColors.highlightYellow,
          fontWeight: FontWeight.w600,
        ),
      ));

      start = index + highlight.length;
      index = lowerText.indexOf(lowerHighlight, start);
    }

    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: AppTypography.scriptureStyle(isDark: isDark, fontSize: 15),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;

  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasQuery ? Icons.search_off : Icons.search,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery ? 'No results found' : 'Search for Scripture',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            hasQuery
                ? 'Try different words'
                : 'Find verses by keyword',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }
}
