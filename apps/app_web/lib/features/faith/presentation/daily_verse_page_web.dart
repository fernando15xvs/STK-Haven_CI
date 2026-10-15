import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/faith/application/daily_verse_provider.dart';
import 'package:core/features/faith/application/bible_reader_provider.dart';
import 'package:core/features/faith/presentation/widgets/contextual_passage_details.dart';
import 'bible_reader_page_web.dart';
import 'package:core/features/faith/application/favorites_provider.dart';
import 'package:core/features/faith/application/reflection_journal_provider.dart';

import '../../../../core/theme/app_colors.dart';
import 'reflection_history_page_web.dart';

class DailyVersePageWeb extends ConsumerWidget {
  final bool embedded;

  const DailyVersePageWeb({super.key, this.embedded = false});

  static const moods = <String>[
    'General',
    'Triste',
    'Agradecido',
    'Ansioso',
    'Esperanza',
    'Enojado',
    'Cansado',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(dailyVerseProvider);

    final content = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 90),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '¿CÓMO TE SIENTES?',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.of(context).textSecondary,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ReflectionHistoryPageWeb(),
                      ),
                    ),
                    icon: const Icon(Icons.history_edu_outlined),
                    label: const Text('Mis reflexiones'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              stateAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Text(
                  'No se pudo cargar el estado de la reflexión.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.of(context).error,
                  ),
                ),
                data: (state) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: moods
                      .map(
                        (mood) => ChoiceChip(
                          label: Text(mood),
                          selected: state.mood == mood,
                          onSelected: (selected) {
                            if (selected)
                              ref
                                  .read(dailyVerseProvider.notifier)
                                  .changeMood(mood);
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 24),
              stateAsync.when(
                loading: () => const _LoadingCard(),
                error: (error, _) => _MessageCard(
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppColors.of(context).error,
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No se pudo cargar la reflexión.',
                        style: AppTypography.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$error',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.of(context).textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                data: (state) {
                  final verse = state.verse;
                  if (state.isLoading || verse == null)
                    return const _LoadingCard();
                  final favorites = ref.watch(favoritesProvider);
                  final isFavorite = favorites.any(
                    (favorite) => favorite.id == verse.id,
                  );

                  return Column(
                    children: [
                      _MessageCard(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.format_quote,
                                  color: AppColors.of(
                                    context,
                                  ).primary.withValues(alpha: 0.55),
                                  size: 34,
                                ),
                                const Spacer(),
                                IconButton.filledTonal(
                                  tooltip: isFavorite
                                      ? 'Quitar de favoritos'
                                      : 'Guardar en favoritos',
                                  onPressed: () => ref
                                      .read(favoritesProvider.notifier)
                                      .toggleFavorite(verse),
                                  icon: Icon(
                                    isFavorite
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                    color: isFavorite
                                        ? AppColors.of(context).primary
                                        : AppColors.of(context).textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SelectableText(
                              '“${verse.text}”',
                              textAlign: TextAlign.center,
                              style: AppTypography.headlineMedium.copyWith(
                                fontSize: 21,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              verse.reference,
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.of(context).primary,
                              ),
                            ),
                            ContextualPassageDetails(
                              verse: verse,
                              onReadChapter: () async {
                                await ref.read(bibleReaderProvider.future);
                                await ref.read(bibleReaderProvider.notifier).selectBook(verse.book);
                                await ref.read(bibleReaderProvider.notifier).selectChapter(verse.chapter);
                                if (!context.mounted) return;
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BibleReaderPageWeb()));
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () async {
                            await ref
                                .read(reflectionJournalProvider.notifier)
                                .saveVerse(verse, state.mood);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Reflexión guardada. Puedes añadir una nota en tu historial.',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.bookmark_add_outlined),
                          label: const Text('Guardar en mis reflexiones'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              stateAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (state) {
                  if (state.verse == null || state.isLoading)
                    return const SizedBox.shrink();
                  return Center(
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        final verse = state.verse;
                        if (verse == null) return;
                        await ref.read(bibleReaderProvider.future);
                        await ref.read(bibleReaderProvider.notifier).selectBook(verse.book);
                        await ref.read(bibleReaderProvider.notifier).selectChapter(verse.chapter);
                        if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BibleReaderPageWeb()));
                      },
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('Leer el capítulo'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (embedded) return content;
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      appBar: AppBar(title: const Text('Reflexión diaria')),
      body: content,
    );
  }
}

class _MessageCard extends StatelessWidget {
  final Widget child;
  const _MessageCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.of(context).surface,
      borderRadius: AppRadius.lg_,
      border: Border.all(color: AppColors.of(context).border),
    ),
    child: child,
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => const _MessageCard(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}
