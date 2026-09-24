import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/domain/models/settings_state.dart';

class SettingsRepository {
  final Box _box;
  static const String storageKey = 'app_settings';

  SettingsRepository(this._box);

  SettingsState getSettings() {
    final Map<dynamic, dynamic>? rawData = _box.get(storageKey);
    if (rawData == null) {
      return const SettingsState();
    }
    
    // Convert to Map<String, dynamic> safely
    final Map<String, dynamic> json = Map<String, dynamic>.from(rawData);
    return SettingsState.fromJson(json);
  }

  Future<void> saveSettings(SettingsState settings) async {
    await _box.put(storageKey, settings.toJson());
  }
}
