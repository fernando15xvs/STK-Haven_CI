import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/profile/application/gamification_provider.dart';

class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamification = ref.watch(gamificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logros y Nivel'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        'Nivel ${gamification.level}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${gamification.xp} XP Totales',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      // XP Progress bar to next level
                      // Formula: Level = floor(sqrt(XP / 150)) + 1
                      // XP = 150 * (Level - 1)^2
                      // Next Level XP = 150 * (Level)^2
                      _buildXpBar(context, gamification.xp, gamification.level),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Medallas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final achievement = gamification.achievements[index];
                  return _buildAchievementCard(context, achievement);
                },
                childCount: gamification.achievements.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXpBar(BuildContext context, int xp, int level) {
    final int currentLevelMinXp = 150 * pow(level - 1, 2).toInt();
    final int nextLevelMinXp = 150 * pow(level, 2).toInt();
    
    final int xpInCurrentLevel = xp - currentLevelMinXp;
    final int xpNeededForNextLevel = nextLevelMinXp - currentLevelMinXp;
    
    final double progress = xpNeededForNextLevel > 0 
        ? xpInCurrentLevel / xpNeededForNextLevel 
        : 0;

    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          color: Theme.of(context).colorScheme.primary,
          minHeight: 12,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$xpInCurrentLevel XP'),
            Text('$xpNeededForNextLevel XP'),
          ],
        ),
      ],
    );
  }

  Widget _buildAchievementCard(BuildContext context, achievement) {
    final bool isUnlocked = achievement.isUnlocked;
    return Card(
      elevation: isUnlocked ? 2 : 0,
      color: isUnlocked 
          ? Theme.of(context).cardColor 
          : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isUnlocked 
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5) 
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUnlocked ? Icons.emoji_events : Icons.lock_outline,
              size: 48,
              color: isUnlocked ? Colors.amber : Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isUnlocked ? null : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              achievement.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isUnlocked ? Colors.grey[400] : Colors.grey,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (!isUnlocked && achievement.progress > 0) ...[
              const Spacer(),
              LinearProgressIndicator(
                value: achievement.progress,
                minHeight: 4,
              ),
              const SizedBox(height: 4),
              Text(
                '${(achievement.progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
