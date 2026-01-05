import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bible_repository.dart';
import 'models/bible_models.dart';

/// Represents a cross-reference between verses
class CrossReference {
  final int fromBookId;
  final int fromChapter;
  final int fromVerse;
  final int toBookId;
  final int toChapter;
  final int toVerse;
  final int? toVerseEnd; // For ranges
  final String? relationshipType; // 'quote', 'parallel', 'allusion', 'theme'

  const CrossReference({
    required this.fromBookId,
    required this.fromChapter,
    required this.fromVerse,
    required this.toBookId,
    required this.toChapter,
    required this.toVerse,
    this.toVerseEnd,
    this.relationshipType,
  });

  /// Get the target reference as a string
  String getTargetReference() {
    final bookName = BibleBooks.getById(toBookId)?.name ?? 'Unknown';
    if (toVerseEnd != null && toVerseEnd != toVerse) {
      return '$bookName $toChapter:$toVerse-$toVerseEnd';
    }
    return '$bookName $toChapter:$toVerse';
  }

  /// Get relationship type display name
  String get relationshipDisplay {
    switch (relationshipType) {
      case 'quote':
        return 'Quotation';
      case 'parallel':
        return 'Parallel Passage';
      case 'allusion':
        return 'Allusion';
      case 'theme':
        return 'Thematic';
      default:
        return 'Related';
    }
  }
}

/// Resolved cross-reference with verse text
class ResolvedCrossReference {
  final CrossReference reference;
  final String targetReference;
  final String? verseText;
  final String bookName;

  const ResolvedCrossReference({
    required this.reference,
    required this.targetReference,
    this.verseText,
    required this.bookName,
  });
}

/// Service for managing cross-references
/// This uses a curated list of common cross-references
/// In a full implementation, this would query a database with TSK data
class CrossReferenceService {
  static CrossReferenceService? _instance;
  static CrossReferenceService get instance {
    _instance ??= CrossReferenceService._();
    return _instance!;
  }

  CrossReferenceService._();

  // Curated cross-references for common verses
  // In production, this would be loaded from a database
  static final Map<String, List<CrossReference>> _crossReferences = {
    // John 3:16
    '43-3-16': [
      CrossReference(fromBookId: 43, fromChapter: 3, fromVerse: 16, toBookId: 45, toChapter: 5, toVerse: 8, relationshipType: 'theme'),
      CrossReference(fromBookId: 43, fromChapter: 3, fromVerse: 16, toBookId: 62, toChapter: 4, toVerse: 9, relationshipType: 'parallel'),
      CrossReference(fromBookId: 43, fromChapter: 3, fromVerse: 16, toBookId: 45, toChapter: 8, toVerse: 32, relationshipType: 'theme'),
      CrossReference(fromBookId: 43, fromChapter: 3, fromVerse: 16, toBookId: 49, toChapter: 2, toVerse: 4, toVerseEnd: 5, relationshipType: 'theme'),
    ],
    // Romans 8:28
    '45-8-28': [
      CrossReference(fromBookId: 45, fromChapter: 8, fromVerse: 28, toBookId: 1, toChapter: 50, toVerse: 20, relationshipType: 'parallel'),
      CrossReference(fromBookId: 45, fromChapter: 8, fromVerse: 28, toBookId: 49, toChapter: 1, toVerse: 11, relationshipType: 'theme'),
      CrossReference(fromBookId: 45, fromChapter: 8, fromVerse: 28, toBookId: 24, toChapter: 29, toVerse: 11, relationshipType: 'theme'),
    ],
    // Philippians 4:13
    '50-4-13': [
      CrossReference(fromBookId: 50, fromChapter: 4, fromVerse: 13, toBookId: 47, toChapter: 12, toVerse: 9, relationshipType: 'parallel'),
      CrossReference(fromBookId: 50, fromChapter: 4, fromVerse: 13, toBookId: 23, toChapter: 40, toVerse: 31, relationshipType: 'theme'),
      CrossReference(fromBookId: 50, fromChapter: 4, fromVerse: 13, toBookId: 49, toChapter: 6, toVerse: 10, relationshipType: 'theme'),
    ],
    // Jeremiah 29:11
    '24-29-11': [
      CrossReference(fromBookId: 24, fromChapter: 29, fromVerse: 11, toBookId: 45, toChapter: 8, toVerse: 28, relationshipType: 'theme'),
      CrossReference(fromBookId: 24, fromChapter: 29, fromVerse: 11, toBookId: 20, toChapter: 3, toVerse: 5, toVerseEnd: 6, relationshipType: 'theme'),
    ],
    // Psalm 23:1
    '19-23-1': [
      CrossReference(fromBookId: 19, fromChapter: 23, fromVerse: 1, toBookId: 43, toChapter: 10, toVerse: 11, relationshipType: 'quote'),
      CrossReference(fromBookId: 19, fromChapter: 23, fromVerse: 1, toBookId: 26, toChapter: 34, toVerse: 11, toVerseEnd: 16, relationshipType: 'parallel'),
      CrossReference(fromBookId: 19, fromChapter: 23, fromVerse: 1, toBookId: 58, toChapter: 13, toVerse: 20, relationshipType: 'theme'),
    ],
    // Proverbs 3:5-6
    '20-3-5': [
      CrossReference(fromBookId: 20, fromChapter: 3, fromVerse: 5, toBookId: 24, toChapter: 17, toVerse: 7, relationshipType: 'theme'),
      CrossReference(fromBookId: 20, fromChapter: 3, fromVerse: 5, toBookId: 19, toChapter: 37, toVerse: 5, relationshipType: 'parallel'),
      CrossReference(fromBookId: 20, fromChapter: 3, fromVerse: 5, toBookId: 23, toChapter: 26, toVerse: 3, toVerseEnd: 4, relationshipType: 'theme'),
    ],
    // Isaiah 40:31
    '23-40-31': [
      CrossReference(fromBookId: 23, fromChapter: 40, fromVerse: 31, toBookId: 19, toChapter: 103, toVerse: 5, relationshipType: 'theme'),
      CrossReference(fromBookId: 23, fromChapter: 40, fromVerse: 31, toBookId: 50, toChapter: 4, toVerse: 13, relationshipType: 'theme'),
      CrossReference(fromBookId: 23, fromChapter: 40, fromVerse: 31, toBookId: 47, toChapter: 12, toVerse: 9, relationshipType: 'parallel'),
    ],
    // Matthew 28:19-20
    '40-28-19': [
      CrossReference(fromBookId: 40, fromChapter: 28, fromVerse: 19, toBookId: 41, toChapter: 16, toVerse: 15, relationshipType: 'parallel'),
      CrossReference(fromBookId: 40, fromChapter: 28, fromVerse: 19, toBookId: 44, toChapter: 1, toVerse: 8, relationshipType: 'parallel'),
      CrossReference(fromBookId: 40, fromChapter: 28, fromVerse: 19, toBookId: 42, toChapter: 24, toVerse: 47, relationshipType: 'parallel'),
    ],
    // Romans 3:23
    '45-3-23': [
      CrossReference(fromBookId: 45, fromChapter: 3, fromVerse: 23, toBookId: 1, toChapter: 3, toVerse: 6, relationshipType: 'theme'),
      CrossReference(fromBookId: 45, fromChapter: 3, fromVerse: 23, toBookId: 21, toChapter: 7, toVerse: 20, relationshipType: 'parallel'),
      CrossReference(fromBookId: 45, fromChapter: 3, fromVerse: 23, toBookId: 48, toChapter: 3, toVerse: 22, relationshipType: 'parallel'),
      CrossReference(fromBookId: 45, fromChapter: 3, fromVerse: 23, toBookId: 62, toChapter: 1, toVerse: 8, toVerseEnd: 10, relationshipType: 'theme'),
    ],
    // Ephesians 2:8-9
    '49-2-8': [
      CrossReference(fromBookId: 49, fromChapter: 2, fromVerse: 8, toBookId: 45, toChapter: 3, toVerse: 24, relationshipType: 'parallel'),
      CrossReference(fromBookId: 49, fromChapter: 2, fromVerse: 8, toBookId: 56, toChapter: 3, toVerse: 5, relationshipType: 'parallel'),
      CrossReference(fromBookId: 49, fromChapter: 2, fromVerse: 8, toBookId: 48, toChapter: 2, toVerse: 16, relationshipType: 'parallel'),
    ],
    // Genesis 1:1
    '1-1-1': [
      CrossReference(fromBookId: 1, fromChapter: 1, fromVerse: 1, toBookId: 43, toChapter: 1, toVerse: 1, toVerseEnd: 3, relationshipType: 'parallel'),
      CrossReference(fromBookId: 1, fromChapter: 1, fromVerse: 1, toBookId: 58, toChapter: 11, toVerse: 3, relationshipType: 'quote'),
      CrossReference(fromBookId: 1, fromChapter: 1, fromVerse: 1, toBookId: 51, toChapter: 1, toVerse: 16, toVerseEnd: 17, relationshipType: 'theme'),
      CrossReference(fromBookId: 1, fromChapter: 1, fromVerse: 1, toBookId: 19, toChapter: 33, toVerse: 6, relationshipType: 'parallel'),
    ],
  };

  /// Get cross-references for a specific verse
  List<CrossReference> getCrossReferences(int bookId, int chapter, int verse) {
    final key = '$bookId-$chapter-$verse';
    return _crossReferences[key] ?? [];
  }

  /// Get resolved cross-references with verse text
  Future<List<ResolvedCrossReference>> getResolvedCrossReferences(
    int bookId,
    int chapter,
    int verse,
    BibleRepository bibleRepo,
  ) async {
    final refs = getCrossReferences(bookId, chapter, verse);
    final resolved = <ResolvedCrossReference>[];

    for (final ref in refs) {
      String? verseText;
      try {
        if (ref.toVerseEnd != null) {
          final verses = await bibleRepo.getVerseRange(
            ref.toBookId,
            ref.toChapter,
            ref.toVerse,
            ref.toVerseEnd!,
          );
          verseText = verses.map((v) => v.text).join(' ');
        } else {
          final verse = await bibleRepo.getVerse(
            ref.toBookId,
            ref.toChapter,
            ref.toVerse,
          );
          verseText = verse?.text;
        }
      } catch (e) {
        debugPrint('Error fetching cross-reference verse: $e');
      }

      final book = BibleBooks.getById(ref.toBookId);
      resolved.add(ResolvedCrossReference(
        reference: ref,
        targetReference: ref.getTargetReference(),
        verseText: verseText,
        bookName: book?.name ?? 'Unknown',
      ));
    }

    return resolved;
  }

  /// Check if a verse has cross-references
  bool hasCrossReferences(int bookId, int chapter, int verse) {
    final key = '$bookId-$chapter-$verse';
    return _crossReferences.containsKey(key) && _crossReferences[key]!.isNotEmpty;
  }
}

/// Provider for cross-reference service
final crossReferenceServiceProvider = Provider<CrossReferenceService>((ref) {
  return CrossReferenceService.instance;
});

/// Provider for resolved cross-references
final crossReferencesProvider = FutureProvider.family<List<ResolvedCrossReference>, ({int bookId, int chapter, int verse})>((ref, params) async {
  final service = ref.watch(crossReferenceServiceProvider);
  final bibleRepo = ref.watch(bibleRepositoryProvider);
  return service.getResolvedCrossReferences(
    params.bookId,
    params.chapter,
    params.verse,
    bibleRepo,
  );
});
