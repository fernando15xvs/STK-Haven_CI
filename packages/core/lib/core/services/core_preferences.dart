/// Synchronous read/asynchronous write semantics of the legacy preferences API.
abstract class CorePreferenceStore {
  String? getString(String key);
  int? getInt(String key);
  bool? getBool(String key);
  List<String>? getStringList(String key);
  Future<bool> setString(String key, String value);
  Future<bool> setInt(String key, int value);
  Future<bool> setBool(String key, bool value);
  Future<bool> setStringList(String key, List<String> value);
}

/// Pure Dart gateway. Mobile injects the existing SharedPreferences storage.
abstract final class CorePreferences {
  static Future<CorePreferenceStore> Function()? _open;

  static void installFactory(
    Future<CorePreferenceStore> Function()? open,
  ) {
    _open = open;
  }

  static Future<CorePreferenceStore> getInstance() {
    final open = _open;
    if (open == null) {
      return Future<CorePreferenceStore>.error(
        StateError('Preferences backend must be installed by Mobile.'),
      );
    }
    return open();
  }
}
