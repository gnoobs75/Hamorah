import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A chip widget for displaying Scripture references
class VerseChip extends StatelessWidget {
  final String reference;
  final VoidCallback? onTap;
  final bool isSelected;

  const VerseChip({
    super.key,
    required this.reference,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.accentLight
          : AppColors.accentLight.withOpacity(0.2),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book,
                size: 16,
                color: isSelected ? Colors.white : AppColors.accentLight,
              ),
              const SizedBox(width: 6),
              Text(
                reference,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.accentLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A larger verse card for displaying in lists
class VerseCard extends StatelessWidget {
  final String reference;
  final String verseText;
  final String? context;
  final String? note;
  final Duration? mentionedAt;
  final VoidCallback? onTap;
  final VoidCallback? onAddNote;

  const VerseCard({
    super.key,
    required this.reference,
    required this.verseText,
    this.context,
    this.note,
    this.mentionedAt,
    this.onTap,
    this.onAddNote,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context_) {
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
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      reference,
                      style: TextStyle(
                        color: AppColors.accentLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (mentionedAt != null)
                    Text(
                      'at ${_formatDuration(mentionedAt!)}',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  if (onAddNote != null)
                    IconButton(
                      icon: Icon(
                        note != null ? Icons.edit_note : Icons.note_add,
                        size: 20,
                      ),
                      onPressed: onAddNote,
                      color: AppColors.secondaryLight,
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Verse text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                      color: AppColors.primaryLight,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  verseText,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),

              // Context from sermon
              if (context != null && context!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Context from sermon:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"$context"',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // User note
              if (note != null && note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.note,
                        size: 16,
                        color: AppColors.secondaryLight,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          note!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
