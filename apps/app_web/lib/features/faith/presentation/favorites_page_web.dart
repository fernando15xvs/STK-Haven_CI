import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/domain/models/verse.dart';
import 'package:core/features/faith/application/favorites_provider.dart';

import '../../../../core/theme/app_colors.dart';

class FavoritesPageWeb extends ConsumerWidget {
  final bool embedded;

  const FavoritesPageWeb({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    final content = favorites.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_border, size: 58, color: AppColors.textSecondary.withValues(alpha: 0.45)),
                    const SizedBox(height: 14),
                    Text('No hay versículos guardados', style: AppTypography.headlineLarge, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      'En la Biblia, usa el botón de marcador junto a un versículo para guardarlo aquí.',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                itemCount: favorites.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final favorite = favorites[index];
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.lg_,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: AppRadius.md_,
                          ),
                          child: const Icon(Icons.bookmark, color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${favorite.book} ${favorite.chapter}:${favorite.verse}', style: AppTypography.headlineSmall.copyWith(color: AppColors.primary)),
                              const SizedBox(height: 7),
                              SelectableText('“${favorite.text}”', style: AppTypography.bodyLarge.copyWith(height: 1.55)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Quitar de favoritos',
                          onPressed: () {
                            ref.read(favoritesProvider.notifier).toggleFavorite(
                                  Verse(
                                    book: favorite.book,
                                    chapter: favorite.chapter,
                                    verse: favorite.verse,
                                    text: favorite.text,
                                  ),
                                );
                          },
                          icon: const Icon(Icons.bookmark_remove_outlined, color: AppColors.error),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );

    if (embedded) return content;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Versículos favoritos')),
      body: content,
    );
  }
}
