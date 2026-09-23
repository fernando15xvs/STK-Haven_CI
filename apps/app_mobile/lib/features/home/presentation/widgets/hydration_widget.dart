import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/home/application/hydration_provider.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

class HydrationWidget extends ConsumerStatefulWidget {
  const HydrationWidget({super.key});

  @override
  ConsumerState<HydrationWidget> createState() => _HydrationWidgetState();
}

class _HydrationWidgetState extends ConsumerState<HydrationWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(hydrationProvider.notifier).checkDateAndRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hydration = ref.watch(hydrationProvider);
    final targetMl = 3000; // E.g., 3L daily goal
    final double progress = (hydration.waterMl / targetMl).clamp(0.0, 1.0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.water_drop, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Hidratación Diaria',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${hydration.waterMl} / $targetMl ml',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: AppColors.surfaceBorder,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAddButton(context, ref, 'Vaso', 250, Icons.local_drink),
                _buildAddButton(context, ref, 'Botella', 500, Icons.water),
                _buildAddButton(context, ref, 'Shaker', 750, Icons.sports_mma),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, WidgetRef ref, String label, int ml, IconData icon) {
    return InkWell(
      onTap: () {
        ref.read(hydrationProvider.notifier).addWater(ml);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
            Text('+$ml ml', style: TextStyle(fontSize: 10, color: Colors.blue.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}
