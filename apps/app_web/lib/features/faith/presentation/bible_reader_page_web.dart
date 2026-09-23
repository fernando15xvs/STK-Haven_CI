import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/features/faith/application/bible_init_provider.dart';
import 'package:core/features/faith/application/bible_reader_provider.dart';
import 'package:core/features/faith/application/favorites_provider.dart';

import '../../../../core/theme/app_colors.dart';
import 'favorites_page_web.dart';

class BibleReaderPageWeb extends ConsumerWidget {
  final bool embedded;

  const BibleReaderPageWeb({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initState = ref.watch(bibleInitProvider);
    final reader = ref.watch(bibleReaderProvider);
    final favorites = ref.watch(favoritesProvider);
    final favoriteIds = favorites.map((favorite) => favorite.id).toSet();

    final content = switch (initState.status) {
      BibleDbStatus.idle || BibleDbStatus.loading => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Preparando la Biblia...'),
            ],
          ),
        ),
      BibleDbStatus.error => _BibleError(
          message: initState.errorMessage,
          onRetry: () => ref.read(bibleInitProvider.notifier).initialize(),
        ),
      BibleDbStatus.ready => reader.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _BibleError(
            message: error.toString(),
            onRetry: () => ref.invalidate(bibleReaderProvider),
          ),
          data: (state) {
            if (state.isLoading) return const Center(child: CircularProgressIndicator());
            if (state.books.isEmpty) {
              return _BibleError(
                message: 'No se encontraron libros para mostrar.',
                onRetry: () => ref.read(bibleInitProvider.notifier).initialize(),
              );
            }

            return Column(
              children: [
                _BibleSelectors(
                  selectedBook: state.selectedBook,
                  books: state.books,
                  selectedChapter: state.selectedChapter,
                  chapters: state.chapters,
                  onBookChanged: (book) {
                    if (book != null) ref.read(bibleReaderProvider.notifier).selectBook(book);
                  },
                  onChapterChanged: (chapter) {
                    if (chapter != null) ref.read(bibleReaderProvider.notifier).selectChapter(chapter);
                  },
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
                        itemCount: state.verses.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 12, bottom: 26),
                              child: Column(
                                children: [
                                  Text(
                                    '${state.selectedBook?.toUpperCase()} ${state.selectedChapter}',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.displaySmall.copyWith(letterSpacing: 1.4),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(width: 42, height: 2, color: AppColors.primary),
                                ],
                              ),
                            );
                          }

                          final verse = state.verses[index - 1];
                          final isFavorite = favoriteIds.contains(verse.id);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isFavorite ? AppColors.primary.withValues(alpha: 0.04) : Colors.transparent,
                              borderRadius: AppRadius.md_,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 34,
                                    child: Text(
                                      '${verse.verse}',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: SelectableText(
                                      verse.text,
                                      style: AppTypography.bodyLarge.copyWith(
                                        color: AppColors.textPrimary,
                                        height: 1.65,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: isFavorite ? 'Quitar de favoritos' : 'Guardar en favoritos',
                                    onPressed: () {
                                      ref.read(favoritesProvider.notifier).toggleFavorite(verse);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(isFavorite ? '${verse.reference} eliminado de favoritos' : '${verse.reference} guardado en favoritos'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    icon: Icon(
                                      isFavorite ? Icons.bookmark : Icons.bookmark_border,
                                      color: isFavorite ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
    };

    if (embedded) return content;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('La Biblia', style: AppTypography.headlineMedium),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            tooltip: 'Versículos favoritos',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FavoritesPageWeb()),
            ),
            icon: const Icon(Icons.bookmarks_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: content,
    );
  }
}

class _BibleSelectors extends StatelessWidget {
  final String? selectedBook;
  final List<String> books;
  final int? selectedChapter;
  final List<int> chapters;
  final ValueChanged<String?> onBookChanged;
  final ValueChanged<int?> onChapterChanged;

  const _BibleSelectors({
    required this.selectedBook,
    required this.books,
    required this.selectedChapter,
    required this.chapters,
    required this.onBookChanged,
    required this.onChapterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.md_,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedBook,
                      dropdownColor: AppColors.surfaceHigh,
                      items: books.map((book) => DropdownMenuItem(value: book, child: Text(book, overflow: TextOverflow.ellipsis))).toList(growable: false),
                      onChanged: onBookChanged,
                    ),
                  ),
                ),
                Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 12), color: AppColors.border),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedChapter,
                      dropdownColor: AppColors.surfaceHigh,
                      items: chapters.map((chapter) => DropdownMenuItem(value: chapter, child: Text('Cap. $chapter'))).toList(growable: false),
                      onChanged: onChapterChanged,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BibleError extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const _BibleError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_outlined, size: 44, color: AppColors.primary),
              const SizedBox(height: 14),
              Text('No pude cargar la Biblia', style: AppTypography.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                message ?? 'Revisa tu conexión e inténtalo nuevamente.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}
