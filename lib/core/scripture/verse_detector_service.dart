import 'package:flutter/foundation.dart';

import '../../data/bible/models/bible_models.dart';
import '../../data/bible/bible_repository.dart';

/// Represents a detected Scripture reference
class DetectedReference {
  final String reference;    // e.g., "John 3:16"
  final String bookName;     // e.g., "John"
  final int bookId;
  final int chapter;
  final int startVerse;
  final int? endVerse;       // For ranges like "John 3:16-18"
  final int startIndex;      // Position in original text
  final int endIndex;

  const DetectedReference({
    required this.reference,
    required this.bookName,
    required this.bookId,
    required this.chapter,
    required this.startVerse,
    this.endVerse,
    required this.startIndex,
    required this.endIndex,
  });

  bool get isRange => endVerse != null;
}

/// Service for detecting Scripture references in text
class VerseDetectorService {
  static VerseDetectorService? _instance;
  static VerseDetectorService get instance {
    _instance ??= VerseDetectorService._();
    return _instance!;
  }

  VerseDetectorService._();

  // Maps for converting spoken words to numbers
  static const Map<String, String> _ordinalToNumber = {
    'first': '1',
    '1st': '1',
    'second': '2',
    '2nd': '2',
    'third': '3',
    '3rd': '3',
  };

  // Common book name variations for better speech recognition matching
  static const Map<String, String> _bookAliases = {
    'genesis': 'Genesis',
    'gen': 'Genesis',
    'exodus': 'Exodus',
    'ex': 'Exodus',
    'leviticus': 'Leviticus',
    'lev': 'Leviticus',
    'numbers': 'Numbers',
    'num': 'Numbers',
    'deuteronomy': 'Deuteronomy',
    'deut': 'Deuteronomy',
    'joshua': 'Joshua',
    'josh': 'Joshua',
    'judges': 'Judges',
    'judg': 'Judges',
    'ruth': 'Ruth',
    'samuel': 'Samuel',
    'sam': 'Samuel',
    'kings': 'Kings',
    'chronicles': 'Chronicles',
    'chron': 'Chronicles',
    'ezra': 'Ezra',
    'nehemiah': 'Nehemiah',
    'neh': 'Nehemiah',
    'esther': 'Esther',
    'job': 'Job',
    'psalms': 'Psalms',
    'psalm': 'Psalms',
    'ps': 'Psalms',
    'proverbs': 'Proverbs',
    'prov': 'Proverbs',
    'ecclesiastes': 'Ecclesiastes',
    'eccl': 'Ecclesiastes',
    'song of solomon': 'Song of Solomon',
    'song of songs': 'Song of Solomon',
    'isaiah': 'Isaiah',
    'isa': 'Isaiah',
    'jeremiah': 'Jeremiah',
    'jer': 'Jeremiah',
    'lamentations': 'Lamentations',
    'lam': 'Lamentations',
    'ezekiel': 'Ezekiel',
    'ezek': 'Ezekiel',
    'daniel': 'Daniel',
    'dan': 'Daniel',
    'hosea': 'Hosea',
    'hos': 'Hosea',
    'joel': 'Joel',
    'amos': 'Amos',
    'obadiah': 'Obadiah',
    'jonah': 'Jonah',
    'micah': 'Micah',
    'nahum': 'Nahum',
    'habakkuk': 'Habakkuk',
    'hab': 'Habakkuk',
    'zephaniah': 'Zephaniah',
    'zeph': 'Zephaniah',
    'haggai': 'Haggai',
    'hag': 'Haggai',
    'zechariah': 'Zechariah',
    'zech': 'Zechariah',
    'malachi': 'Malachi',
    'mal': 'Malachi',
    'matthew': 'Matthew',
    'matt': 'Matthew',
    'mark': 'Mark',
    'luke': 'Luke',
    'john': 'John',
    'acts': 'Acts',
    'romans': 'Romans',
    'rom': 'Romans',
    'corinthians': 'Corinthians',
    'cor': 'Corinthians',
    'galatians': 'Galatians',
    'gal': 'Galatians',
    'ephesians': 'Ephesians',
    'eph': 'Ephesians',
    'philippians': 'Philippians',
    'phil': 'Philippians',
    'colossians': 'Colossians',
    'col': 'Colossians',
    'thessalonians': 'Thessalonians',
    'thess': 'Thessalonians',
    'timothy': 'Timothy',
    'tim': 'Timothy',
    'titus': 'Titus',
    'philemon': 'Philemon',
    'hebrews': 'Hebrews',
    'heb': 'Hebrews',
    'james': 'James',
    'peter': 'Peter',
    'pet': 'Peter',
    'jude': 'Jude',
    'revelation': 'Revelation',
    'rev': 'Revelation',
    'revelations': 'Revelation',
  };

  /// Detect all Scripture references in the given text
  List<DetectedReference> detectReferences(String text) {
    final references = <DetectedReference>[];

    // Pattern 1: Standard format "Book Chapter:Verse" or "1 Book Chapter:Verse"
    // Examples: "John 3:16", "1 Corinthians 13:4", "1 John 4:8"
    final standardPattern = RegExp(
      r'(\d?\s?[A-Za-z]+(?:\s+of\s+[A-Za-z]+)?)\s+(\d+):(\d+)(?:-(\d+))?',
      caseSensitive: false,
    );

    for (final match in standardPattern.allMatches(text)) {
      final bookPart = match.group(1)!.trim();
      final chapter = int.tryParse(match.group(2)!);
      final startVerse = int.tryParse(match.group(3)!);
      final endVerse = match.group(4) != null ? int.tryParse(match.group(4)!) : null;

      if (chapter == null || startVerse == null) continue;

      final book = _resolveBookName(bookPart);
      if (book == null) continue;

      // Build the canonical reference
      String reference = '${book.name} $chapter:$startVerse';
      if (endVerse != null) {
        reference += '-$endVerse';
      }

      references.add(DetectedReference(
        reference: reference,
        bookName: book.name,
        bookId: book.id,
        chapter: chapter,
        startVerse: startVerse,
        endVerse: endVerse,
        startIndex: match.start,
        endIndex: match.end,
      ));
    }

    // Pattern 2: Spoken format "Book chapter X verse Y"
    // Examples: "John chapter 3 verse 16", "First Corinthians chapter 13 verse 4"
    final spokenPattern = RegExp(
      r'(\w+(?:\s+\w+)?)\s+chapter\s+(\d+)\s+verse\s+(\d+)(?:\s+(?:through|to|-)\s*(\d+))?',
      caseSensitive: false,
    );

    for (final match in spokenPattern.allMatches(text)) {
      final bookPart = match.group(1)!.trim();
      final chapter = int.tryParse(match.group(2)!);
      final startVerse = int.tryParse(match.group(3)!);
      final endVerse = match.group(4) != null ? int.tryParse(match.group(4)!) : null;

      if (chapter == null || startVerse == null) continue;

      // Handle ordinal prefixes (First, Second, Third)
      final processedBook = _processOrdinalPrefix(bookPart);
      final book = _resolveBookName(processedBook);
      if (book == null) continue;

      // Build the canonical reference
      String reference = '${book.name} $chapter:$startVerse';
      if (endVerse != null) {
        reference += '-$endVerse';
      }

      // Avoid duplicates
      if (!references.any((r) => r.reference == reference)) {
        references.add(DetectedReference(
          reference: reference,
          bookName: book.name,
          bookId: book.id,
          chapter: chapter,
          startVerse: startVerse,
          endVerse: endVerse,
          startIndex: match.start,
          endIndex: match.end,
        ));
      }
    }

    // Sort by position in text
    references.sort((a, b) => a.startIndex.compareTo(b.startIndex));

    return references;
  }

  /// Convert ordinal words to numbers (e.g., "First Corinthians" -> "1 Corinthians")
  String _processOrdinalPrefix(String input) {
    for (final entry in _ordinalToNumber.entries) {
      if (input.toLowerCase().startsWith(entry.key)) {
        return '${entry.value} ${input.substring(entry.key.length).trim()}';
      }
    }
    return input;
  }

  /// Resolve a book name string to a BibleBook
  BibleBook? _resolveBookName(String input) {
    final lower = input.toLowerCase().trim();

    // Try direct lookup first
    var book = BibleBooks.getByName(input);
    if (book != null) return book;

    // Try aliases
    final alias = _bookAliases[lower];
    if (alias != null) {
      book = BibleBooks.getByName(alias);
      if (book != null) return book;
    }

    // Handle numbered books like "1 Corinthians"
    final numberedMatch = RegExp(r'^(\d)\s*(.+)$').firstMatch(lower);
    if (numberedMatch != null) {
      final num = numberedMatch.group(1)!;
      final name = numberedMatch.group(2)!;
      final normalizedName = _bookAliases[name] ?? name;

      // Try "$num $normalizedName"
      book = BibleBooks.getByName('$num $normalizedName');
      if (book != null) return book;

      // Try with title case
      final titleName = normalizedName[0].toUpperCase() + normalizedName.substring(1);
      book = BibleBooks.getByName('$num $titleName');
      if (book != null) return book;
    }

    return null;
  }

  /// Get verse text from the Bible repository
  Future<String?> getVerseText(
    BibleRepository repository,
    DetectedReference reference,
  ) async {
    try {
      if (reference.isRange) {
        final verses = await repository.getVerseRange(
          reference.bookId,
          reference.chapter,
          reference.startVerse,
          reference.endVerse!,
        );
        if (verses.isEmpty) return null;
        return verses.map((v) => v.text).join(' ');
      } else {
        final verse = await repository.getVerse(
          reference.bookId,
          reference.chapter,
          reference.startVerse,
        );
        return verse?.text;
      }
    } catch (e) {
      debugPrint('Error getting verse text: $e');
      return null;
    }
  }

  /// Detect references and fetch their full text
  Future<List<({DetectedReference reference, String verseText})>> detectAndFetchVerses(
    String text,
    BibleRepository repository,
  ) async {
    final references = detectReferences(text);
    final results = <({DetectedReference reference, String verseText})>[];

    for (final ref in references) {
      final verseText = await getVerseText(repository, ref);
      if (verseText != null) {
        results.add((reference: ref, verseText: verseText));
      }
    }

    return results;
  }

  /// Extract context around a reference from the source text
  String extractContext(String sourceText, DetectedReference reference, {int contextWords = 10}) {
    final words = sourceText.split(RegExp(r'\s+'));

    // Find the reference position in words
    int refStartWord = 0;
    int currentPos = 0;
    for (int i = 0; i < words.length; i++) {
      if (currentPos >= reference.startIndex) {
        refStartWord = i;
        break;
      }
      currentPos += words[i].length + 1; // +1 for space
    }

    // Get context words before and after
    final startWord = (refStartWord - contextWords).clamp(0, words.length);
    final endWord = (refStartWord + contextWords + 1).clamp(0, words.length);

    final contextWords_ = words.sublist(startWord, endWord);
    return contextWords_.join(' ');
  }
}
