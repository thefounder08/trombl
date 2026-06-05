import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';
import '../../../core/observability/analytics_service.dart';
import '../../../shared/models/models.dart';
import '../../home/providers/home_providers.dart';
import '../../menu/domain/action_engine.dart';
import '../../menu/domain/menu_models.dart';
import '../../plan/presentation/create_plan_screen.dart';
import '../../vibe/providers/session_providers.dart';
import '../providers/reaction_provider.dart';

/// Passed via GoRouter's `extra` parameter.
class ResponseArgs {
  const ResponseArgs({
    required this.pick,
    required this.vibe,
    required this.optionLabel,
    required this.tag,
    this.tromMessage,
  });
  final Pick pick;
  final String vibe;
  final String optionLabel;
  final String tag;
  final String? tromMessage;
}

class ResponseScreen extends ConsumerStatefulWidget {
  const ResponseScreen({super.key, required this.args});
  final ResponseArgs args;

  @override
  ConsumerState<ResponseScreen> createState() => _ResponseScreenState();
}

class _ResponseScreenState extends ConsumerState<ResponseScreen> {
  bool _loading = false;
  bool _launched = false; // true after external app opens

  ResponseArgs get args => widget.args;

  static String _contextLine(String vibe) => vibe == 'fomo'
      ? '⚡ fomo pick · going for it'
      : '🛌 jomo pick · protecting ur energy';

  // Tag-based fallback first step (used when AI field is empty).
  static String _fallbackFirstStep(String tag) => switch (tag) {
        'squad'    => "open the group chat and send smth rn.",
        'discover' => "search it up right now. don't save it for later.",
        'order in' => "open the app and just browse. u don't have to decide yet.",
        'rest'     => "put ur phone face down. that's literally the whole move.",
        'content'  => "open the app first. don't draft — just open it.",
        'solo'     => "close this and go. u already know what to do.",
        _          => "one thing. right now. just start.",
      };


  Future<void> _textSquad() async {
    if (_loading) return;
    setState(() => _loading = true);
    HapticFeedback.heavyImpact();
    final option = MenuOption(
      id: args.pick.optionId,
      label: args.optionLabel,
      tag: args.tag,
    );
    final result = await ActionEngine.execute(
      option: option,
      vibe: args.vibe,
      tromMessage: args.tromMessage,
    );
    AnalyticsService.actionLaunched(tag: args.tag, result: result.name);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result == ActionResult.launched) {
      context.push('/create-plan',
          extra: CreatePlanArgs(
              vibe: args.vibe, optionLabel: args.optionLabel));
    } else {
      ref.invalidate(homeGreetingProvider);
      context.go('/home');
    }
  }

  Future<void> _onIt() async {
    if (_loading) return;
    HapticFeedback.heavyImpact();

    final def = ActionEngine.definitionFor(args.tag);
    if (args.tag != 'squad' && def != null) {
      setState(() => _loading = true);
      final option = MenuOption(
        id: args.pick.optionId,
        label: args.optionLabel,
        tag: args.tag,
      );
      final result = await ActionEngine.execute(
        option: option,
        vibe: args.vibe,
        tromMessage: args.tromMessage,
      );
      AnalyticsService.actionLaunched(tag: args.tag, result: result.name);
      if (!mounted) return;
      setState(() => _loading = false);
      switch (result) {
        case ActionResult.dndInternal:
          AnalyticsService.dndEntered();
          context.push('/dnd');
        case ActionResult.launched:
          // Stay on screen — user returns from external app and sees the
          // affirmation + "fr did it / nah" confirmation prompt.
          setState(() => _launched = true);
        case ActionResult.comingSoon:
        case ActionResult.failed:
          ref.invalidate(homeGreetingProvider);
          context.go('/home');
      }
    } else {
      ref.invalidate(homeGreetingProvider);
      context.go('/home');
    }
  }

  Future<void> _markDone(bool done) async {
    HapticFeedback.selectionClick();
    await ref
        .read(sessionRepositoryProvider)
        .setPickDone(args.pick.id, done);
    ref.invalidate(homeGreetingProvider);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final accent = TromblColors.accentFor(args.vibe);
    final cardTint = accent.withValues(alpha: 0.11);
    final reactionArgs = (vibe: args.vibe, optionLabel: args.optionLabel);
    final reaction = ref.watch(reactionProvider(reactionArgs));

    return Scaffold(
      backgroundColor: TromblColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
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

              // ── Scrollable — no fixed heights ───────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 26, 0, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vibe anchor
                        Text(
                          args.vibe == 'fomo' ? '⚡' : '🛌',
                          style: const TextStyle(fontSize: 36),
                        ),
                        const SizedBox(height: 10),

                        // Pick label — hero
                        Text(
                          args.optionLabel,
                          style: TextStyle(
                            fontFamily: TromblText.serif,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: accent,
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Context line
                        Text(
                          _contextLine(args.vibe),
                          style: TextStyle(
                            color: accent.withValues(alpha: 0.45),
                            fontSize: 12,
                            fontFamily: TromblText.sans,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── MISSING 1: "trom clocked it." personality moment ───
                        const Row(
                          children: [
                            Text('🔥',
                                style: TextStyle(fontSize: 13)),
                            SizedBox(width: 5),
                            Text(
                              'trom clocked it.',
                              style: TextStyle(
                                color: TromblColors.textMuted,
                                fontSize: 12,
                                fontFamily: TromblText.sans,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // ── MISSING 4+5: Tinted TROM'S TAKE card, bold text ───
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: cardTint,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: accent.withValues(alpha: 0.22)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 14, 16, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Label
                                    Text(
                                      "TROM'S TAKE",
                                      style: TextStyle(
                                        color: accent.withValues(alpha: 0.6),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                        fontFamily: TromblText.sans,
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Reaction — always shows (static fallback on AI failure)
                                    reaction.when(
                                      loading: () => const _TypingIndicator(),
                                      error: (_, __) => const Text(
                                        "here's something that'll do.",
                                        style: TextStyle(
                                          fontFamily: TromblText.serif,
                                          fontSize: 23,
                                          fontWeight: FontWeight.w700,
                                          color: TromblColors.textMuted,
                                          height: 1.4,
                                        ),
                                      ),
                                      data: (r) => Text(
                                        r.reaction.isNotEmpty ? r.reaction : '…',
                                        style: const TextStyle(
                                          fontFamily: TromblText.serif,
                                          fontSize: 23,
                                          fontWeight: FontWeight.w700,
                                          color: TromblColors.text,
                                          height: 1.4,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // DO THIS FIRST — left border accent, rule-based
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0, 14, 16, 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 3,
                                      margin: const EdgeInsets.only(left: 16, right: 12),
                                      constraints: const BoxConstraints(minHeight: 36),
                                      decoration: BoxDecoration(
                                        color: accent,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'DO THIS FIRST',
                                            style: TextStyle(
                                              color: accent.withValues(alpha: 0.6),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.2,
                                              fontFamily: TromblText.sans,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            _fallbackFirstStep(args.tag),
                                            style: const TextStyle(
                                              color: TromblColors.text,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: TromblText.sans,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── TROM CLOCKED THIS — from combined reactionProvider ──
                        reaction.maybeWhen(
                          data: (r) {
                            if (r.clocked.isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                                decoration: BoxDecoration(
                                  color: TromblColors.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: accent.withValues(alpha: 0.1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TROM CLOCKED THIS',
                                      style: TextStyle(
                                        color: TromblColors.textMuted,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        fontFamily: TromblText.sans,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      r.clocked,
                                      style: const TextStyle(
                                        color: TromblColors.textSub,
                                        fontSize: 14,
                                        fontFamily: TromblText.sans,
                                        height: 1.45,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),

                        // ── MISSING 3: Squad draft block ──────────────────────
                        if (args.tag == 'squad' &&
                            args.tromMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.fromLTRB(16, 14, 16, 16),
                            decoration: BoxDecoration(
                              color: TromblColors.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xFF25D366)
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "TROM'S DRAFT FOR UR SQUAD",
                                  style: TextStyle(
                                    color: Color(0xFF25D366),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    fontFamily: TromblText.sans,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '"${args.tromMessage}"',
                                  style: const TextStyle(
                                    color: TromblColors.text,
                                    fontSize: 14,
                                    fontFamily: TromblText.sans,
                                    height: 1.45,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                GestureDetector(
                                  onTap: _textSquad,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _loading
                                          ? 'opening…'
                                          : 'text ur squad →',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF0B0B0D),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        fontFamily: TromblText.sans,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ── Pinned CTAs — clear hierarchy ──────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _launched ? _LaunchedCtas(
                  accent: accent,
                  tag: args.tag,
                  onDone: _markDone,
                ) : Column(
                  children: [
                    // PRIMARY — "i'm on it →"
                    GestureDetector(
                      onTap: _onIt,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _loading ? 0.6 : 1.0,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent,
                                accent.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _loading ? 'on it…' : "i'm on it →",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF090909),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              fontFamily: TromblText.sans,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // SECONDARY — pick smth else
                    GestureDetector(
                      onTap: () => context.go('/menu'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: TromblColors.border),
                        ),
                        child: const Text(
                          'pick smth else',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: TromblColors.textSub,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            fontFamily: TromblText.sans,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
          'trom is thinking…',
          style: TextStyle(
            fontFamily: TromblText.serif,
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: TromblColors.textMuted,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

// ─── Post-launch CTAs ─────────────────────────────────────────────────────────
// Shown after user is sent to external app via "i'm on it →". When they return
// to trombl, they see an affirmation + "fr did it / nah" to mark completion.

class _LaunchedCtas extends StatelessWidget {
  const _LaunchedCtas({
    required this.accent,
    required this.tag,
    required this.onDone,
  });
  final Color accent;
  final String tag;
  final void Function(bool done) onDone;

  static String _header(String tag) => switch (tag) {
        'squad'    => "text sent. 🔥",
        'discover' => "going out? 🔥",
        'order in' => "on its way. 🔥",
        'rest'     => "resting now. 🛌",
        'content'  => "just posted. 🔥",
        _          => "you're on it. 🔥",
      };

  static String _motivation(String tag) => switch (tag) {
        'squad'    => "u reached out. that's fomo in action.",
        'discover' => "u chose to go out. that's always worth it.",
        'order in' => "treating urself is not optional.",
        'rest'     => "ur body asked for this and u listened.",
        'content'  => "being present beats being perfect.",
        'solo'     => "u chose the solo vibe. giving self-sufficient energy.",
        _          => "u committed to something. that's already the win.",
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Affirmation card
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _header(tag),
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFamily: TromblText.sans,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _motivation(tag),
                style: const TextStyle(
                  color: TromblColors.textSub,
                  fontSize: 13,
                  fontFamily: TromblText.sans,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // "fr did it" — primary
        GestureDetector(
          onTap: () => onDone(true),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.8)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'fr did it ✓',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF090909),
                fontWeight: FontWeight.w800,
                fontSize: 16,
                fontFamily: TromblText.sans,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // "nah" — ghost
        GestureDetector(
          onTap: () => onDone(false),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TromblColors.border),
            ),
            child: const Text(
              "nah didn't happen",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: TromblColors.textSub,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontFamily: TromblText.sans,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
