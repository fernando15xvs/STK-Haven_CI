/// Compile-time opt-in for private personal-test artifacts only.
/// The flag is NOT authorization: a fresh, session-bound server grant is required.
/// Production builds omit this define. The server independently disables
/// development access when a published legal release becomes current.
class NutritionDevelopmentConfig {
  const NutritionDevelopmentConfig._();
  static const enabled = bool.fromEnvironment('STK_DEVELOPMENT_NUTRITION',
      defaultValue: false);
}
