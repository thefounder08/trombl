/// App-wide config, read from --dart-define at build time.
/// Never hardcode keys. Run with:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// The LLM proxy edge function name (provider switching happens server-side).
  static const llmProxyFunction = 'llm-proxy';

  /// Base URL for invite/share links. Change this once when the custom domain
  /// is wired to Netlify — all link generation derives from this constant.
  static const shareBaseUrl = 'https://trombl.com';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
