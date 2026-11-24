import 'package:core/core/services/supabase_client_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';

void main() {
  tearDown(() => CoreSupabaseClient.installClient(null));

  test('Core uses the exact authenticated mobile client instance', () {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test_only',
    );
    CoreSupabaseClient.installClient(client);
    expect(identical(CoreSupabaseClient.client, client), true);
    CoreSupabaseClient.installClient(null);
    expect(() => CoreSupabaseClient.client, throwsStateError);
  });
}
