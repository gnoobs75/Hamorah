import 'dart:convert';
import 'package:http/http.dart' as http;
import 'bible_database.dart';
import 'models/bible_models.dart';

/// Download progress callback
typedef BibleProgressCallback = void Function(int current, int total, String message);

/// Service for downloading Bible translations from public sources
class BibleDownloadService {
  static BibleDownloadService? _instance;

  BibleDownloadService._();

  static BibleDownloadService get instance {
    _instance ??= BibleDownloadService._();
    return _instance!;
  }

  /// Download sources for each translation
  static const Map<String, String> _downloadSources = {
    'KJV': 'https://raw.githubusercontent.com/aruljohn/Bible-kjv/master',
    'ASV': 'https://raw.githubusercontent.com/thiagobodruk/bible/master/json/en_asv.json',
    'WEB': 'https://raw.githubusercontent.com/thiagobodruk/bible/master/json/en_web.json',
  };

  /// Book names in the order they appear in the GitHub KJV repo
  static const List<String> _kjvBookNames = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
    'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
    '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles', 'Ezra',
    'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
    'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah', 'Lamentations',
    'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
    'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
    'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
    'Matthew', 'Mark', 'Luke', 'John', 'Acts',
    'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians', '1 Timothy',
    '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James',
    '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
    'Jude', 'Revelation',
  ];

  /// Download KJV from GitHub (aruljohn/Bible-kjv format)
  /// Each book is a separate JSON file
  Future<void> downloadKJV({BibleProgressCallback? onProgress}) async {
    final db = BibleDatabase.instance;
    int totalVerses = 0;

    onProgress?.call(0, 66, 'Starting KJV download...');

    for (int bookIndex = 0; bookIndex < _kjvBookNames.length; bookIndex++) {
      final bookName = _kjvBookNames[bookIndex];
      final bookId = bookIndex + 1;

      onProgress?.call(bookIndex, 66, 'Downloading $bookName...');

      try {
        // GitHub file names use the book name directly
        final fileName = bookName.replaceAll(' ', '%20');
        final url = '${_downloadSources['KJV']}/$fileName.json';

        final response = await http.get(Uri.parse(url));

        if (response.statusCode != 200) {
          throw Exception('Failed to download $bookName: ${response.statusCode}');
        }

        final data = jsonDecode(response.body);
        final chapters = data['chapters'] as List;

        List<BibleVerse> verses = [];

        for (final chapterData in chapters) {
          final chapterNum = int.parse(chapterData['chapter'].toString());
          final versesList = chapterData['verses'] as List;

          for (final verseData in versesList) {
            final verseNum = int.parse(verseData['verse'].toString());
            final text = verseData['text'] as String;

            verses.add(BibleVerse(
              id: 0, // Will be assigned by database
              bookId: bookId,
              chapter: chapterNum,
              verse: verseNum,
              text: text.trim(),
              bookName: bookName,
            ));
          }
        }

        // Insert in batches
        await db.insertVerses(verses, translationId: 'KJV');
        totalVerses += verses.length;

      } catch (e) {
        throw Exception('Error downloading $bookName: $e');
      }
    }

    // Update translation status
    await db.updateTranslationStatus('KJV', true, totalVerses);
    onProgress?.call(66, 66, 'KJV download complete! $totalVerses verses');
  }

  /// Download ASV or WEB from thiagobodruk/bible format
  /// Single JSON file with all verses
  Future<void> downloadSingleFileTranslation(
    String translationId, {
    BibleProgressCallback? onProgress,
  }) async {
    final url = _downloadSources[translationId];
    if (url == null) {
      throw Exception('Unknown translation: $translationId');
    }

    onProgress?.call(0, 100, 'Downloading $translationId...');

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to download $translationId: ${response.statusCode}');
    }

    onProgress?.call(25, 100, 'Parsing $translationId...');

    final List<dynamic> books = jsonDecode(response.body);
    final db = BibleDatabase.instance;
    int totalVerses = 0;

    for (int bookIndex = 0; bookIndex < books.length; bookIndex++) {
      final bookData = books[bookIndex];
      final bookId = bookIndex + 1;
      final bookName = _kjvBookNames[bookIndex];

      onProgress?.call(25 + (bookIndex * 75 ~/ 66), 100, 'Processing $bookName...');

      final chapters = bookData['chapters'] as List;
      List<BibleVerse> verses = [];

      for (int chapterIndex = 0; chapterIndex < chapters.length; chapterIndex++) {
        final versesList = chapters[chapterIndex] as List;

        for (int verseIndex = 0; verseIndex < versesList.length; verseIndex++) {
          final text = versesList[verseIndex] as String;

          verses.add(BibleVerse(
            id: 0,
            bookId: bookId,
            chapter: chapterIndex + 1,
            verse: verseIndex + 1,
            text: text.trim(),
            bookName: bookName,
          ));
        }
      }

      await db.insertVerses(verses, translationId: translationId);
      totalVerses += verses.length;
    }

    await db.updateTranslationStatus(translationId, true, totalVerses);
    onProgress?.call(100, 100, '$translationId download complete! $totalVerses verses');
  }

  /// Download any supported translation
  Future<void> downloadTranslation(
    String translationId, {
    BibleProgressCallback? onProgress,
  }) async {
    switch (translationId) {
      case 'KJV':
        await downloadKJV(onProgress: onProgress);
        break;
      case 'ASV':
      case 'WEB':
        await downloadSingleFileTranslation(translationId, onProgress: onProgress);
        break;
      default:
        throw Exception('Unsupported translation: $translationId');
    }
  }

  /// Delete a translation
  Future<void> deleteTranslation(String translationId) async {
    await BibleDatabase.instance.clearTranslation(translationId);
  }

  /// Check if a translation is available for download
  bool isTranslationAvailable(String translationId) {
    return _downloadSources.containsKey(translationId);
  }
}
