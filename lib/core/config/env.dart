/// Build-time configuration.
///
/// Pass Supabase credentials with:
///   flutter run --dart-define-from-file=env.json
/// When they are missing the app runs in local demo mode with a persistent
/// on-device database seeded from assets/demo/seed.json.
class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Set FORCE_DEMO=true to ignore Supabase credentials (useful for demos).
  static const forceDemo = bool.fromEnvironment('FORCE_DEMO');

  static bool get hasSupabase =>
      !forceDemo &&
      supabaseUrl.startsWith('https://') &&
      supabaseAnonKey.length > 20 &&
      !supabaseUrl.contains('YOUR-PROJECT-REF');
}
