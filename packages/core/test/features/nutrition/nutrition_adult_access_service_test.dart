import 'dart:async';

import 'package:core/features/nutrition/data/nutrition_adult_access_service.dart';
import 'package:test/test.dart';

void main() {
  Future<NutritionAdultCheck> inspect({
    String? initialUserId = 'account-a',
    bool anonymous = false,
    String? Function()? currentUserId,
    String? sessionToken,
    String? Function()? currentSessionToken,
    Future<dynamic> Function()? fetch,
    Duration timeout = const Duration(milliseconds: 80),
  }) => NutritionAdultAccessService.queryStatus(
    userId: initialUserId,
    isAnonymous: anonymous,
    currentUserId: currentUserId ?? () => initialUserId,
    sessionToken: sessionToken,
    currentSessionToken: currentSessionToken,
    fetch: fetch ?? () async => false,
    timeout: timeout,
  );

  test('only a fresh true response grants numeric authorization', () async {
    final allowed = await inspect(fetch: () async => true);
    expect(allowed, NutritionAdultCheck.verified);
    expect(allowed.allowsNumeric, isTrue);
    final denied = await inspect(fetch: () async => false);
    expect(denied, NutritionAdultCheck.unverified);
    expect(denied.allowsNumeric, isFalse);
    expect(denied.canRetry, isFalse);
  });

  test('an explicit denial is different from no server response', () async {
    for (final result in [null, 'true', 1, {'verified': true}]) {
      final check = await inspect(fetch: () async => result);
      expect(check, NutritionAdultCheck.unavailable);
      expect(check.allowsNumeric, isFalse);
      expect(check.canRetry, isTrue);
    }
  });

  test('offline, 401, 403, and network failures fail closed with retry',
      () async {
    for (final reason in ['network offline', '401', '403', 'socket closed']) {
      final check = await inspect(fetch: () async => throw Exception(reason));
      expect(check, NutritionAdultCheck.unavailable);
      expect(check.allowsNumeric, isFalse);
    }
  });

  test('timeout never grants adult access', () async {
    final pending = Completer<dynamic>();
    final check = await inspect(
      fetch: () => pending.future,
      timeout: const Duration(milliseconds: 10),
    );
    expect(check, NutritionAdultCheck.unavailable);
    expect(check.canRetry, isTrue);
    pending.complete(true);
  });

  test('signed-out and anonymous sessions do not call the RPC', () async {
    var calls = 0;
    Future<dynamic> fetch() async {
      calls++;
      return true;
    }
    expect(await inspect(initialUserId: null, fetch: fetch),
        NutritionAdultCheck.signedOut);
    expect(await inspect(anonymous: true, fetch: fetch),
        NutritionAdultCheck.signedOut);
    expect(calls, 0);
  });

  test('switching accounts while RPC is running rejects a late grant',
      () async {
    final server = Completer<dynamic>();
    var active = 'account-a';
    final request = inspect(
      initialUserId: 'account-a',
      currentUserId: () => active,
      fetch: () => server.future,
    );
    active = 'account-b';
    server.complete(true);
    final status = await request;
    expect(status, NutritionAdultCheck.signedOut);
    expect(status.allowsNumeric, isFalse);
  });

  test('same user ID re-login cannot inherit old session grant', () async {
    final pending = Completer<dynamic>();
    var activeToken = 'login-A';
    final request = inspect(
      initialUserId: 'account-a',
      currentUserId: () => 'account-a',
      sessionToken: 'login-A',
      currentSessionToken: () => activeToken,
      fetch: () => pending.future,
    );
    activeToken = 'login-B'; // same UID, but a different auth session
    pending.complete(true);
    final status = await request;
    expect(status, NutritionAdultCheck.signedOut);
    expect(status.allowsNumeric, isFalse);
  });

  test('missing access token cannot even issue the grant RPC', () async {
    var calls = 0;
    final status = await inspect(
      sessionToken: null,
      currentSessionToken: () => 'active-token',
      fetch: () async { calls++; return true; },
    );
    expect(status, NutritionAdultCheck.signedOut);
    expect(calls, 0);
  });

  test('rotated session plus timeout cannot claim a network error as access',
      () async {
    final pending = Completer<dynamic>();
    var activeToken = 'old';
    final request = inspect(
      sessionToken: 'old',
      currentSessionToken: () => activeToken,
      fetch: () => pending.future,
      timeout: const Duration(milliseconds: 10),
    );
    activeToken = 'new';
    expect(await request, NutritionAdultCheck.signedOut);
    pending.complete(true);
  });

  test('stable authenticated session retains valid backend decision',
      () async {
    final status = await inspect(
      sessionToken: 'stable',
      currentSessionToken: () => 'stable',
      fetch: () async => true,
    );
    expect(status, NutritionAdultCheck.verified);
  });

  test('signing out while an error arrives does not show old-account error',
      () async {
    final server = Completer<dynamic>();
    String? active = 'account-a';
    final request = inspect(
      initialUserId: 'account-a',
      currentUserId: () => active,
      fetch: () => server.future,
    );
    active = null;
    server.completeError(StateError('session expired'));
    expect(await request, NutritionAdultCheck.signedOut);
  });

  test('server revocation is observable and not cached by the service',
      () async {
    var backendGranted = true;
    Future<dynamic> fetch() async => backendGranted;
    expect((await inspect(fetch: fetch)).allowsNumeric, isTrue);
    backendGranted = false;
    expect((await inspect(fetch: fetch)).allowsNumeric, isFalse);
    expect(await inspect(fetch: fetch), NutritionAdultCheck.unverified);
  });

  test('loading has no adult grant even if an older check was verified', () {
    expect(NutritionAdultCheck.checking.allowsNumeric, isFalse);
    expect(NutritionAdultCheck.unavailable.allowsNumeric, isFalse);
    expect(NutritionAdultCheck.signedOut.allowsNumeric, isFalse);
  });
}
