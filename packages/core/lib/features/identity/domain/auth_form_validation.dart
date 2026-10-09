/// Shared login and signup checks. Passwords are never trimmed or logged.
class AuthFormValidation {
  const AuthFormValidation._();

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String? email(String? input) {
    final value = normalizeEmail(input ?? '');
    if (value.isEmpty) return 'Escribe tu correo electrónico.';
    if (value.length > 254 || value.contains('..') ||
        value.startsWith('.') || value.contains('@.') ||
        !RegExp(r'^[^\s@]+@[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)*\.[a-z]{2,63}$')
            .hasMatch(value) ||
        value.split('@').first.length > 64) {
      return 'Ingresa un correo válido, por ejemplo nombre@correo.com.';
    }
    return null;
  }

  static String? signInPassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Escribe tu contraseña.';
    }
    return null; // Never block a valid existing legacy password.
  }

  static List<bool> passwordCriteria(String password) => [
    password.length >= 10,
    RegExp(r'[a-z]').hasMatch(password) && RegExp(r'[A-Z]').hasMatch(password),
    RegExp(r'\d').hasMatch(password),
    RegExp(r'[^a-zA-Z0-9]').hasMatch(password),
  ];

  static String? signUpPassword(String? password) {
    final value = password ?? '';
    if (value.isEmpty) return 'Crea una contraseña.';
    if (value.length < 10) return 'Usa al menos 10 caracteres.';
    if (value.length > 72) return 'Usa como máximo 72 caracteres.';
    if (value.contains(RegExp(r'\s'))) {
      return 'No uses espacios en la contraseña.';
    }
    if (!RegExp(r'[a-z]').hasMatch(value) ||
        !RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Incluye una letra mayúscula y una minúscula.';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Incluye al menos un número.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña.';
    }
    if (value != original) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }
}
