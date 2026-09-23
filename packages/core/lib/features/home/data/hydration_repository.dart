import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/domain/models/hydration_state.dart';

class HydrationRepository {
  final Box _box;

  HydrationRepository(this._box);

  HydrationState getHydrationForDate(String dateString) {
    final Map<dynamic, dynamic>? rawData = _box.get(dateString);
    if (rawData == null) {
      return HydrationState(dateString: dateString, waterMl: 0);
    }
    
    final Map<String, dynamic> json = Map<String, dynamic>.from(rawData);
    return HydrationState.fromJson(json);
  }

  Future<void> saveHydration(HydrationState state) async {
    await _box.put(state.dateString, state.toJson());
  }
}
