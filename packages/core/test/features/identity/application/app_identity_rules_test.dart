import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/identity/application/app_identity_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppIdentityRules', () {
    test('classifies no session, anonymous and permanent sessions', () {
      expect(
        AppIdentityRules.classifySession(
          hasUser: false,
          email: null,
        ),
        AppSessionKind.none,
      );
      expect(
        AppIdentityRules.classifySession(
          hasUser: true,
          email: null,
        ),
        AppSessionKind.anonymous,
      );
      expect(
        AppIdentityRules.classifySession(
          hasUser: true,
          email: 'person@example.com',
        ),
        AppSessionKind.permanent,
      );
    });

    test('empty capabilities fall back to athlete', () {
      expect(
        AppIdentityRules.sanitizeCapabilities(const <UserCapability>{}),
        {UserCapability.athlete},
      );
    });

    test('capability names are deterministic', () {
      expect(
        AppIdentityRules.capabilityNames({
          UserCapability.coach,
          UserCapability.athlete,
        }),
        ['athlete', 'coach'],
      );
    });

    test('parses only supported capability rows', () {
      expect(
        AppIdentityRules.parseCapabilityRows([
          {'capability': 'coach'},
          {'capability': 'athlete'},
          {'capability': 'admin'},
          {'wrong': 'coach'},
        ]),
        {
          UserCapability.athlete,
          UserCapability.coach,
        },
      );
    });

    test('unsupported-only remote rows still fail closed to athlete', () {
      expect(
        AppIdentityRules.parseCapabilityRows([
          {'capability': 'admin'},
        ]),
        {UserCapability.athlete},
      );
    });
  });

  group('AppIdentityState', () {
    test('permanent account derives signedIn from session kind', () {
      const state = AppIdentityState(
        sessionKind: AppSessionKind.permanent,
        userId: 'u1',
        email: 'person@example.com',
        remoteCapabilities: {
          UserCapability.athlete,
          UserCapability.coach,
        },
      );

      expect(state.signedIn, isTrue);
      expect(state.hasAnonymousSession, isFalse);
      expect(state.isCoach, isTrue);
    });

    test('anonymous session is never treated as signed in app identity', () {
      const state = AppIdentityState(
        sessionKind: AppSessionKind.anonymous,
        userId: 'anon',
      );

      expect(state.signedIn, isFalse);
      expect(state.hasAnonymousSession, isTrue);
    });
  });
}
