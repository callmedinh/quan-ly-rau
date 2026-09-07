/// App-level configuration.
///
/// Supabase credentials can be provided at build/run time with
/// `--dart-define`, or edited directly in this file:
///
/// ```bash
/// flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///             --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
/// ```
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR-PROJECT-REF.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR-ANON-KEY',
  );

  static const String appTitle = 'Quản Lý Rau';

  /// True once real Supabase credentials have been provided.
  static bool get isConfigured =>
      !supabaseUrl.contains('YOUR-PROJECT') &&
      !supabaseAnonKey.contains('YOUR-ANON-KEY');
}
