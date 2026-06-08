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
    final loading = useState(false);
    // sent = true only in the magic-link path after the link has been sent.
    // In the auto-sign-in path this stays false — the user never sees a waiting state.
    final sent = useState(false);
    final sentEmail = useState('');
    final authSub = useRef<StreamSubscription<AuthState>?>(null);

    useEffect(() {
      return () => authSub.value?.cancel();
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
      try {
        if (FeatureFlags.emailConfirmationEnabled) {
          // MAGIC LINK PATH — email confirmation ON
          // Send magic link; show "check ur email" waiting state.
          // onAuthStateChange fires when the user clicks the link.
          await ref.read(supabaseProvider).auth.signInWithOtp(
            email: raw,
            emailRedirectTo: 'trombl://auth/callback',
          );
          sentEmail.value = raw;
          sent.value = true;
          loading.value = false;
          // Subscribe so we catch the signedIn event when the link is clicked.
          authSub.value?.cancel();
          authSub.value = ref
              .read(supabaseProvider)
              .auth
              .onAuthStateChange
              .listen((state) async {
            if (state.event == AuthChangeEvent.signedIn) {
              authSub.value?.cancel();
              authSub.value = null;
              await routeAfterSignIn();
            }
          });
        } else {
          // AUTO SIGN-IN PATH — email confirmation OFF (current Supabase setting)
          // Supabase fires signedIn immediately — no OTP code entry needed.
          await ref.read(supabaseProvider).auth.signInWithOtp(
            email: raw,
            shouldCreateUser: true,
          );
          sentEmail.value = raw;
          // Keep loading = true ("getting u in…") until onAuthStateChange fires.
          authSub.value?.cancel();
          authSub.value = ref
              .read(supabaseProvider)
              .auth
              .onAuthStateChange
              .listen((state) async {
            if (state.event == AuthChangeEvent.signedIn) {
              authSub.value?.cancel();
              authSub.value = null;
              loading.value = false;
              await routeAfterSignIn();
            }
          });
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

    final joiningPlan = ref.watch(pendingPlanTokenProvider) != null;

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
                sent.value
                    ? 'check ur email. tap the link and ur in.'
                    : FeatureFlags.emailConfirmationEnabled
                        ? 'drop ur email — trom sends a magic link. no password needed.'
                        : 'drop ur email. trom\'s got the rest.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: TromblColors.textSub, height: 1.5),
              ),
              const SizedBox(height: 28),
              if (kDebugMode) ...[
                _PrimaryButton(
                  label: '⚡ dev skip (fresh user)',
                  onTap: loading.value ? null : () async {
                    loading.value = true;
                    try {
                      await ref.read(supabaseProvider).auth.signInWithPassword(
                        email: 'dev@trombl.com',
                        password: 'trombldev123',
                      );
                      // Reset profile so dev account looks like a brand-new user
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
                    } finally {
                      loading.value = false;
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
              if (sent.value) ...[
                // Magic-link waiting state — no email field, just a reset option.
                GestureDetector(
                  onTap: loading.value ? null : () {
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
                  label: loading.value
                      ? (FeatureFlags.emailConfirmationEnabled ? 'sending…' : 'getting u in…')
                      : "let's go →",
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
