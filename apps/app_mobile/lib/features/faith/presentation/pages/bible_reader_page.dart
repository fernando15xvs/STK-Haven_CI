import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:core/features/faith/application/bible_reader_provider.dart';
import 'package:core/features/faith/application/favorites_provider.dart';

class BibleReaderPage extends ConsumerWidget {
  const BibleReaderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(bibleReaderProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('La Biblia', style: AppTypography.headlineMedium),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: AppTypography.bodyMedium)),
        data: (state) {
          if (state.isLoading) return const Center(child: CircularProgressIndicator());
          if (state.books.isEmpty) {
             return Center(
               child: Text(
                 'La base de datos está vacía.',
                 style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
               )
             );
          }

          return Column(
            children: [
              // Selector Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: AppColors.surfaceHigh,
                          icon: const Icon(Icons.expand_more, color: AppColors.textSecondary),
                          value: state.selectedBook,
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                          items: state.books.map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (b) {
                            if (b != null) ref.read(bibleReaderProvider.notifier).selectBook(b);
                          },
                        ),
                      ),
                    ),
                    Container(height: 24, width: 1, color: AppColors.surfaceBorder, margin: const EdgeInsets.symmetric(horizontal: 16)),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          dropdownColor: AppColors.surfaceHigh,
                          icon: const Icon(Icons.expand_more, color: AppColors.textSecondary),
                          value: state.selectedChapter,
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                          items: state.chapters.map((c) => DropdownMenuItem(value: c, child: Text('Cap. $c'))).toList(),
                          onChanged: (c) {
                            if (c != null) ref.read(bibleReaderProvider.notifier).selectChapter(c);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Reading Area
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16).copyWith(bottom: 100),
                  itemCount: state.verses.length + 1, // +1 for the title header
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            '${state.selectedBook?.toUpperCase()} ${state.selectedChapter}',
                            style: AppTypography.displaySmall.copyWith(
                              letterSpacing: 2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Container(width: 40, height: 2, color: AppColors.primary),
                          const SizedBox(height: 36),
                        ],
                      );
                    }

                    final verse = state.verses[index - 1];
                    return GestureDetector(
                      onLongPress: () {
                        ref.read(favoritesProvider.notifier).toggleFavorite(verse);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('"${verse.reference}" guardado en Favoritos'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.surfaceHigh,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.top,
                                child: Transform.translate(
                                  offset: const Offset(0, -2),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Text(
                                      '${verse.verse}',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              TextSpan(
                                text: verse.text,
                                style: AppTypography.bodyLarge.copyWith(
                                  color: AppColors.textPrimary,
                                  height: 1.6,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
