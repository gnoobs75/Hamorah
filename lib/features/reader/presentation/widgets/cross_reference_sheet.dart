import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/bible/cross_reference_service.dart';
import '../../../../data/bible/models/bible_models.dart';

/// Bottom sheet displaying cross-references for a verse
class CrossReferenceSheet extends ConsumerWidget {
  final int bookId;
  final int chapter;
  final int verse;
  final String reference;
  final void Function(int bookId, int chapter, int verse)? onNavigate;

  const CrossReferenceSheet({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.reference,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crossRefsAsync = ref.watch(crossReferencesProvider((
      bookId: bookId,
      chapter: chapter,
      verse: verse,
    )));

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.link,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cross References',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            reference,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content
              Expanded(
                child: crossRefsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error loading cross-references: $error'),
                    ),
                  ),
                  data: (crossRefs) {
                    if (crossRefs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.link_off,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No cross-references found',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Cross-references for this verse are not yet available.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: crossRefs.length,
                      itemBuilder: (context, index) {
                        final crossRef = crossRefs[index];
                        return _CrossReferenceCard(
                          crossRef: crossRef,
                          onTap: () {
                            Navigator.pop(context);
                            onNavigate?.call(
                              crossRef.reference.toBookId,
                              crossRef.reference.toChapter,
                              crossRef.reference.toVerse,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CrossReferenceCard extends StatelessWidget {
  final ResolvedCrossReference crossRef;
  final VoidCallback? onTap;

  const _CrossReferenceCard({
    required this.crossRef,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
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
                      crossRef.targetReference,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRelationshipColor(crossRef.reference.relationshipType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      crossRef.reference.relationshipDisplay,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _getRelationshipColor(crossRef.reference.relationshipType),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (crossRef.verseText != null) ...[
                const SizedBox(height: 12),
                Text(
                  crossRef.verseText!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Tap to read',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRelationshipColor(String? type) {
    switch (type) {
      case 'quote':
        return Colors.purple;
      case 'parallel':
        return Colors.blue;
      case 'allusion':
        return Colors.orange;
      case 'theme':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

/// Helper function to show the cross-reference sheet
void showCrossReferenceSheet(
  BuildContext context, {
  required int bookId,
  required int chapter,
  required int verse,
  required String reference,
  void Function(int bookId, int chapter, int verse)? onNavigate,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CrossReferenceSheet(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      reference: reference,
      onNavigate: onNavigate,
    ),
  );
}
