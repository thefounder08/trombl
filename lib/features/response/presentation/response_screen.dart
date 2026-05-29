import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/trombl_theme.dart';
import '../../../shared/models/models.dart';
import '../../menu/data/categories.dart';
import '../providers/reaction_provider.dart';

class ResponseArgs {
  const ResponseArgs({
    required this.pick,
    required this.vibe,
    required this.optionLabel,
    required this.action,
    this.actionData,
  });
  final Pick pick;
  final String vibe;
  final String optionLabel;
  final ActionType action;
  final String? actionData;
}

class ResponseScreen extends ConsumerWidget {
  const ResponseScreen({super.key, required this.args});
  final ResponseArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = TromblColors.accentFor(args.vibe);
    final reaction = ref.watch(reactionProvider(
      (vibe: args.vibe, optionLabel: args.optionLabel),
    ));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              // Back
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.go('/menu');
                },
                child: const Text(
                  '← back',
                  style: TextStyle(
                    color: TromblColors.textMuted,
                    fontSize: 13,
                    fontFamily: TromblText.sans,
                  ),
                ),
              ),
              // Scrollable reaction area
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Option label as accent tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: accent.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            args.optionLabel,
                            style: TextStyle(
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              fontFamily: TromblText.sans,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Reaction text
                        reaction.when(
                          loading: () => const _TypingIndicator(),
                          error: (_, __) => GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref.invalidate(reactionProvider((
                                vibe: args.vibe,
                                optionLabel: args.optionLabel,
                              )));
                            },
                            child: const Text(
                              "trom went quiet.\ntap to try again.",
                              style: TextStyle(
                                fontFamily: TromblText.serif,
                                fontSize: 28,
                                color: TromblColors.textMuted,
                                height: 1.25,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          data: (text) => Text(
                            text,
                            style: const TextStyle(
                              fontFamily: TromblText.serif,
                              fontSize: 28,
                              color: TromblColors.text,
                              height: 1.25,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Pinned bottom CTA area ──────────────────────────────────
              Column(
                children: [
                  // Action button (discover/squad/order-in/rest/content)
                  if (args.action != ActionType.none &&
                      args.action != ActionType.comingSoon) ...[
                    _ActionButton(
                      action: args.action,
                      actionData: args.actionData,
                      vibe: args.vibe,
                      optionLabel: args.optionLabel,
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Share reaction
                  reaction.maybeWhen(
                    data: (text) => _SecondaryButton(
                      label: 'share this 🔗',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Share.share(
                          '${args.optionLabel}\n\n$text\n\n— trombl',
                          subject: args.optionLabel,
                        );
                      },
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 10),

                  // Pick something else
                  _SecondaryButton(
                    label: 'pick something else',
                    onTap: () => context.go('/menu'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Typing indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: const Text(
          'trom is thinking...',
          style: TextStyle(
            fontFamily: TromblText.serif,
            fontSize: 28,
            color: TromblColors.textMuted,
            height: 1.25,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }
}

// ─── Action button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.vibe,
    required this.optionLabel,
    this.actionData,
  });
  final ActionType action;
  final String vibe;
  final String optionLabel;
  final String? actionData;

  @override
  Widget build(BuildContext context) {
    final (icon, label, gradient) = _resolve();
    return GestureDetector(
      onTap: () => _launch(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF090909),
                fontWeight: FontWeight.w800,
                fontSize: 15,
                fontFamily: TromblText.sans,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, String, LinearGradient) _resolve() => switch (action) {
    ActionType.discover => (
      '🎟️',
      'find something near u →',
      const LinearGradient(colors: [TromblColors.fomo, Color(0xFFFFD700)]),
    ),
    ActionType.squad => (
      '💬',
      'text ur squad →',
      const LinearGradient(colors: [Color(0xFF25D366), Color(0xFF128C7E)]),
    ),
    ActionType.orderIn => (
      '🍕',
      'order comfort food →',
      const LinearGradient(colors: [Color(0xFFE23744), Color(0xFFFF6B6B)]),
    ),
    ActionType.rest => (
      '🛌',
      'protect ur peace →',
      const LinearGradient(colors: [TromblColors.jomo, Color(0xFFB0A0FF)]),
    ),
    ActionType.content => (
      '📸',
      'post something →',
      const LinearGradient(colors: [Color(0xFFE1306C), Color(0xFFF77737)]),
    ),
    _ => ('', '', const LinearGradient(colors: [TromblColors.fomo, TromblColors.jomo])),
  };

  Future<void> _launch(BuildContext context) async {
    switch (action) {
      case ActionType.discover:
        final query = Uri.encodeComponent(
          optionLabel.toLowerCase().contains('music') || optionLabel.toLowerCase().contains('gig')
              ? 'live music tonight'
              : optionLabel.toLowerCase().contains('comedy')
                  ? 'comedy show tonight'
                  : optionLabel.toLowerCase().contains('gym') || optionLabel.toLowerCase().contains('fitness')
                      ? 'fitness classes nearby'
                      : 'events tonight near me',
        );
        await _tryLaunch('https://in.bookmyshow.com/explore/events?q=$query');

      case ActionType.squad:
        final msg = actionData ?? Categories.squadMessage(vibe);
        await _tryLaunch(
          'whatsapp://send?text=${Uri.encodeComponent(msg)}',
          fallback: 'https://api.whatsapp.com/send?text=${Uri.encodeComponent(msg)}',
        );

      case ActionType.orderIn:
        final cuisine = Uri.encodeComponent(
          optionLabel.toLowerCase().contains('snack') ? 'snacks' :
          optionLabel.toLowerCase().contains('coffee') ? 'coffee' :
          optionLabel.toLowerCase().contains('dessert') ? 'dessert' :
          'comfort food',
        );
        await _tryLaunch('zomato://search?q=$cuisine',
            fallback: 'https://www.zomato.com/search?q=$cuisine');

      case ActionType.rest:
        // DND — show sound settings (can't programmatically enable DND on Android)
        await _tryLaunch('android.settings.SOUND_SETTINGS');

      case ActionType.content:
        await _tryLaunch('instagram://camera', fallback: 'https://www.instagram.com/');

      case ActionType.comingSoon:
      case ActionType.none:
        break;
    }
  }

  Future<void> _tryLaunch(String uri, {String? fallback}) async {
    final parsed = Uri.parse(uri);
    try {
      if (await canLaunchUrl(parsed)) {
        await launchUrl(parsed, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    if (fallback != null) {
      try {
        await launchUrl(Uri.parse(fallback), mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }
}

// ─── Secondary button ─────────────────────────────────────────────────────────

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: TromblColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TromblColors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: TromblColors.textSub,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            fontFamily: TromblText.sans,
          ),
        ),
      ),
    );
  }
}
