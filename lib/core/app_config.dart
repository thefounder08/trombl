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

  /// OAuth web client id from Google Cloud Console (Credentials → OAuth
  /// client ID → Web application) — required by `google_sign_in` on
  /// Android to mint a server-verifiable idToken, and used as the `aud`
  /// Supabase checks when validating it. Empty until configured; Google
  /// sign-in fails soft (see GoogleSignInUnavailableException) rather than
  /// crashing when it's missing.
  static const googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// Apple "Services ID" (not the App ID) from the Apple Developer portal —
  /// only needed for the web/Android `WebAuthenticationOptions` fallback
  /// path; native iOS/macOS Sign in with Apple doesn't use this at all.
  static const appleServiceId = String.fromEnvironment('APPLE_SERVICE_ID');

  /// Where Apple's web-based auth flow (Android/web only) redirects back
  /// to — must be a registered return URL on the Services ID, and must
  /// point at a relay that forwards the response into this app via the
  /// `io.trombl://` deep link. See docs/AUTHENTICATION_ARCHITECTURE.md.
  static const appleRedirectUri = String.fromEnvironment('APPLE_REDIRECT_URI');

  /// Which build flavor is running (dev | staging | prod).
  static const appFlavor = String.fromEnvironment('APP_FLAVOR', defaultValue: 'prod');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
