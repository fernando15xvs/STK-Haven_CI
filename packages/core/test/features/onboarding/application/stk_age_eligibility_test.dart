import 'package:core/features/onboarding/application/stk_age_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('STK 15+ declaration: account eligibility', () {
    final today = DateTime(2026, 11, 17, 23, 59);

    test('a day before 15th birthday is blocked, birthday is eligible', () {
      final dob = DateTime(2011, 11, 18);
      expect(StkAgeEligibility.ageOn(dob, today), 14);
      expect(StkAgeEligibility.canBeginNewAccount(
        birthDate: dob, today: today,
      ), isFalse);
      expect(StkAgeEligibility.classify(
        birthDate: dob, today: DateTime(2026, 11, 18),
      ), StkDeclaredAgeBand.teen15To17);
      expect(StkAgeEligibility.canBeginNewAccount(
        birthDate: dob, today: DateTime(2026, 11, 18),
      ), isTrue);
    });

    test('turning 18 changes only declared band, not verified state', () {
      final dob = DateTime(2008, 11, 18);
      expect(StkAgeEligibility.classify(
        birthDate: dob, today: today,
      ), StkDeclaredAgeBand.teen15To17);
      expect(StkAgeEligibility.classify(
        birthDate: dob, today: DateTime(2026, 11, 18),
      ), StkDeclaredAgeBand.adult18PlusDeclared);
    });

    test('missing, future or implausible DOB cannot open a new account', () {
      for (final dob in <DateTime?>[
        null,
        DateTime(2026, 11, 18),
        DateTime(1899, 12, 31),
      ]) {
        expect(StkAgeEligibility.classify(
          birthDate: dob, today: today,
        ), StkDeclaredAgeBand.unknownLegacy);
        expect(StkAgeEligibility.canBeginNewAccount(
          birthDate: dob, today: today,
        ), isFalse);
      }
    });

    test('day-only policy ignores clock time and supports leap days', () {
      final leapDob = DateTime(2012, 2, 29, 23, 50);
      expect(StkAgeEligibility.ageOn(
        leapDob, DateTime(2027, 2, 28, 23, 59),
      ), 14);
      expect(StkAgeEligibility.ageOn(
        leapDob, DateTime(2027, 3, 1),
      ), 15);
      expect(StkAgeEligibility.canBeginNewAccount(
        birthDate: leapDob, today: DateTime(2027, 3, 1),
      ), isTrue);
    });
  });

  group('STK proposed nutrition capabilities never grant backend access', () {
    StkNutritionFeatureAccess access({
      required StkDeclaredAgeBand band,
      bool terms = true,
      bool online = true,
      bool photoConsent = true,
      bool verified = false,
      bool fresh = false,
    }) => StkNutritionFeatureAccess.resolve(
      declaredAge: band,
      termsCurrent: terms,
      isOnline: online,
      photoProcessingConsented: photoConsent,
      backendVerifiedAdult: verified,
      backendGrantFresh: fresh,
    );

    test('teen can see educational goals and descriptive photo scan', () {
      final teen = access(band: StkDeclaredAgeBand.teen15To17);
      expect(teen.canSeeEducationalGoals, isTrue);
      expect(teen.canRequestDescriptiveFoodVision, isTrue);
      expect(teen.canViewInformationalPhotoNumbers, isFalse);
      expect(teen.canViewPersonalizedAdultTargets, isFalse);
    });

    test('teen with stale adult grant cannot see adult targets', () {
      final teen = access(
        band: StkDeclaredAgeBand.teen15To17,
        verified: true,
        fresh: true,
      );
      expect(teen.canViewPersonalizedAdultTargets, isFalse);
      expect(teen.canViewInformationalPhotoNumbers, isFalse);
    });

    test('editable declared adult DOB is not authorization', () {
      final adult = access(band: StkDeclaredAgeBand.adult18PlusDeclared);
      expect(adult.canSeeEducationalGoals, isTrue);
      expect(adult.canViewPersonalizedAdultTargets, isFalse);
      expect(adult.canViewInformationalPhotoNumbers, isFalse);
    });

    test('only fresh online verified adult grant enables numeric targets', () {
      for (final online in [true, false]) {
        for (final fresh in [true, false]) {
          final adult = access(
            band: StkDeclaredAgeBand.adult18PlusDeclared,
            verified: true, fresh: fresh, online: online,
          );
          expect(adult.canViewPersonalizedAdultTargets, online && fresh);
        }
      }
    });

    test('no consent to photo sharing means no scan and no photo ranges', () {
      final adult = access(
        band: StkDeclaredAgeBand.adult18PlusDeclared,
        verified: true, fresh: true, photoConsent: false,
      );
      expect(adult.canRequestDescriptiveFoodVision, isFalse);
      expect(adult.canViewInformationalPhotoNumbers, isFalse);
    });

    test('expired Terms, underage and unknown are always safe', () {
      for (final band in [
        StkDeclaredAgeBand.under15,
        StkDeclaredAgeBand.unknownLegacy,
      ]) {
        final denied = access(band: band, verified: true, fresh: true);
        expect(denied.canSeeEducationalGoals, isFalse);
        expect(denied.canRequestDescriptiveFoodVision, isFalse);
        expect(denied.canViewPersonalizedAdultTargets, isFalse);
      }
      final pending = access(
        band: StkDeclaredAgeBand.adult18PlusDeclared,
        terms: false,
        verified: true,
        fresh: true,
      );
      expect(pending.canViewPersonalizedAdultTargets, isFalse);
      expect(pending.canRequestDescriptiveFoodVision, isFalse);
    });
  });
}
