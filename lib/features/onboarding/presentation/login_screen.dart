import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = useTextEditingController();
    final otp = useTextEditingController();
    final loading = useState(false);
    final sent = useState(false);
    final sentEmail = useState('');

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
        await ref.read(supabaseProvider).auth.signInWithOtp(email: raw);
        sentEmail.value = raw;
        sent.value = true;
      } catch (e) {
        debugPrint('sendOtp error: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("that didn't go through. try again?")),
          );
        }
      } finally {
        loading.value = false;
      }
    }

    Future<void> verifyOtp() async {
      final code = otp.text.trim();
      if (code.length != 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("enter the 6-digit code from ur email.")),
        );
        return;
      }
      loading.value = true;
      try {
        await ref.read(supabaseProvider).auth.verifyOTP(
              email: sentEmail.value,
              token: code,
              type: OtpType.email,
            );
        // router will redirect automatically via authStateProvider
      } catch (e) {
        debugPrint('verifyOtp error: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("wrong code. check ur email and try again.")),
          );
        }
      } finally {
        loading.value = false;
      }
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
                sent.value ? 'check ur email.' : 'trom needs a name\nto yell at.',
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
                    ? 'enter the 6-digit code trom sent to ${sentEmail.value}'
                    : 'drop ur email — trom sends a code, no passwords.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: TromblColors.textSub, height: 1.5),
              ),
              const SizedBox(height: 28),
              if (kDebugMode) ...[
                _PrimaryButton(
                  label: '⚡ dev skip',
                  onTap: loading.value ? null : () async {
                    loading.value = true;
                    try {
                      await ref.read(supabaseProvider).auth.signInWithPassword(
                        email: 'dev@trombl.com',
                        password: 'trombldev123',
                      );
                    } catch (e) {
                      debugPrint('dev login error: $e');
                    } finally {
                      loading.value = false;
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
              if (!sent.value) ...[
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
              ] else ...[
                TextField(
                  controller: otp,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    color: TromblColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                    letterSpacing: 10,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '······',
                    hintStyle: const TextStyle(color: TromblColors.textMuted, letterSpacing: 10),
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
                  label: loading.value ? 'verifying…' : "verify →",
                  onTap: loading.value ? null : verifyOtp,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: loading.value ? null : () {
                    sent.value = false;
                    otp.clear();
                  },
                  child: const Text(
                    'wrong email? go back',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
                  ),
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
