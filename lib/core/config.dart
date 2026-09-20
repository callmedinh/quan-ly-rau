/// App-level configuration.
///
/// Credentials stay OUT of git: pass them at run/build time.
///
/// Recommended (reads the git-ignored `dart_defines.json`, copy the
/// `dart_defines.example.json` template):
///
/// ```bash
/// flutter run --dart-define-from-file=dart_defines.json
/// flutter build apk --release --dart-define-from-file=dart_defines.json
/// ```
///
/// Plain defines work too:
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
