import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:core/features/faith/application/daily_verse_provider.dart';
import 'package:core/features/faith/data/contextual_passage_catalog.dart';
import 'package:core/features/faith/application/bible_reader_provider.dart';
import 'package:core/features/faith/presentation/widgets/contextual_passage_details.dart';
import 'bible_reader_page.dart';
import 'package:core/features/faith/services/verse_widget_sync.dart';
import 'package:core/features/faith/application/favorites_provider.dart';
import 'package:core/features/faith/application/reflection_journal_provider.dart';
import 'reflection_history_page.dart';

class DailyVersePage extends ConsumerWidget {
  const DailyVersePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(dailyVerseProvider);
    final mood = stateAsync.value?.mood ?? 'General';
    final moodAsync = mood == 'General'
        ? null
        : ref.watch(moodPassageProvider(mood));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reflexión Diaria'),
        backgroundColor: AppColors.of(context).background,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Mis reflexiones',
            icon: const Icon(Icons.history_edu_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReflectionHistoryPage()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿CÓMO TE SIENTES?',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.of(context).textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            stateAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (state) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ContextualPassageCatalog.moodOptions.map((m) {
                  final isSelected = state.mood == m;
                  return ChoiceChip(
                    label: Text(m),
                    selected: isSelected,
                    selectedColor: AppColors.of(context).primary,
                    backgroundColor: AppColors.of(context).surfaceHigh,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.of(context).onPrimary
                          : AppColors.of(context).textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(dailyVerseProvider.notifier).changeMood(m);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              mood == 'General'
                  ? 'Mensaje del día: permanece igual hasta mañana.'
                  : 'Reflexión para tu estado de ánimo. El Mensaje de hoy en Inicio no cambia.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.of(context).textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            stateAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => const SizedBox(),
              data: (state) {
                if (state.isLoading || (state.mood != 'General' &&
                    moodAsync?.isLoading == true)) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final verse = state.mood == 'General'
                    ? state.verse
                    : moodAsync?.value;
                if (verse == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        state.mood == 'General'
                            ? 'Preparando el contenido...\nVuelve en un momento.'
                            : 'No se encontró un pasaje para este estado de ánimo. Prueba otra opción o vuelve a General.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.of(context).textSecondary,
                        ),
                      ),
                    ),
                  );
                }

                final favorites = ref.watch(favoritesProvider);
                final isFavorite = favorites.any((v) => v.id == verse.id);

                return Column(
                  children: [
                    PremiumCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                Icons.format_quote,
                                color: AppColors.of(
                                  context,
                                ).primary.withValues(alpha: 0.5),
                                size: 32,
                              ),
                              IconButton(
                                icon: Icon(
                                  isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFavorite
                                      ? AppColors.of(context).error
                                      : AppColors.of(context).textSecondary,
                                ),
                                onPressed: () => ref
                                    .read(favoritesProvider.notifier)
                                    .toggleFavorite(verse),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '“${verse.text}”',
                            style: AppTypography.headlineMedium.copyWith(
                              fontSize: 20,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            verse.reference,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.of(context).primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ContextualPassageDetails(
                            verse: verse,
                            onReadChapter: () async {
                              await ref.read(bibleReaderProvider.future);
                              await ref.read(bibleReaderProvider.notifier).selectBook(verse.book);
                              await ref.read(bibleReaderProvider.notifier).selectChapter(verse.chapter);
                              if (!context.mounted) return;
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const BibleReaderPage()));
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
            Card(
              child: ListTile(
                leading: const Icon(Icons.widgets_outlined),
                title: const Text('Versículo en pantalla de bloqueo'),
                trailing: const Icon(Icons.info_outline),
                onTap: () async {
                  final diagnostics = await VerseWidgetSync.diagnostics();
                  if (!context.mounted) return;
                  final message = diagnostics == null
                      ? 'No se pudo consultar la instalación nativa del widget.'
                      : diagnostics['extensionBundled'] != true
                      ? 'El widget no está instalado en la aplicación firmada. '
                            'En Sideloadly desactiva Remove App Extensions. '
                            'No elimines STK Haven para corregirlo.'
                      : diagnostics['appGroupAvailable'] != true
                      ? 'El widget está incluido, pero la firma no '
                            'permite el App Group compartido. Revisa '
                            'los permisos y perfiles de firma.'
                      : 'Extensión y App Group detectados. Si el '
                            'widget no aparece en iOS, reinicia el '
                            'iPhone y revisa los registros de Sideloadly.';
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Diagnóstico del widget'),
                      content: Text(message),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Entendido'),
                        ),
                      ],
                    ),
                  );
                },
                subtitle: const Text(
                  'iPhone: mantén pulsada la pantalla de bloqueo, toca '
                  'Personalizar y añade el widget rectangular STK Haven. '
                  'Android: añade el widget STK Haven desde Widgets; '
                  'en la pantalla de bloqueo solo aparece si tu dispositivo '
                  'permite widgets allí. Se actualiza al abrir la app.',
                ),
              ),
            ),
            const SizedBox(height: 24),
            stateAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (state) {
                final verse = state.mood == 'General'
                    ? state.verse
                    : moodAsync?.value;
                if (verse == null) return const SizedBox.shrink();
                return Center(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await ref.read(bibleReaderProvider.future);
                      await ref.read(bibleReaderProvider.notifier).selectBook(verse.book);
                      await ref.read(bibleReaderProvider.notifier).selectChapter(verse.chapter);
                      if (!context.mounted) return;
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const BibleReaderPage(),
                      ));
                    },
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Leer el capítulo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.of(context).surfaceHigh,
                      foregroundColor: AppColors.of(context).textPrimary,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
