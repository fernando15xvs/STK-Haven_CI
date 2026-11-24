import 'package:supabase/supabase.dart';

/// Pure Dart access point to the already-initialized platform Supabase client.
///
/// Never creates another client or session. Mobile installs the same authenticated
/// client after SupabaseFlutter.initialize and before mounting providers.
abstract final class CoreSupabaseClient {
  static SupabaseClient? _client;

  static void installClient(SupabaseClient? client) {
    _client = client;
  }

  static SupabaseClient get client {
    final value = _client;
    if (value == null) {
      throw StateError('Supabase client is not installed by the platform.');
    }
    return value;
  }
}
