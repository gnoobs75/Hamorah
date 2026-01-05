import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/pastors_notes/models/pastors_notes_models.dart';

/// Widget to display the live transcript with highlighted verse references
class TranscriptDisplay extends StatelessWidget {
  final List<TranscriptSegment> segments;
  final String currentPartialText;

  const TranscriptDisplay({
    super.key,
    required this.segments,
    this.currentPartialText = '',
  });

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty && currentPartialText.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.record_voice_over,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Listening...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scripture references will be automatically detected',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: segments.length + (currentPartialText.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        // Show current partial text at the end
        if (index == segments.length) {
          return _PartialTextSegment(text: currentPartialText);
        }

        final segment = segments[index];
        return _TranscriptSegmentWidget(segment: segment);
      },
    );
  }
}

class _TranscriptSegmentWidget extends StatelessWidget {
  final TranscriptSegment segment;

  const _TranscriptSegmentWidget({required this.segment});

  String _formatOffset(Duration offset) {
    final minutes = offset.inMinutes;
    final seconds = offset.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasVerses = segment.detectedVerseRefs.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          SizedBox(
            width: 50,
            child: Text(
              _formatOffset(segment.offsetFromStart),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                    fontFamily: 'monospace',
                  ),
            ),
          ),
          const SizedBox(width: 8),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HighlightedText(
                  text: segment.text,
                  verseRefs: segment.detectedVerseRefs,
                ),
                if (hasVerses)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      children: segment.detectedVerseRefs.map((ref) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            ref,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.accentLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final List<String> verseRefs;

  const _HighlightedText({
    required this.text,
    required this.verseRefs,
  });

  @override
  Widget build(BuildContext context) {
    if (verseRefs.isEmpty) {
      return Text(text);
    }

    // Build regex pattern from verse references
    final pattern = verseRefs.map((ref) => RegExp.escape(ref)).join('|');
    final regex = RegExp(pattern, caseSensitive: false);

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Add text before match
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          backgroundColor: AppColors.accentLight.withOpacity(0.3),
          fontWeight: FontWeight.w600,
        ),
      ));

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: spans,
      ),
    );
  }
}

class _PartialTextSegment extends StatelessWidget {
  final String text;

  const _PartialTextSegment({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Icon(
              Icons.mic,
              size: 16,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
