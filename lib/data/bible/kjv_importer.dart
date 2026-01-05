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

  // GitHub raw files base URL (aruljohn/Bible-kjv repo)
  static const String _baseUrl =
    'https://raw.githubusercontent.com/aruljohn/Bible-kjv/master';

  // All 66 books in order (file names match GitHub repo naming convention)
  static const List<String> _bookFiles = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
    'Joshua', 'Judges', 'Ruth', '1Samuel', '2Samuel',
    '1Kings', '2Kings', '1Chronicles', '2Chronicles', 'Ezra',
    'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
    'Ecclesiastes', 'SongofSolomon', 'Isaiah', 'Jeremiah', 'Lamentations',
    'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
    'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
    'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
    'Matthew', 'Mark', 'Luke', 'John', 'Acts',
    'Romans', '1Corinthians', '2Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1Thessalonians', '2Thessalonians', '1Timothy',
    '2Timothy', 'Titus', 'Philemon', 'Hebrews', 'James',
    '1Peter', '2Peter', '1John', '2John', '3John',
    'Jude', 'Revelation',
  ];

  KjvImporter(this._database);

  /// Import KJV Bible from GitHub
  Future<bool> importFromNetwork({ProgressCallback? onProgress}) async {
    try {
      onProgress?.call(0.0, 'Starting KJV download...');

      List<BibleVerse> allVerses = [];
      int verseId = 1;

      // Download each book
      for (int i = 0; i < _bookFiles.length; i++) {
        final bookName = _bookFiles[i];
        final progress = i / _bookFiles.length;
        onProgress?.call(progress * 0.8, 'Downloading $bookName...');

        final url = '$_baseUrl/${Uri.encodeComponent(bookName)}.json';
        final jsonData = await _fetchJson(url);

        if (jsonData == null) {
          debugPrint('Failed to download $bookName');
          continue;
        }

        try {
          final data = json.decode(jsonData);
          final bookVerses = _parseBookJson(data, verseId);
          allVerses.addAll(bookVerses);
          verseId += bookVerses.length;
          debugPrint('Parsed $bookName: ${bookVerses.length} verses');
        } catch (e) {
          debugPrint('Error parsing $bookName: $e');
        }
      }

      if (allVerses.isEmpty) {
        onProgress?.call(0.0, 'No verses downloaded');
        return false;
      }

      onProgress?.call(0.8, 'Saving ${allVerses.length} verses...');

      // Clear existing data
      await _database.clearAll();

      // Insert in batches
      const batchSize = 500;
      for (var i = 0; i < allVerses.length; i += batchSize) {
        final end = (i + batchSize < allVerses.length) ? i + batchSize : allVerses.length;
        final batch = allVerses.sublist(i, end);
        await _database.insertVerses(batch);

        final progress = 0.8 + (0.2 * (end / allVerses.length));
        onProgress?.call(progress, 'Saving... ${end}/${allVerses.length}');
      }

      final finalCount = await _database.getVerseCount();
      onProgress?.call(1.0, 'Complete! $finalCount verses loaded.');
      debugPrint('KJV Import complete: $finalCount verses');
      return finalCount > 0;
    } catch (e, stack) {
      debugPrint('KJV Import error: $e');
      debugPrint('Stack: $stack');
      onProgress?.call(0.0, 'Import failed: $e');
      return false;
    }
  }

  Future<String?> _fetchJson(String url) async {
    try {
      debugPrint('Fetching: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Hamorah-Bible-App',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.body;
      }
      debugPrint('HTTP ${response.statusCode} for $url');
    } catch (e) {
      debugPrint('Failed to fetch $url: $e');
    }
    return null;
  }

  /// Parse aruljohn/Bible-kjv format
  /// {"book": "Matthew", "chapters": [{"chapter": "1", "verses": [{"verse": "1", "text": "..."}]}]}
  List<BibleVerse> _parseBookJson(Map<dynamic, dynamic> data, int startId) {
    final verses = <BibleVerse>[];
    int id = startId;

    final bookName = data['book'] as String?;
    if (bookName == null) return verses;

    final book = BibleBooks.getByName(bookName);
    if (book == null) {
      debugPrint('Unknown book: $bookName');
      return verses;
    }

    final chapters = data['chapters'] as List?;
    if (chapters == null) return verses;

    for (final chapterData in chapters) {
      if (chapterData is! Map) continue;

      final chapterNum = int.tryParse(chapterData['chapter']?.toString() ?? '') ?? 0;
      if (chapterNum == 0) continue;

      final verseList = chapterData['verses'] as List?;
      if (verseList == null) continue;

      for (final verseData in verseList) {
        if (verseData is! Map) continue;

        final verseNum = int.tryParse(verseData['verse']?.toString() ?? '') ?? 0;
        final text = verseData['text'] as String?;

        if (verseNum > 0 && text != null && text.isNotEmpty) {
          verses.add(BibleVerse(
            id: id++,
            bookId: book.id,
            bookName: book.name,
            chapter: chapterNum,
            verse: verseNum,
            text: text.trim(),
          ));
        }
      }
    }

    return verses;
  }
}

/// Sample data for offline/testing
class KjvSampleData {
  static Future<void> loadIntoDatabase(BibleDatabase database) async {
    await database.clearAll();

    // Load multiple chapters for testing
    final allVerses = <BibleVerse>[];
    allVerses.addAll(_getGenesis1());
    allVerses.addAll(_getPsalm23());
    allVerses.addAll(_getJohn3());
    allVerses.addAll(_getJohn1());
    allVerses.addAll(_getMatthew1());

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
      "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
    ];
    return _createVerses(bookId, chapter, texts, 'John', startVerse: 1);
  }

  static List<BibleVerse> _getMatthew1() {
    const bookId = 40;
    const chapter = 1;
    const texts = [
      "The book of the generation of Jesus Christ, the son of David, the son of Abraham.",
      "Abraham begat Isaac; and Isaac begat Jacob; and Jacob begat Judas and his brethren;",
      "And Jacob begat Joseph the husband of Mary, of whom was born Jesus, who is called Christ.",
    ];
    return _createVerses(bookId, chapter, texts, 'Matthew');
  }

  static List<BibleVerse> _createVerses(int bookId, int chapter, List<String> texts, String bookName, {int startVerse = 1}) {
    final verses = <BibleVerse>[];
    for (int i = 0; i < texts.length; i++) {
      verses.add(BibleVerse(
        id: bookId * 10000 + chapter * 100 + i + startVerse,
        bookId: bookId,
        bookName: bookName,
        chapter: chapter,
        verse: i + startVerse,
        text: texts[i],
      ));
    }
    return verses;
  }
}
