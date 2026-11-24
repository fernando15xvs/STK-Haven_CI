import 'package:core/core/services/core_preferences.dart';

/// In-memory test implementation with the same synchronous getters as the
/// on-device SharedPreferences adapter, never reading user data from disk.
class InMemoryCorePreferenceStore implements CorePreferenceStore {
  final Map<String, Object?> _values;

  InMemoryCorePreferenceStore([Map<String, Object?> initial = const {}])
      : _values = Map<String, Object?>.from(initial);

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  int? getInt(String key) => _values[key] as int?;

  @override
  bool? getBool(String key) => _values[key] as bool?;

  @override
  List<String>? getStringList(String key) {
    final value = _values[key];
    return value is List ? List<String>.from(value) : null;
  }

  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _values[key] = List<String>.from(value);
    return true;
  }
}

void installMemoryPreferences([Map<String, Object?> initial = const {}]) {
  final store = InMemoryCorePreferenceStore(initial);
  CorePreferences.installFactory(() async => store);
}
