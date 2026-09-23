import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:core/features/faith/application/daily_verse_provider.dart';
import 'package:core/features/faith/application/favorites_provider.dart';
import 'package:core/features/faith/application/reflection_journal_provider.dart';
import 'reflection_history_page.dart';

class DailyVersePage extends ConsumerWidget {
  const DailyVersePage({super.key});

  final List<String> moods = const [
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reflexión Diaria'),
        backgroundColor: AppColors.background,
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
            Text('¿CÓMO TE SIENTES?', style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            stateAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (state) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: moods.map((m) {
                  final isSelected = state.mood == m;
                  return ChoiceChip(
                    label: Text(m),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceHigh,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    onSelected: (selected) {
                      if (selected) ref.read(dailyVerseProvider.notifier).changeMood(m);
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            stateAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => const SizedBox(),
              data: (state) {
                if (state.isLoading) return const Center(child: CircularProgressIndicator());
                if (state.verse == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text('Preparando el contenido...\nVuelve en un momento.', textAlign: TextAlign.center, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    ),
                  );
                }

                final verse = state.verse!;
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
                              Icon(Icons.format_quote, color: AppColors.primary.withValues(alpha: 0.5), size: 32),
                              IconButton(
                                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? AppColors.error : AppColors.textSecondary),
                                onPressed: () => ref.read(favoritesProvider.notifier).toggleFavorite(verse),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text('“${verse.text}”', style: AppTypography.headlineMedium.copyWith(fontSize: 20, height: 1.5), textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          Text(verse.reference, style: AppTypography.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reflexión guardada. Puedes añadir una nota en tu historial.')),
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
            const SizedBox(height: 24),
            stateAsync.whenData((state) => Center(
              child: state.verse == null
                  ? const SizedBox()
                  : ElevatedButton.icon(
                      onPressed: () => ref.read(dailyVerseProvider.notifier).changeMood(state.mood),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Otra reflexión'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.surfaceHigh, foregroundColor: AppColors.textPrimary),
                    ),
            )).value ?? const SizedBox(),
          ],
        ),
      ),
    );
  }
}
