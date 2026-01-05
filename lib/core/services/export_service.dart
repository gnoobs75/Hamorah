import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/bible/models/bible_models.dart';
import '../../data/pastors_notes/models/pastors_notes_models.dart';
import '../../data/user/models/user_data_models.dart';

/// Service for exporting and sharing content
class ExportService {
  static ExportService? _instance;
  static ExportService get instance {
    _instance ??= ExportService._();
    return _instance!;
  }

  ExportService._();

  // ==================== Text Sharing ====================

  /// Share a single verse
  Future<void> shareVerse(BibleVerse verse, String bookName) async {
    final text = '"${verse.text}"\n\n- $bookName ${verse.chapter}:${verse.verseNumber}';
    await Share.share(text, subject: 'Bible Verse - $bookName ${verse.chapter}:${verse.verseNumber}');
  }

  /// Share multiple verses
  Future<void> shareVerses(List<BibleVerse> verses, String bookName, int chapter) async {
    if (verses.isEmpty) return;

    final buffer = StringBuffer();
    for (final verse in verses) {
      buffer.writeln('${verse.verseNumber} ${verse.text}');
    }

    final startVerse = verses.first.verseNumber;
    final endVerse = verses.last.verseNumber;
    final ref = startVerse == endVerse
        ? '$bookName $chapter:$startVerse'
        : '$bookName $chapter:$startVerse-$endVerse';

    buffer.writeln();
    buffer.writeln('- $ref');

    await Share.share(buffer.toString(), subject: 'Bible Passage - $ref');
  }

  /// Share custom text
  Future<void> shareText(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }

  // ==================== PDF Generation ====================

  /// Generate a PDF with verses
  Future<File> generateVersesPdf({
    required String title,
    required List<BibleVerse> verses,
    required String bookName,
    required int chapter,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildPdfHeader(title),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          pw.Header(
            level: 1,
            text: '$bookName $chapter',
          ),
          pw.SizedBox(height: 20),
          ...verses.map((verse) => pw.Paragraph(
                text: '${verse.verseNumber} ${verse.text}',
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 2),
              )),
        ],
      ),
    );

    return _savePdf(pdf, 'verses_${DateTime.now().millisecondsSinceEpoch}');
  }

  /// Generate a PDF with bookmarks and highlights
  Future<File> generateStudyNotesPdf({
    required String title,
    List<Bookmark>? bookmarks,
    List<Highlight>? highlights,
    List<VerseNote>? notes,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildPdfHeader(title),
        footer: (context) => _buildPdfFooter(context),
        build: (context) {
          final widgets = <pw.Widget>[];

          // Bookmarks section
          if (bookmarks != null && bookmarks.isNotEmpty) {
            widgets.add(pw.Header(level: 1, text: 'Bookmarks'));
            widgets.add(pw.SizedBox(height: 10));
            for (final bookmark in bookmarks) {
              widgets.add(pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      bookmark.reference,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    if (bookmark.verseText != null)
                      pw.Text(
                        bookmark.verseText!,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    if (bookmark.note != null)
                      pw.Text(
                        'Note: ${bookmark.note}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ));
            }
            widgets.add(pw.SizedBox(height: 20));
          }

          // Notes section
          if (notes != null && notes.isNotEmpty) {
            widgets.add(pw.Header(level: 1, text: 'Notes'));
            widgets.add(pw.SizedBox(height: 10));
            for (final note in notes) {
              widgets.add(pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      note.reference,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(note.note),
                  ],
                ),
              ));
            }
            widgets.add(pw.SizedBox(height: 20));
          }

          // Highlights section
          if (highlights != null && highlights.isNotEmpty) {
            widgets.add(pw.Header(level: 1, text: 'Highlights'));
            widgets.add(pw.SizedBox(height: 10));
            for (final highlight in highlights) {
              widgets.add(pw.Paragraph(
                text: '• ${highlight.reference}',
                style: const pw.TextStyle(fontSize: 10),
              ));
            }
          }

          return widgets;
        },
      ),
    );

    return _savePdf(pdf, 'study_notes_${DateTime.now().millisecondsSinceEpoch}');
  }

  /// Generate a PDF for a Pastor's Notes session
  Future<File> generateSessionPdf({
    required SermonSession session,
    List<TranscriptSegment>? segments,
    List<AnnotatedVerse>? verses,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMMM d, yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildPdfHeader("Pastor's Notes"),
        footer: (context) => _buildPdfFooter(context),
        build: (context) {
          final widgets = <pw.Widget>[];

          // Session info
          widgets.add(pw.Header(
            level: 0,
            text: session.title ?? 'Untitled Session',
          ));
          widgets.add(pw.Text(
            dateFormat.format(session.createdAt),
            style: const pw.TextStyle(color: PdfColors.grey600),
          ));
          if (session.durationMs != null) {
            final duration = Duration(milliseconds: session.durationMs!);
            widgets.add(pw.Text(
              'Duration: ${_formatDuration(duration)}',
              style: const pw.TextStyle(color: PdfColors.grey600),
            ));
          }
          widgets.add(pw.SizedBox(height: 20));

          // Transcript
          if (segments != null && segments.isNotEmpty) {
            widgets.add(pw.Header(level: 1, text: 'Transcript'));
            widgets.add(pw.SizedBox(height: 10));

            for (final segment in segments) {
              final time = Duration(milliseconds: segment.offsetFromStartMs);
              widgets.add(pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 60,
                      child: pw.Text(
                        _formatDuration(time),
                        style: const pw.TextStyle(
                          color: PdfColors.grey600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(segment.text),
                    ),
                  ],
                ),
              ));
            }
            widgets.add(pw.SizedBox(height: 20));
          }

          // Scripture References
          if (verses != null && verses.isNotEmpty) {
            widgets.add(pw.Header(level: 1, text: 'Scripture References'));
            widgets.add(pw.SizedBox(height: 10));

            for (final verse in verses) {
              widgets.add(pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      verse.reference,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    if (verse.verseText != null)
                      pw.Text(
                        verse.verseText!,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    if (verse.context != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Context: "${verse.context}"',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ],
                ),
              ));
            }
          }

          // Notes
          if (session.notes != null && session.notes!.isNotEmpty) {
            widgets.add(pw.Header(level: 1, text: 'Notes'));
            widgets.add(pw.Paragraph(text: session.notes!));
          }

          return widgets;
        },
      ),
    );

    return _savePdf(pdf, 'session_${session.id}');
  }

  // ==================== Helpers ====================

  pw.Widget _buildPdfHeader(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'Hamorah',
            style: const pw.TextStyle(
              color: PdfColors.grey600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            DateFormat('yyyy-MM-dd').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  Future<File> _savePdf(pw.Document pdf, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename.pdf');
    await file.writeAsBytes(await pdf.save());
    debugPrint('PDF saved to: ${file.path}');
    return file;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Share a PDF file
  Future<void> sharePdf(File pdf, {String? subject}) async {
    await Share.shareXFiles(
      [XFile(pdf.path)],
      subject: subject,
    );
  }

  /// Print a PDF
  Future<void> printPdf(File pdf) async {
    await Printing.layoutPdf(
      onLayout: (_) => pdf.readAsBytes(),
    );
  }

  /// Preview and print a PDF
  Future<void> previewPdf(File pdf) async {
    await Printing.sharePdf(
      bytes: await pdf.readAsBytes(),
      filename: pdf.path.split('/').last,
    );
  }
}
