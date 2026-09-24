import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Roadmap 3 identity migration contract', () {
    late String sql;

    setUpAll(() async {
      final file = _findMigration();
      expect(
        await file.exists(),
        isTrue,
        reason: 'No se encontró la migración de identidad Roadmap 3.',
      );
      sql = await file.readAsString();
    });

    test('enables RLS on profile and capability tables', () {
      expect(
        sql,
        contains('alter table public.stk_user_profiles enable row level security;'),
      );
      expect(
        sql,
        contains('alter table public.stk_user_capabilities enable row level security;'),
      );
    });

    test('anonymous role receives no table access', () {
      expect(
        sql,
        contains('revoke all on public.stk_user_profiles from anon;'),
      );
      expect(
        sql,
        contains('revoke all on public.stk_user_capabilities from anon;'),
      );
    });

    test('policies require own user id and reject anonymous JWTs', () {
      expect(sql, contains('auth.uid() = user_id'));
      expect(
        sql,
        contains(
          "coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false",
        ),
      );
    });

    test('capability domain is limited to athlete and coach', () {
      expect(
        sql,
        contains("check (capability in ('athlete', 'coach'))"),
      );
      expect(
        sql,
        contains("v_capability not in ('athlete', 'coach')"),
      );
    });

    test('sync function is invoker security and unavailable to anon', () {
      expect(sql, contains('security invoker'));
      expect(
        sql,
        contains(
          'revoke all on function public.stk_sync_own_profile(text, text[]) from public, anon;',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.stk_sync_own_profile(text, text[]) to authenticated;',
        ),
      );
    });

    test('migration rejects null capability entries before mutation', () {
      expect(
        sql,
        contains('array_position(v_capabilities, null) is not null'),
      );
    });

    test('migration never grants service_role explicitly', () {
      expect(sql.toLowerCase(), isNot(contains('grant service_role')));
    });
  });
}

File _findMigration() {
  const relative =
      'supabase/migrations/20260924052000_stk_user_profiles_and_capabilities.sql';
  var directory = Directory.current;

  for (var depth = 0; depth < 8; depth++) {
    final candidate = File('${directory.path}/$relative');
    if (candidate.existsSync()) return candidate;

    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }

  return File(relative);
}
