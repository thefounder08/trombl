import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/oauth_models.dart';
import '../../../core/auth/auth_exceptions.dart';
import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import 'widgets/apple_sign_in_button.dart';
import 'widgets/google_sign_in_button.dart';

/// Shows the modal, fires `guest_signup_prompt_viewed`, and returns
/// whichever `AuthOutcome` (if any) resulted — callers don't need to know
/// anything about the auth state machine to use this.
Future<void> showSignupBottomSheet(BuildContext context, {required String surface}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => SignupBottomSheet(surface: surface),
  );
}

class SignupBottomSheet extends ConsumerStatefulWidget {
  const SignupBottomSheet({super.key, required this.surface});
  final String surface;

  @override
  ConsumerState<SignupBottomSheet> createState() => _SignupBottomSheetState();
}

class _SignupBottomSheetState extends ConsumerState<SignupBottomSheet> {
  @override
  void initState() {
    super.initState();
    ref.read(analyticsRepositoryProvider).trackGuestSignupPromptViewed(surface: widget.surface);
  }

  void _continueWith(AuthProviderKind provider) {
    HapticFeedback.mediumImpact();
    ref.read(authControllerProvider.notifier).continueWith(provider);
  }

  void _signInExisting(AuthProviderKind provider) {
    HapticFeedback.mediumImpact();
    ref.read(authControllerProvider.notifier).signInExisting(provider);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    // Dismiss automatically on success — "no forced restart," just close
    // the sheet and let whatever screen was underneath stay exactly as it
    // was (it'll reactively pick up the now-registered user via
    // currentUserProvider/userTypeProvider on its own).
    ref.listen(authControllerProvider, (previous, next) {
      if (next is AuthSuccess && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });

    final loadingProvider = state is AuthLoading ? state.provider : null;

    return Container(
      decoration: const BoxDecoration(
        color: TromblColors.cardLit,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).padding.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'save ur progress',
            style: TextStyle(
              fontFamily: TromblText.serif,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: TromblColors.text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "everything trom knows about u stays exactly as it is — "
            "u're just not a guest anymore.",
            style: TextStyle(color: TromblColors.textSub, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 22),

          if (state is AuthIdentityConflict) _ConflictBanner(
            provider: state.provider,
            onSignInInstead: () => _signInExisting(state.provider),
          ),
          if (state is AuthFailed) _ErrorBanner(
            message: state.reason.friendlyMessage,
            onRetry: () => _continueWith(state.provider),
          ),
          if (state is AuthIdentityConflict || state is AuthFailed)
            const SizedBox(height: 14),

          GoogleSignInButton(
            loading: loadingProvider == AuthProviderKind.google,
            onTap: state is AuthLoading ? null : () => _continueWith(AuthProviderKind.google),
          ),
          const SizedBox(height: 10),
          AppleSignInButton(
            loading: loadingProvider == AuthProviderKind.apple,
            onTap: state is AuthLoading ? null : () => _continueWith(AuthProviderKind.apple),
          ),
          const SizedBox(height: 16),

          Center(
            child: GestureDetector(
              onTap: state is AuthLoading
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      context.push('/login');
                    },
              child: const Text(
                'or use email instead',
                style: TextStyle(
                  color: TromblColors.textMuted,
                  fontSize: 12.5,
                  fontFamily: TromblText.sans,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: GestureDetector(
              onTap: state is AuthLoading ? null : () => Navigator.of(context).pop(),
              child: const Text(
                'maybe later',
                style: TextStyle(
                  color: TromblColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: TromblText.sans,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.provider, required this.onSignInInstead});
  final AuthProviderKind provider;
  final VoidCallback onSignInInstead;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TromblColors.jomo.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TromblColors.jomo.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AuthFailureReason.identityAlreadyLinked.friendlyMessage,
            style: const TextStyle(color: TromblColors.text, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onSignInInstead,
            child: Text(
              'sign in to that account →',
              style: TextStyle(
                color: TromblColors.jomo,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE05252).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE05252).withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: TromblColors.text, fontSize: 12.5, height: 1.4),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRetry,
            child: const Text(
              'retry',
              style: TextStyle(
                color: Color(0xFFE05252),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
