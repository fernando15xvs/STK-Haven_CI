class SupabaseConfig {
  const SupabaseConfig._();

  // These values are public client configuration. The publishable key is
  // intentionally safe to ship in mobile/desktop applications. Never place a
  // Supabase secret/service-role key or the Gemini API key here.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yolyhmpnmkaclevqjjeo.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_olNTHlQmupPNBIzFyFD9bw_Wymk5orz',
  );
}
