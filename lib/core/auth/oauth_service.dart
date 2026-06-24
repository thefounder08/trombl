import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../app_config.dart';
import 'oauth_models.dart';

/// Pure platform-token acquisition — talks to the native Google/Apple SDKs
/// only, never to Supabase. [AuthRepository] is the layer that takes the
/// token this returns and decides whether to link it to the current guest
/// session or sign in fresh; keeping that decision out of this class is
/// what makes both paths reuse the exact same token-acquisition code.
class OAuthService {
  OAuthService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              serverClientId: AppConfig.googleServerClientId.isEmpty
                  ? null
                  : AppConfig.googleServerClientId,
              scopes: const ['email'],
            );

  final GoogleSignIn _googleSignIn;

  /// Opens Google's native account picker (Android/iOS) or the Google
  /// Identity Services popup (web), and returns an idToken Supabase can
  /// verify. Throws [OAuthCancelledException] if the user backs out.
  Future<NativeAuthCredential> signInWithGoogle() async {
    GoogleSignInAccount? account;
    try {
      account = await _googleSignIn.signIn();
    } catch (e) {
      throw OAuthUnavailableException(AuthProviderKind.google, e.toString());
    }
    if (account == null) {
      throw const OAuthCancelledException(AuthProviderKind.google);
    }

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw OAuthUnavailableException(
        AuthProviderKind.google,
        'Google did not return an idToken — usually means '
        'GOOGLE_SERVER_CLIENT_ID is missing or the OAuth client in Google '
        'Cloud Console is misconfigured for this app.',
      );
    }

    return NativeAuthCredential(
      provider: AuthProviderKind.google,
      idToken: idToken,
      email: account.email,
      fullName: account.displayName,
    );
  }

  /// Opens the native Sign in with Apple sheet (iOS/macOS) or the
  /// web-based flow (Android/web, via [AppConfig.appleServiceId] +
  /// [AppConfig.appleRedirectUri] — see docs for what has to be configured
  /// on Apple's side for that path to work at all).
  Future<NativeAuthCredential> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
        webAuthenticationOptions: kIsWeb || _needsWebAuth
            ? WebAuthenticationOptions(
                clientId: AppConfig.appleServiceId,
                redirectUri: Uri.parse(AppConfig.appleRedirectUri),
              )
            : null,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const OAuthCancelledException(AuthProviderKind.apple);
      }
      throw OAuthUnavailableException(AuthProviderKind.apple, e.message);
    } catch (e) {
      throw OAuthUnavailableException(AuthProviderKind.apple, e.toString());
    }

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw OAuthUnavailableException(
        AuthProviderKind.apple,
        'Apple did not return an identityToken.',
      );
    }

    final fullName = [credential.givenName, credential.familyName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');

    return NativeAuthCredential(
      provider: AuthProviderKind.apple,
      idToken: idToken,
      rawNonce: rawNonce,
      email: credential.email,
      fullName: fullName.isEmpty ? null : fullName,
    );
  }

  /// True on platforms where Sign in with Apple has no native SDK path and
  /// must fall back to [WebAuthenticationOptions] — i.e. everything except
  /// iOS/macOS. `sign_in_with_apple` handles the actual platform check
  /// internally too; this only decides whether to *supply* web options.
  bool get _needsWebAuth =>
      defaultTargetPlatform != TargetPlatform.iOS &&
      defaultTargetPlatform != TargetPlatform.macOS;

  /// Apple requires a cryptographically random nonce, hashed with SHA-256
  /// before being sent to Apple (the *raw* value goes to Supabase so it can
  /// verify the idToken against the same nonce).
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  Future<void> signOutGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}
