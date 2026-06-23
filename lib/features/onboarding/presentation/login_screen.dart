import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../vibe/providers/session_providers.dart';


class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = useTextEditingController();
    final otp = useTextEditingController(); // OTP path only
    final loading = useState(false);
    final sent = useState(false);
    final sentEmail = useState('');
    final resendCooldown = useState(0); // OTP path only
    final authSub = useRef<StreamSubscription<AuthState>?>(null);

    // True when this screen is upgrading an existing guest (anonymous)
    // session rather than signing in fresh — changes which Supabase Auth
    // calls are used so the guest's user id (and everything written under
    // it: sessions, picks, ai_picks, memory_nodes...) survives the upgrade
    // unchanged instead of being replaced by a brand-new account.
    final isGuestUpgrade = ref.read(guestIdentityServiceProvider).isGuest;

    useEffect(() {
      return () => authSub.value?.cancel();
    }, const []);

    useEffect(() {
      if (isGuestUpgrade) {
        ref.read(analyticsRepositoryProvider).trackSignupPromptShown(surface: 'login_screen');
      }
      return null;
    }, const []);

    Future<void> routeAfterSignIn() async {
      if (!context.mounted) return;
      HapticFeedback.heavyImpact();
      final profile = await ref.read(sessionRepositoryProvider).getProfile();
      final pendingToken = ref.read(pendingPlanTokenProvider);
      if (!context.mounted) return;
      if (profile?.displayName == null) {
        context.go('/setup');
      } else if (!profile!.onboardingCompleted) {
        context.go('/onboarding');
      } else if (pendingToken != null) {
        ref.read(pendingPlanTokenProvider.notifier).state = null;
        context.go('/p/$pendingToken');
      }
      // else: _AuthRefresh picks up the auth change and redirects to /vibe
    }

    Future<void> sendOtp() async {
      final raw = email.text.trim().toLowerCase();
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (raw.isEmpty || !emailRegex.hasMatch(raw)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("enter a valid email first.")),
        );
        return;
      }
      loading.value = true;
      ref.read(analyticsRepositoryProvider).trackSignupStarted();
      try {
        if (FeatureFlags.emailConfirmationEnabled) {
          // MAGIC LINK PATH — send link, show waiting state, listen for click.
          if (isGuestUpgrade) {
            await ref.read(guestIdentityServiceProvider).beginUpgrade(
                  raw,
                  emailRedirectTo: 'trombl://auth/callback',
                );
          } else {
            await ref.read(supabaseProvider).auth.signInWithOtp(
              email: raw,
              emailRedirectTo: 'trombl://auth/callback',
            );
          }
          sentEmail.value = raw;
          sent.value = true;
          loading.value = false;
          authSub.value?.cancel();
          authSub.value = ref
              .read(supabaseProvider)
              .auth
              .onAuthStateChange
              .listen((state) async {
            // A guest upgrade confirms via `userUpdated` (the session/user
            // already existed) instead of `signedIn` (a brand-new one).
            final completed = isGuestUpgrade
                ? state.event == AuthChangeEvent.userUpdated
                : state.event == AuthChangeEvent.signedIn;
            if (completed) {
              authSub.value?.cancel();
              authSub.value = null;
              if (isGuestUpgrade) {
                final id = ref.read(guestIdentityServiceProvider).currentId ?? '';
                ref.read(analyticsRepositoryProvider)
                    .trackSignupCompleted(oldGuestId: id, newUserId: id);
              } else {
                ref.read(analyticsRepositoryProvider)
                    .trackLoginCompleted(method: 'magic_link');
              }
              await routeAfterSignIn();
            }
          });
        } else {
          // OTP PATH — Supabase sends an 8-digit code; user types it to verify.
          // signedIn (or userUpdated, for a guest upgrade) fires only after
          // verifyOTP succeeds, not immediately here.
          if (isGuestUpgrade) {
            await ref.read(guestIdentityServiceProvider).beginUpgrade(raw);
          } else {
            await ref.read(supabaseProvider).auth.signInWithOtp(
              email: raw,
              shouldCreateUser: true,
            );
          }
          sentEmail.value = raw;
          sent.value = true;
          resendCooldown.value = 30;
          Timer.periodic(const Duration(seconds: 1), (t) {
            if (resendCooldown.value <= 0) {
              t.cancel();
            } else {
              resendCooldown.value--;
            }
          });
          loading.value = false;
        }
      } catch (e) {
        debugPrint('sendOtp error: $e');
        final msg = e is AuthException ? e.message : e.toString();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), duration: const Duration(seconds: 6)),
          );
        }
        loading.value = false;
      }
    }

    // OTP path only — verify the 8-digit code the user received.
    Future<void> verifyOtp() async {
      final code = otp.text.trim();
      if (code.length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("enter the full 8-digit code from ur email.")),
        );
        return;
      }
      loading.value = true;
      try {
        if (isGuestUpgrade) {
          final id = ref.read(guestIdentityServiceProvider).currentId ?? '';
          await ref.read(guestIdentityServiceProvider).confirmUpgrade(
                email: sentEmail.value,
                token: code,
              );
          ref.read(analyticsRepositoryProvider)
              .trackSignupCompleted(oldGuestId: id, newUserId: id);
        } else {
          await ref.read(supabaseProvider).auth.verifyOTP(
                email: sentEmail.value,
                token: code,
                type: OtpType.email,
              );
          ref.read(analyticsRepositoryProvider).trackLoginCompleted(method: 'otp');
        }
        await routeAfterSignIn();
      } catch (e) {
        debugPrint('verifyOtp error: $e');
        final msg = e is AuthException ? e.message : e.toString();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), duration: const Duration(seconds: 6)),
          );
        }
      } finally {
        loading.value = false;
      }
    }

    final joiningPlan = ref.watch(pendingPlanTokenProvider) != null;

    // Subtitle text changes based on flag + sent state.
    final String subtitle;
    if (FeatureFlags.emailConfirmationEnabled) {
      subtitle = sent.value
          ? 'check ur email. tap the link and ur in.'
          : 'drop ur email — trom sends a magic link. no password needed.';
    } else {
      subtitle = sent.value
          ? 'enter the 8-digit code from ur email to ${sentEmail.value}\n(ignore any "verify" link — just type the code)'
          : 'drop ur email. trom\'s got the rest.';
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 44), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Text(
                sent.value
                    ? 'check ur email.'
                    : joiningPlan
                        ? 'join the plan.\nwho r u?'
                        : isGuestUpgrade
                            ? 'save ur progress\nbefore u lose it.'
                            : 'trom needs a name\nto yell at.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: TromblText.serif,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: TromblColors.text,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: TromblColors.textSub, height: 1.5),
              ),
              const SizedBox(height: 28),
              if (kDebugMode) ...[
                _PrimaryButton(
                  label: '⚡ dev skip (fresh user)',
                  onTap: () async {
                    loading.value = true;
                    try {
                      await ref.read(supabaseProvider).auth.signInWithPassword(
                        email: 'dev@trombl.com',
                        password: 'trombldev123',
                      );
                      final uid = ref.read(supabaseProvider).auth.currentUser?.id;
                      if (uid != null) {
                        await ref.read(supabaseProvider).from('profiles').upsert({
                          'id': uid,
                          'display_name': null,
                          'handle': null,
                          'city': null,
                          'lifestyle': null,
                          'onboarding_completed': false,
                          'goals': <String>[],
                          'archetype': null,
                          'schedule_type': null,
                          'weekend_pref': null,
                          'wants_more': <String>[],
                        });
                      }
                      ref.read(activeSessionProvider.notifier).clear();
                      if (context.mounted) context.go('/setup');
                    } catch (e) {
                      debugPrint('dev login error: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('dev skip failed: $e')),
                        );
                      }
                    } finally {
                      if (context.mounted) loading.value = false;
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
              // Body: OTP entry (false path, sent), magic-link wait (true path, sent),
              // or email input (either path, not yet sent).
              if (!FeatureFlags.emailConfirmationEnabled && sent.value) ...[
                TextField(
                  controller: otp,
                  keyboardType: TextInputType.visiblePassword,
                  textAlign: TextAlign.center,
                  maxLength: 8,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(
                    color: TromblColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '········',
                    hintStyle: const TextStyle(color: TromblColors.textMuted, letterSpacing: 8),
                    filled: true,
                    fillColor: TromblColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) {
                    if (v.length == 8 && !loading.value) verifyOtp();
                  },
                ),
                const SizedBox(height: 14),
                _PrimaryButton(
                  label: loading.value ? 'verifying…' : "verify →",
                  onTap: loading.value ? null : verifyOtp,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: loading.value ? null : () {
                        sent.value = false;
                        otp.clear();
                      },
                      child: const Text(
                        'wrong email?',
                        style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
                      ),
                    ),
                    const Text(' · ',
                        style: TextStyle(color: TromblColors.textMuted, fontSize: 13)),
                    GestureDetector(
                      onTap: (loading.value || resendCooldown.value > 0)
                          ? null
                          : sendOtp,
                      child: Text(
                        resendCooldown.value > 0
                            ? 'resend in ${resendCooldown.value}s'
                            : 'resend code',
                        style: TextStyle(
                          color: resendCooldown.value > 0
                              ? TromblColors.textMuted
                              : TromblColors.jomo,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (FeatureFlags.emailConfirmationEnabled && sent.value) ...[
                // Magic-link sent — user just needs to click the link.
                GestureDetector(
                  onTap: () {
                    authSub.value?.cancel();
                    authSub.value = null;
                    sent.value = false;
                  },
                  child: const Text(
                    'wrong email? start over',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: TromblColors.text, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'u@email.com',
                    hintStyle: const TextStyle(color: TromblColors.textMuted),
                    filled: true,
                    fillColor: TromblColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _PrimaryButton(
                  label: loading.value ? 'sending…' : "let's go →",
                  onTap: loading.value ? null : sendOtp,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: onTap == null
              ? null
              : const LinearGradient(colors: [TromblColors.fomo, TromblColors.jomo]),
          color: onTap == null ? TromblColors.card : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: onTap == null ? TromblColors.textMuted : const Color(0xFF090909),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
