import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/models/llm_message.dart';
import '../../../core/providers.dart';
import '../../../shared/result.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../menu/domain/action_engine.dart';
import '../../menu/domain/menu_models.dart';
import '../../vibe/providers/session_providers.dart';
import '../domain/ai_pick_model.dart';
import '../domain/pick_fallback.dart';
import '../domain/pick_prompt_builder.dart';
import '../providers/decide_providers.dart';

enum _Phase { fork, loading, pick, done }

class DecideScreen extends ConsumerStatefulWidget {
  const DecideScreen({super.key});

  @override
  ConsumerState<DecideScreen> createState() => _DecideScreenState();
}

class _DecideScreenState extends ConsumerState<DecideScreen> {
  _Phase _phase = _Phase.fork;
  AiPick? _currentPick;
  int _rerollCount = 0;
  bool _actionLoading = false;

  // Tracks picks rerolled this session for in-prompt anti-repetition.
  final List<String> _inSessionRejects = [];

  // ── Pick request ─────────────────────────────────────────────────────────────

  Future<void> _requestPick() async {
    setState(() => _phase = _Phase.loading);

    final session = ref.read(activeSessionProvider);
    if (session == null) {
      if (mounted) context.go('/vibe');
      return;
    }

    final city = ref.read(cityProvider);
    final now = DateTime.now();
    const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final dayOfWeek = days[now.weekday - 1];

    // Load history context (graceful — returns empty on error)
    final ctx = await ref.read(decideRepositoryProvider).loadContext();

    // Build prompt
    final prompt = PickPromptBuilder.build(
      vibe: session.vibe,
      hour: now.hour,
      dayOfWeek: dayOfWeek,
      city: city,
      rerollCount: _rerollCount,
      ctx: ctx,
      inSessionRejects: List.unmodifiable(_inSessionRejects),
    );

    // Call LLM; fall back silently on any failure (Scenario 5)
    AiPick pick;
    final result = await ref.read(llmProvider).generate(
          LlmRequest(system: prompt.system, prompt: prompt.userPrompt),
        );

    switch (result) {
      case Success(:final data):
        pick = _parseResponse(data, session.vibe, session.id);
      case Failure():
        pick = PickFallback.get(session.vibe, now.hour, session.id,
            rerollCount: _rerollCount);
    }

    // Persist to DB (fire-and-forget; error doesn't block the pick)
    final saved = await ref.read(decideRepositoryProvider).savePick(pick);

    if (!mounted) return;
    setState(() {
      _currentPick = saved;
      _phase = _Phase.pick;
    });
  }

  // ── Reroll (Scenario 1) ───────────────────────────────────────────────────────

  Future<void> _reroll() async {
    HapticFeedback.lightImpact();
    final current = _currentPick;
    if (current != null) {
      if (current.pickText.isNotEmpty) _inSessionRejects.add(current.pickText);
      unawaited(
          ref.read(decideRepositoryProvider).markRerolled(current.id));
    }
    setState(() => _rerollCount++);

    // At 3+ rerolls the escape hatch replaces the nah button — no new pick.
    if (_rerollCount >= 3) {
      setState(() => _phase = _Phase.pick);
      return;
    }

    await _requestPick();
  }

  // ── Do it ────────────────────────────────────────────────────────────────────

  Future<void> _doIt() async {
    final pick = _currentPick;
    if (pick == null || _actionLoading) return;

    unawaited(ref.read(decideRepositoryProvider).markAccepted(pick.id));

    // Solo picks — show warm confirmation before navigating to menu.
    if (pick.tag == 'solo') {
      if (mounted) setState(() => _phase = _Phase.done);
      return;
    }

    setState(() => _actionLoading = true);

    final session = ref.read(activeSessionProvider);
    final option =
        MenuOption(id: 'ai_${pick.id}', label: pick.pickText, tag: pick.tag);
    final result = await ActionEngine.execute(
      option: option,
      vibe: session?.vibe ?? 'fomo',
    );

    if (!mounted) return;
    setState(() => _actionLoading = false);

    if (result == ActionResult.dndInternal) {
      context.push('/dnd');
    } else {
      context.go('/menu');
    }
  }

  // ── LLM response parsing ─────────────────────────────────────────────────────

  AiPick _parseResponse(String raw, String vibe, String sessionId) {
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start == -1 || end <= start) throw const FormatException('no JSON');
      final map = jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;

      final pickText = (map['pick'] as String? ?? '').trim();
      final reasonText = (map['reason'] as String? ?? '').trim();
      final tag = _normalizeTag(map['tag'] as String? ?? 'solo');

      if (pickText.isEmpty || reasonText.isEmpty) {
        throw const FormatException('empty fields');
      }

      return AiPick(
        id: '',
        userId: '',
        sessionId: sessionId,
        vibe: vibe,
        pickText: pickText,
        reasonText: reasonText,
        tag: tag,
      );
    } catch (_) {
      return PickFallback.get(vibe, DateTime.now().hour, sessionId,
          rerollCount: _rerollCount);
    }
  }

  static String _normalizeTag(String raw) {
    const valid = {'discover', 'squad', 'order in', 'rest', 'content', 'solo'};
    final lower = raw.toLowerCase().trim();
    return valid.contains(lower) ? lower : 'solo';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/vibe');
      });
      return const Scaffold(backgroundColor: TromblColors.bg);
    }

    final accent = TromblColors.accentFor(session.vibe);

    return Scaffold(
      backgroundColor: TromblColors.bg,
      body: SafeArea(
        child: switch (_phase) {
          _Phase.fork => _Fork(
              vibe: session.vibe,
              accent: accent,
              onPickForMe: _requestPick,
              onBrowse: () => context.go('/menu'),
              onBack: () => context.go('/vibe'),
            ),
          _Phase.loading => _Loading(vibe: session.vibe),
          _Phase.done => _Done(
              pick: _currentPick!,
              vibe: session.vibe,
              accent: accent,
              onContinue: () => context.go('/menu'),
            ),
          _Phase.pick => _Pick(
              pick: _currentPick!,
              vibe: session.vibe,
              accent: accent,
              rerollCount: _rerollCount,
              actionLoading: _actionLoading,
              onDoIt: _doIt,
              onReroll: _reroll,
              onSwitchVibe: () => context.go('/vibe'),
              onBrowse: () => context.go('/menu'),
              onBack: () => setState(() {
                _phase = _Phase.fork;
                _rerollCount = 0;
                _currentPick = null;
                _inSessionRejects.clear();
              }),
            ),
        },
      ),
    );
  }
}

// ─── Done screen (solo pick confirmed) ───────────────────────────────────────

class _Done extends StatefulWidget {
  const _Done({
    required this.pick,
    required this.vibe,
    required this.accent,
    required this.onContinue,
  });
  final AiPick pick;
  final String vibe;
  final Color accent;
  final VoidCallback onContinue;

  @override
  State<_Done> createState() => _DoneState();
}

class _DoneState extends State<_Done> {
  @override
  void initState() {
    super.initState();
    // Auto-navigate to menu after 2.5 s so the user gets a moment to read.
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) widget.onContinue();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            widget.vibe == 'fomo' ? '🔥' : '🛌',
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 20),
          Text(
            widget.pick.pickText,
            style: const TextStyle(
              fontFamily: TromblText.serif,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: TromblColors.text,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'noted. go do it.',
            style: TextStyle(
              color: widget.accent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: TromblText.sans,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onContinue,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: TromblColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TromblColors.border),
              ),
              child: const Text(
                'open trombl →',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TromblColors.textSub,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
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

// ─── Fork screen ──────────────────────────────────────────────────────────────

class _Fork extends StatelessWidget {
  const _Fork({
    required this.vibe,
    required this.accent,
    required this.onPickForMe,
    required this.onBrowse,
    required this.onBack,
  });
  final String vibe;
  final Color accent;
  final VoidCallback onPickForMe;
  final VoidCallback onBrowse;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onBack,
            child: const Text('← back',
                style:
                    TextStyle(color: TromblColors.textMuted, fontSize: 13)),
          ),
          const Spacer(),
          Text(
            vibe == 'fomo'
                ? "ok, what's the\nmove?"
                : "what's calling\nto you?",
            style: const TextStyle(
              fontFamily: TromblText.serif,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: TromblColors.text,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "trom can pick for u, or u browse.",
            style:
                TextStyle(color: TromblColors.textSub, fontSize: 14),
          ),
          const Spacer(),

          // Primary — gradient pick for me
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              onPickForMe();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [TromblColors.fomo, TromblColors.jomo],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'just pick for me ✨',
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
          const SizedBox(height: 12),

          // Secondary — browse
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onBrowse();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: TromblColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TromblColors.border),
              ),
              child: const Text(
                'let me browse',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TromblColors.textSub,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
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

// ─── Loading screen ────────────────────────────────────────────────────────────

class _Loading extends StatefulWidget {
  const _Loading({required this.vibe});
  final String vibe;

  @override
  State<_Loading> createState() => _LoadingState();
}

class _LoadingState extends State<_Loading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Opacity(
            opacity: _anim.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'trom is deciding...',
                  style: TextStyle(
                    fontFamily: TromblText.serif,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: TromblColors.text,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.vibe == 'fomo' ? '⚡' : '🛌',
                  style: const TextStyle(fontSize: 28),
                ),
              ],
            ),
          ),
        ),
      );
}

// ─── Pick result screen ────────────────────────────────────────────────────────

class _Pick extends StatelessWidget {
  const _Pick({
    required this.pick,
    required this.vibe,
    required this.accent,
    required this.rerollCount,
    required this.actionLoading,
    required this.onDoIt,
    required this.onReroll,
    required this.onSwitchVibe,
    required this.onBrowse,
    required this.onBack,
  });
  final AiPick pick;
  final String vibe;
  final Color accent;
  final int rerollCount;
  final bool actionLoading;
  final VoidCallback onDoIt;
  final VoidCallback onReroll;
  final VoidCallback onSwitchVibe;
  final VoidCallback onBrowse;
  final VoidCallback onBack;

  String get _chipLabel {
    if (rerollCount == 0) return 'trom says';
    if (rerollCount == 1) return 'ok, try this';
    if (rerollCount == 2) return 'last pick —';
    return 'still here —';
  }

  String get _doItLabel => switch (pick.tag) {
        'squad' => 'trom, send it →',
        'order in' => 'trom, order →',
        'rest' => 'trom, lock in →',
        'discover' => 'trom, find it →',
        'content' => 'trom, post it →',
        _ => 'noted. go. →',
      };

  @override
  Widget build(BuildContext context) {
    final showEscape = rerollCount >= 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onBack,
            child: const Text('← back',
                style: TextStyle(
                    color: TromblColors.textMuted, fontSize: 13)),
          ),
          const Spacer(),

          // "trom says" chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Text(
              _chipLabel,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: TromblText.sans,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Pick headline
          Text(
            pick.pickText,
            style: const TextStyle(
              fontFamily: TromblText.serif,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: TromblColors.text,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),

          // Reason
          Text(
            pick.reasonText,
            style: const TextStyle(
              color: TromblColors.textSub,
              fontSize: 14,
              height: 1.45,
            ),
          ),

          const Spacer(),

          // Escape hatch — only at reroll >= 3 (Scenario 1)
          if (showEscape) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: TromblColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TromblColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "maybe it's not a $vibe night.",
                    style: const TextStyle(
                      color: TromblColors.textSub,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onSwitchVibe,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.28)),
                            ),
                            child: Text(
                              'switch vibe →',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                fontFamily: TromblText.sans,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: onBrowse,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: TromblColors.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: TromblColors.border),
                            ),
                            child: const Text(
                              'or just browse →',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: TromblColors.textSub,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                fontFamily: TromblText.sans,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // "Do it" — primary action
          GestureDetector(
            onTap: actionLoading ? null : onDoIt,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: actionLoading ? 0.5 : 1.0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 17),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.75)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  actionLoading ? 'one sec…' : _doItLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF090909),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    fontFamily: TromblText.sans,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // "nah" — reroll OR escape (Scenario 1 floor)
          if (!showEscape)
            GestureDetector(
              onTap: onReroll,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: TromblColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TromblColors.border),
                ),
                child: Text(
                  rerollCount >= 1 ? 'still nah' : 'nah, something else',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: TromblColors.textSub,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
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
