import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/faith/application/daily_verse_provider.dart';
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
                  Expanded(child: Text('¿CÓMO TE SIENTES?', style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary))),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReflectionHistoryPageWeb())),
                    icon: const Icon(Icons.history_edu_outlined),
                    label: const Text('Mis reflexiones'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              stateAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Text('No se pudo cargar el estado de la reflexión.', style: AppTypography.bodyMedium.copyWith(color: AppColors.error)),
                data: (state) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: moods.map((mood) => ChoiceChip(
                    label: Text(mood),
                    selected: state.mood == mood,
                    onSelected: (selected) {
                      if (selected) ref.read(dailyVerseProvider.notifier).changeMood(mood);
                    },
                  )).toList(growable: false),
                ),
              ),
              const SizedBox(height: 24),
              stateAsync.when(
                loading: () => const _LoadingCard(),
                error: (error, _) => _MessageCard(
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 40),
                      const SizedBox(height: 10),
                      Text('No se pudo cargar la reflexión.', style: AppTypography.headlineSmall),
                      const SizedBox(height: 6),
                      Text('$error', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
                    ],
                  ),
                ),
                data: (state) {
                  final verse = state.verse;
                  if (state.isLoading || verse == null) return const _LoadingCard();
                  final favorites = ref.watch(favoritesProvider);
                  final isFavorite = favorites.any((favorite) => favorite.id == verse.id);

                  return Column(
                    children: [
                      _MessageCard(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.format_quote, color: AppColors.primary.withValues(alpha: 0.55), size: 34),
                                const Spacer(),
                                IconButton.filledTonal(
                                  tooltip: isFavorite ? 'Quitar de favoritos' : 'Guardar en favoritos',
                                  onPressed: () => ref.read(favoritesProvider.notifier).toggleFavorite(verse),
                                  icon: Icon(isFavorite ? Icons.bookmark : Icons.bookmark_border, color: isFavorite ? AppColors.primary : AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SelectableText('“${verse.text}”', textAlign: TextAlign.center, style: AppTypography.headlineMedium.copyWith(fontSize: 21, height: 1.55)),
                            const SizedBox(height: 20),
                            Text(verse.reference, style: AppTypography.labelLarge.copyWith(color: AppColors.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () async {
                            await ref.read(reflectionJournalProvider.notifier).saveVerse(verse, state.mood);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reflexión guardada. Puedes añadir una nota en tu historial.')));
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
                  if (state.verse == null || state.isLoading) return const SizedBox.shrink();
                  return Center(
                    child: FilledButton.tonalIcon(
                      onPressed: () => ref.read(dailyVerseProvider.notifier).changeMood(state.mood),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Otra reflexión'),
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
    return Scaffold(backgroundColor: AppColors.background, appBar: AppBar(title: const Text('Reflexión diaria')), body: content);
  }
}

class _MessageCard extends StatelessWidget {
  final Widget child;
  const _MessageCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.lg_, border: Border.all(color: AppColors.border)),
    child: child,
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => const _MessageCard(
    child: Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: CircularProgressIndicator())),
  );
}
