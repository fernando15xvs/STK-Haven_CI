import 'package:core/core/services/core_preferences.dart';
import 'package:core/core/config/storage_namespace.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage adapter; no changed keys or namespace, including existing accounts.
class MobilePreferenceStore implements CorePreferenceStore {
  final SharedPreferences _prefs;

  MobilePreferenceStore(this._prefs);

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  int? getInt(String key) => _prefs.getInt(key);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  List<String>? getStringList(String key) => _prefs.getStringList(key);

  @override
  Future<bool> setString(String key, String value) => _prefs.setString(key, value);

  @override
  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  @override
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Future<bool> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);
}

Future<CorePreferenceStore> openMobilePreferences() async =>
    MobilePreferenceStore(await SharedPreferences.getInstance());

/// Called before any providers mount; keeps all existing preference keys intact.
void installMobileCorePreferences() {
  StorageNamespace.installPreferencesPrefixSetter(SharedPreferences.setPrefix);
  StorageNamespace.configureSharedPreferences();
  CorePreferences.installFactory(openMobilePreferences);
}
