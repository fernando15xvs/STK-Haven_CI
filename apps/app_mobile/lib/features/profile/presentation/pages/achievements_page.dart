import 'dart:math';

import 'package:core/core/theme/app_palette.dart';
import 'package:core/features/profile/application/gamification_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Logros son reconocimientos, no otro dashboard de Progreso.
class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(gamificationProvider);
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nivel y logros')),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nivel ${data.level}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: colors.primary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${data.xp} XP acumulados',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _levelProgress(context, data.xp, data.level),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Text('Medallas',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          if (data.achievements.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Aún no hay medallas. Tus logros aparecerán aquí.'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList.builder(
                itemCount: data.achievements.length,
                itemBuilder: (context, index) {
                  final award = data.achievements[index];
                  final unlocked = award.isUnlocked;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              label: unlocked ? 'Medalla desbloqueada' : 'Medalla bloqueada',
                              child: Icon(
                                unlocked
                                    ? Icons.emoji_events_outlined
                                    : Icons.lock_outline,
                                color: unlocked ? colors.gold : colors.textSecondary,
                                size: 36,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    award.title,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    award.description,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                  ),
                                  if (!unlocked && award.progress > 0) ...[
                                    const SizedBox(height: 12),
                                    LinearProgressIndicator(
                                      value: (award.progress as num)
                                          .toDouble()
                                          .clamp(0.0, 1.0).toDouble(),
                                      minHeight: 5,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(award.progress * 100).clamp(0, 100).toInt()} % completado',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: colors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ],
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
      ),
    );
  }

  Widget _levelProgress(BuildContext context, int xp, int level) {
    final currentMin = 150 * pow(level - 1, 2).toInt();
    final nextMin = 150 * pow(level, 2).toInt();
    final progressXp = (xp - currentMin).clamp(0, nextMin - currentMin);
    final requiredXp = nextMin - currentMin;
    final progress = requiredXp == 0 ? 0.0 : progressXp / requiredXp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0).toDouble(),
          minHeight: 9,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: 8),
        Text(
          '$progressXp de $requiredXp XP para el siguiente nivel',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.of(context).textSecondary,
              ),
        ),
      ],
    );
  }
}
