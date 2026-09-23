import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/hydration_state.dart';
import 'package:core/features/home/data/hydration_repository.dart';

final hydrationRepositoryProvider = Provider<HydrationRepository>((ref) {
  final box = Hive.box(HiveBoxes.hydration);
  return HydrationRepository(box);
});

class HydrationNotifier extends Notifier<HydrationState> {
  late final HydrationRepository _repository;

  @override
  HydrationState build() {
    _repository = ref.watch(hydrationRepositoryProvider);
    return _repository.getHydrationForDate(_getTodayString());
  }

  static String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void checkDateAndRefresh() {
    final today = _getTodayString();
    if (state.dateString != today) {
      state = _repository.getHydrationForDate(today);
    }
  }

  void addWater(int amountMl) {
    checkDateAndRefresh();
    final newAmount = (state.waterMl + amountMl).clamp(0, 9999);
    state = state.copyWith(waterMl: newAmount);
    _repository.saveHydration(state);
  }
}

final hydrationProvider = NotifierProvider<HydrationNotifier, HydrationState>(
  HydrationNotifier.new,
);
