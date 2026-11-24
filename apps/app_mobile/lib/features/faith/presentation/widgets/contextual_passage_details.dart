import 'package:core/domain/models/verse.dart';
import 'package:flutter/material.dart';

/// Keeps the application note visually distinct from the Bible quotation.
class ContextualPassageDetails extends StatelessWidget {
  final Verse verse;
  final VoidCallback onReadChapter;
  final bool compact;

  const ContextualPassageDetails({
    super.key,
    required this.verse,
    required this.onReadChapter,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (verse.explanation?.isNotEmpty == true) ...[
          const SizedBox(height: 14),
          Text('¿Qué significa este pasaje?',
              style: compact ? textTheme.labelLarge : textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(verse.explanation!, style: textTheme.bodyMedium),
        ],
        if (verse.reflectionQuestion?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Text('Para reflexionar: ${verse.reflectionQuestion!}',
              style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Leer el capítulo'),
            onPressed: onReadChapter,
          ),
        ),
      ],
    );
  }
}
