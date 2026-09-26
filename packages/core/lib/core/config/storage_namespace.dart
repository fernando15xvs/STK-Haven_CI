import 'package:shared_preferences/shared_preferences.dart';

/// Compile-time namespace used by preview/test web builds.
///
/// Production builds keep the empty default, preserving every existing key and
/// Hive box name. Preview builds can pass:
/// --dart-define=STK_STORAGE_NAMESPACE=roadmap3_preview
///
/// This prevents a preview served from the same web origin from reading or
/// overwriting the stable app's Hive/IndexedDB and SharedPreferences data.
class StorageNamespace {
  const StorageNamespace._();

  static const String _configured = String.fromEnvironment(
    'STK_STORAGE_NAMESPACE',
    defaultValue: '',
  );

  static String get value => normalize(_configured);

  static bool get enabled => value.isNotEmpty;

  static String scope(
    String base, {
    String? namespace,
  }) {
    final resolved = normalize(namespace ?? value);
    if (resolved.isEmpty) return base;
    return '${resolved}__$base';
  }

  static void configureSharedPreferences() {
    if (!enabled) return;
    SharedPreferences.setPrefix('stk.${value}.');
  }

  static String normalize(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return '';

    final normalized = trimmed.replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );

    return normalized
        .replaceFirst(RegExp(r'^_+'), '')
        .replaceFirst(RegExp(r'_+$'), '');
  }
}
