import 'package:core/features/identity/domain/auth_form_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('email validation', () {
    test('trims and normalizes email for backend', () {
      expect(AuthFormValidation.normalizeEmail('  Person@Example.COM  '),
        'person@example.com');
      expect(AuthFormValidation.email('  Person@Example.COM  '), isNull);
    });

    test('rejects empty, malformed and unsafe values', () {
      for (final sample in [
        '', '  ', 'a', 'name@', '@example.com',
        'name@example', 'name @example.com', 'name@example..com',
        '.name@example.com', 'name@.example.com',
        'a@-example.com', 'a@example-.com', 'name@example.c',
        'test@example.com\nbcc:attacker@example.com',
        ('x' * 65) + '@example.com', ('x' * 254) + '@example.com',
      ]) {
        expect(AuthFormValidation.email(sample), isNotNull,
            reason: sample);
      }
    });
  });

  group('password login', () {
    test('only requires nonempty; old accounts remain usable', () {
      expect(AuthFormValidation.signInPassword(''), isNotNull);
      expect(AuthFormValidation.signInPassword(null), isNotNull);
      expect(AuthFormValidation.signInPassword('abc123'), isNull);
      expect(AuthFormValidation.signInPassword(' a b '), isNull);
    });
  });

  group('password registration', () {
    test('requires long mixed-case numeric password', () {
      expect(AuthFormValidation.signUpPassword('Stronger123'), isNull);
      expect(AuthFormValidation.signUpPassword('Stronger123!'), isNull);
      for (final bad in [
        '', 'Abc123', 'abcdefghijk12', 'ABCDEFGHIJK12',
        'Abcdefghijk', 'Abc defghijk123', ('A' * 73) + 'bc1',
      ]) {
        expect(AuthFormValidation.signUpPassword(bad), isNotNull,
          reason: bad);
      }
    });

    test('password strength checks match visible guidance', () {
      expect(AuthFormValidation.passwordCriteria('Stronger123!'),
        [true, true, true, true]);
      expect(AuthFormValidation.passwordCriteria('short'),
        [false, false, false, false]);
    });

    test('confirmation uses exact value without trimming secrets', () {
      expect(AuthFormValidation.confirmPassword('', 'Stronger123'), isNotNull);
      expect(AuthFormValidation.confirmPassword(
        'Stronger123 ', 'Stronger123'), isNotNull);
      expect(AuthFormValidation.confirmPassword(
        'Stronger123', 'Stronger123'), isNull);
    });
  });
}
