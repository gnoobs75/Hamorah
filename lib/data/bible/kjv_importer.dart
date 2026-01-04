import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'bible_database.dart';
import 'models/bible_models.dart';

/// Import progress callback
typedef ProgressCallback = void Function(double progress, String message);

/// Service to import KJV Bible data
class KjvImporter {
  final BibleDatabase _database;

  // Reliable KJV JSON source (getbible.net public API)
  static const String _kjvApiUrl =
    'https://getbible.net/v2/kjv.json';

  KjvImporter(this._database);

  /// Import KJV Bible from online source
  Future<bool> importFromNetwork({ProgressCallback? onProgress}) async {
    try {
      onProgress?.call(0.0, 'Downloading KJV Bible...');

      final jsonData = await _fetchJson(_kjvApiUrl);

      if (jsonData == null) {
        debugPrint('Failed to download Bible data');
        onProgress?.call(0.0, 'Download failed. Using sample data...');
        return false;
      }

      onProgress?.call(0.2, 'Parsing Bible data...');

      // Parse JSON
      final data = json.decode(jsonData);

      List<BibleVerse> verses = [];

      // getbible.net format: {"books": [{"name": "Genesis", "chapters": [{"chapter": 1, "verses": [{"verse": 1, "text": "..."}]}]}]}
      if (data is Map && data.containsKey('books')) {
        verses = _parseGetBibleFormat(data);
      } else {
        debugPrint('Unknown format, trying alternative parsing...');
        // Try parsing as simple list
        if (data is List) {
          verses = _parseSimpleList(data);
        }
      }

      if (verses.isEmpty) {
        debugPrint('No verses parsed from data');
        onProgress?.call(0.0, 'Failed to parse Bible data');
        return false;
      }

      onProgress?.call(0.5, 'Importing ${verses.length} verses...');

      // Clear existing data
      await _database.clearAll();

      // Insert in batches
      const batchSize = 500;
      for (var i = 0; i < verses.length; i += batchSize) {
        final end = (i + batchSize < verses.length) ? i + batchSize : verses.length;
        final batch = verses.sublist(i, end);
        await _database.insertVerses(batch);

        final progress = 0.5 + (0.5 * (end / verses.length));
        onProgress?.call(progress, 'Importing... ${end}/${verses.length}');
      }

      final finalCount = await _database.getVerseCount();
      onProgress?.call(1.0, 'Complete! $finalCount verses loaded.');
      debugPrint('KJV Import complete: $finalCount verses');
      return finalCount > 0;
    } catch (e, stack) {
      debugPrint('KJV Import error: $e');
      debugPrint('Stack: $stack');
      onProgress?.call(0.0, 'Import failed: ${e.toString().substring(0, 100)}');
      return false;
    }
  }

  Future<String?> _fetchJson(String url) async {
    try {
      debugPrint('Fetching Bible from: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 120));

      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('Downloaded ${response.body.length} bytes');
        return response.body;
      }
    } catch (e) {
      debugPrint('Failed to fetch $url: $e');
    }
    return null;
  }

  /// Parse getBible.net format
  List<BibleVerse> _parseGetBibleFormat(Map<dynamic, dynamic> data) {
    final verses = <BibleVerse>[];
    int id = 1;

    final books = data['books'] as List?;
    if (books == null) return verses;

    for (final bookData in books) {
      if (bookData is! Map) continue;

      final bookName = bookData['name'] as String?;
      if (bookName == null) continue;

      final book = BibleBooks.getByName(bookName);
      if (book == null) {
        debugPrint('Unknown book: $bookName');
        continue;
      }

      final chapters = bookData['chapters'] as List?;
      if (chapters == null) continue;

      for (final chapterData in chapters) {
        if (chapterData is! Map) continue;

        final chapterNum = chapterData['chapter'] as int?;
        if (chapterNum == null) continue;

        final versesData = chapterData['verses'] as List?;
        if (versesData == null) continue;

        for (final verseData in versesData) {
          if (verseData is! Map) continue;

          final verseNum = verseData['verse'] as int?;
          final text = verseData['text'] as String?;

          if (verseNum != null && text != null && text.isNotEmpty) {
            verses.add(BibleVerse(
              id: id++,
              bookId: book.id,
              chapter: chapterNum,
              verse: verseNum,
              text: text.trim(),
              bookName: book.name,
            ));
          }
        }
      }
    }

    debugPrint('Parsed ${verses.length} verses from getBible format');
    return verses;
  }

  /// Parse simple list format
  List<BibleVerse> _parseSimpleList(List<dynamic> data) {
    final verses = <BibleVerse>[];
    int id = 1;

    for (final item in data) {
      if (item is! Map) continue;

      final bookName = item['book'] as String? ?? item['book_name'] as String?;
      if (bookName == null) continue;

      final book = BibleBooks.getByName(bookName);
      if (book == null) continue;

      final chapter = item['chapter'] as int?;
      final verse = item['verse'] as int?;
      final text = item['text'] as String?;

      if (chapter != null && verse != null && text != null && text.isNotEmpty) {
        verses.add(BibleVerse(
          id: id++,
          bookId: book.id,
          chapter: chapter,
          verse: verse,
          text: text.trim(),
          bookName: book.name,
        ));
      }
    }

    debugPrint('Parsed ${verses.length} verses from simple list format');
    return verses;
  }
}

/// Hardcoded KJV data for sample/offline use
class KjvSampleData {
  static Future<void> loadIntoDatabase(BibleDatabase database) async {
    await database.clearAll();

    // Load multiple chapters for testing
    final allVerses = <BibleVerse>[];
    allVerses.addAll(_getGenesis1());
    allVerses.addAll(_getPsalm23());
    allVerses.addAll(_getJohn3());
    allVerses.addAll(_getJohn1());

    await database.insertVerses(allVerses);
    debugPrint('Loaded ${allVerses.length} sample verses');
  }

  static List<BibleVerse> _getGenesis1() {
    const bookId = 1;
    const chapter = 1;
    const texts = [
      "In the beginning God created the heaven and the earth.",
      "And the earth was without form, and void; and darkness was upon the face of the deep. And the Spirit of God moved upon the face of the waters.",
      "And God said, Let there be light: and there was light.",
      "And God saw the light, that it was good: and God divided the light from the darkness.",
      "And God called the light Day, and the darkness he called Night. And the evening and the morning were the first day.",
    ];
    return _createVerses(bookId, chapter, texts, 'Genesis');
  }

  static List<BibleVerse> _getPsalm23() {
    const bookId = 19;
    const chapter = 23;
    const texts = [
      "The LORD is my shepherd; I shall not want.",
      "He maketh me to lie down in green pastures: he leadeth me beside the still waters.",
      "He restoreth my soul: he leadeth me in the paths of righteousness for his name's sake.",
      "Yea, though I walk through the valley of the shadow of death, I will fear no evil: for thou art with me; thy rod and thy staff they comfort me.",
      "Thou preparest a table before me in the presence of mine enemies: thou anointest my head with oil; my cup runneth over.",
      "Surely goodness and mercy shall follow me all the days of my life: and I will dwell in the house of the LORD for ever.",
    ];
    return _createVerses(bookId, chapter, texts, 'Psalms');
  }

  static List<BibleVerse> _getJohn1() {
    const bookId = 43;
    const chapter = 1;
    const texts = [
      "In the beginning was the Word, and the Word was with God, and the Word was God.",
      "The same was in the beginning with God.",
      "All things were made by him; and without him was not any thing made that was made.",
      "In him was life; and the life was the light of men.",
      "And the light shineth in darkness; and the darkness comprehended it not.",
    ];
    return _createVerses(bookId, chapter, texts, 'John');
  }

  static List<BibleVerse> _getJohn3() {
    const bookId = 43;
    const chapter = 3;
    const texts = [
      "There was a man of the Pharisees, named Nicodemus, a ruler of the Jews:",
      "The same came to Jesus by night, and said unto him, Rabbi, we know that thou art a teacher come from God: for no man can do these miracles that thou doest, except God be with him.",
      "Jesus answered and said unto him, Verily, verily, I say unto thee, Except a man be born again, he cannot see the kingdom of God.",
      "Nicodemus saith unto him, How can a man be born when he is old? can he enter the second time into his mother's womb, and be born?",
      "Jesus answered, Verily, verily, I say unto thee, Except a man be born of water and of the Spirit, he cannot enter into the kingdom of God.",
      "That which is born of the flesh is flesh; and that which is born of the Spirit is spirit.",
      "Marvel not that I said unto thee, Ye must be born again.",
      "The wind bloweth where it listeth, and thou hearest the sound thereof, but canst not tell whence it cometh, and whither it goeth: so is every one that is born of the Spirit.",
      "Nicodemus answered and said unto him, How can these things be?",
      "Jesus answered and said unto him, Art thou a master of Israel, and knowest not these things?",
      "Verily, verily, I say unto thee, We speak that we do know, and testify that we have seen; and ye receive not our witness.",
      "If I have told you earthly things, and ye believe not, how shall ye believe, if I tell you of heavenly things?",
      "And no man hath ascended up to heaven, but he that came down from heaven, even the Son of man which is in heaven.",
      "And as Moses lifted up the serpent in the wilderness, even so must the Son of man be lifted up:",
      "That whosoever believeth in him should not perish, but have eternal life.",
      "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
      "For God sent not his Son into the world to condemn the world; but that the world through him might be saved.",
    ];
    return _createVerses(bookId, chapter, texts, 'John');
  }

  static List<BibleVerse> _createVerses(int bookId, int chapter, List<String> texts, String bookName) {
    return List.generate(texts.length, (index) => BibleVerse(
      id: 0, // Will be auto-assigned
      bookId: bookId,
      chapter: chapter,
      verse: index + 1,
      text: texts[index],
      bookName: bookName,
    ));
  }
}
