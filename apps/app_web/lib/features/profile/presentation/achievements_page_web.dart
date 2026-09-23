import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/profile/application/gamification_provider.dart';

import '../../../core/theme/app_colors.dart';

class AchievementsPageWeb extends ConsumerWidget {
  const AchievementsPageWeb({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gamificationProvider);
    final currentMin = 150 * math.pow(state.level - 1, 2).toInt();
    final nextMin = 150 * math.pow(state.level, 2).toInt();
    final levelXp = state.xp - currentMin;
    final needed = math.max(1, nextMin - currentMin);
    final progress = (levelXp / needed).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nivel y logros')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.lg_,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.12),
                                  borderRadius: AppRadius.md_,
                                ),
                                child: const Icon(Icons.emoji_events, color: AppColors.gold, size: 30),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Nivel ${state.level}', style: AppTypography.displaySmall),
                                    Text('${state.xp} XP totales', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          LinearProgressIndicator(value: progress, minHeight: 10, borderRadius: BorderRadius.circular(20)),
                          const SizedBox(height: 7),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('$levelXp XP', style: AppTypography.labelMedium),
                              Text('$needed XP para el siguiente nivel', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  sliver: SliverToBoxAdapter(child: Text('Medallas', style: AppTypography.headlineLarge)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.crossAxisExtent >= 900 ? 3 : constraints.crossAxisExtent >= 580 ? 2 : 1;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: columns == 1 ? 2.6 : 1.55,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final achievement = state.achievements[index];
                            final unlocked = achievement.isUnlocked;
                            return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: unlocked ? AppColors.surface : AppColors.surfaceHigh.withValues(alpha: 0.55),
                                borderRadius: AppRadius.lg_,
                                border: Border.all(
                                  color: unlocked ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(unlocked ? Icons.emoji_events : Icons.lock_outline, color: unlocked ? AppColors.gold : AppColors.textDisabled, size: 34),
                                  const SizedBox(height: 10),
                                  Text(achievement.title, style: AppTypography.headlineSmall),
                                  const SizedBox(height: 5),
                                  Text(
                                    achievement.description,
                                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (!unlocked && achievement.progress > 0) ...[
                                    const SizedBox(height: 12),
                                    LinearProgressIndicator(value: achievement.progress, minHeight: 6, borderRadius: BorderRadius.circular(20)),
                                    const SizedBox(height: 5),
                                    Text('${(achievement.progress * 100).round()}%', style: AppTypography.labelSmall),
                                  ],
                                ],
                              ),
                            );
                          },
                          childCount: state.achievements.length,
                        ),
                      );
                    },
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
