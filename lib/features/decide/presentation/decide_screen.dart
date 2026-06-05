import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/models/llm_message.dart';
import '../../../core/providers.dart';
import '../../../core/services/weather_service.dart';
import '../../../shared/result.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../menu/domain/action_engine.dart';
import '../../menu/domain/menu_models.dart';
import '../../vibe/providers/session_providers.dart';
import '../domain/ai_pick_model.dart';
import '../domain/pick_fallback.dart';
import '../domain/pick_prompt_builder.dart';
import '../providers/decide_providers.dart';

// Level 4 is a new phase — trom stops guessing and asks ONE question.
enum _Phase { fork, loading, pick, ask, done }

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

  final List<String> _inSessionRejects = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shouldStart = ref.read(decideShouldAutoStartProvider);
      if (shouldStart) {
        ref.read(decideShouldAutoStartProvider.notifier).state = false;
        _requestPick();
      }
    });
  }

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

    // Consume mood text — set by home, vibe chips, or Level 4 trom-asks.
    final mood = ref.read(moodInputProvider);
    if (mood != null) ref.read(moodInputProvider.notifier).state = null;

    final contextFuture = ref.read(decideRepositoryProvider).loadContext();
    final weatherFuture = WeatherService.getCondition(city);
    final ctx = await contextFuture;
    final weather = await weatherFuture;

    final prompt = PickPromptBuilder.build(
      vibe: session.vibe,
      hour: now.hour,
      dayOfWeek: dayOfWeek,
      city: city,
      rerollCount: _rerollCount,
      ctx: ctx,
      inSessionRejects: List.unmodifiable(_inSessionRejects),
      moodText: mood,
      weatherCondition: weather,
    );

    AiPick pick;
    final start = DateTime.now();
    final result = await ref.read(llmProvider).generate(
          LlmRequest(system: prompt.system, prompt: prompt.userPrompt),
        );
    final ms = DateTime.now().difference(start).inMilliseconds;
    final usage = ref.read(aiUsageServiceProvider);

    switch (result) {
      case Success(:final data):
        pick = _parseResponse(data, session.vibe, session.id);
        usage.log(
          endpoint: 'decide',
          cacheHit: false,
          fallbackLayer: 1,
          promptChars: prompt.system.length + prompt.userPrompt.length,
          responseChars: data.length,
          durationMs: ms,
        );
      case Failure():
        pick = PickFallback.get(session.vibe, now.hour, session.id,
            rerollCount: _rerollCount);
        usage.log(
            endpoint: 'decide', cacheHit: false, fallbackLayer: 3, durationMs: ms);
    }

    pick = pick.copyWith(
      moodText: mood,
      pickHour: now.hour,
      pickDay: dayOfWeek,
      weatherCondition: weather,
    );

    final saved = await ref.read(decideRepositoryProvider).savePick(pick);

    if (!mounted) return;
    setState(() {
      _currentPick = saved;
      _phase = _Phase.pick;
    });
  }

  // ── Reroll (Level 2→3 fallback; Level 4 fires at 3+) ─────────────────────────

  Future<void> _reroll() async {
    HapticFeedback.lightImpact();
    final current = _currentPick;
    if (current != null) {
      if (current.pickText.isNotEmpty) _inSessionRejects.add(current.pickText);
      unawaited(ref.read(decideRepositoryProvider).markRerolled(current.id));
    }
    setState(() => _rerollCount++);

    // Level 4: after 3 rerolls trom stops guessing and asks ONE question.
    if (_rerollCount >= 3) {
      setState(() => _phase = _Phase.ask);
      return;
    }

    await _requestPick();
  }

  // ── Level 4: re-anchor with mood from trom-asks ───────────────────────────────

  Future<void> _requestWithMood(String mood) async {
    ref.read(moodInputProvider.notifier).state = mood;
    // Reset counters so the new anchored pick feels fresh.
    setState(() {
      _rerollCount = 0;
      _inSessionRejects.clear();
    });
    await _requestPick();
  }

  // ── Level 3: user tapped an alternative from the explore sheet ────────────────

  Future<void> _selectAlternative(AiPick pick) async {
    setState(() => _phase = _Phase.loading);
    final saved = await ref.read(decideRepositoryProvider).savePick(pick);
    if (!mounted) return;
    setState(() {
      _currentPick = saved;
      _rerollCount = 0;
      _inSessionRejects.clear();
      _phase = _Phase.pick;
    });
  }

  // ── Do it ────────────────────────────────────────────────────────────────────

  Future<void> _doIt() async {
    final pick = _currentPick;
    if (pick == null || _actionLoading) return;

    unawaited(ref.read(decideRepositoryProvider).markAccepted(pick.id));

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
      context.go('/home');
    }
  }

  // ── LLM response parsing ─────────────────────────────────────────────────────

  AiPick _parseResponse(String raw, String vibe, String sessionId) {
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start == -1 || end <= start) throw const FormatException('no JSON');
      final map =
          jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;

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
              onBack: () => context.go('/home'),
            ),
          _Phase.loading => _Loading(vibe: session.vibe),
          _Phase.done => _Done(
              pick: _currentPick!,
              vibe: session.vibe,
              accent: accent,
              onContinue: () => context.go('/home'),
            ),
          _Phase.ask => _Ask(
              vibe: session.vibe,
              accent: accent,
              onAnswer: _requestWithMood,
              onBack: () => setState(() => _phase = _Phase.pick),
            ),
          _Phase.pick => _Pick(
              pick: _currentPick!,
              vibe: session.vibe,
              accent: accent,
              rerollCount: _rerollCount,
              actionLoading: _actionLoading,
              onDoIt: _doIt,
              onReroll: _reroll,
              onExplore: () {
                final s = ref.read(activeSessionProvider);
                final router = GoRouter.of(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => _AlternativesSheet(
                    vibe: s?.vibe ?? 'fomo',
                    hour: DateTime.now().hour,
                    sessionId: s?.id,
                    currentPickText: _currentPick?.pickText ?? '',
                    accent: accent,
                    onSelect: (pick) {
                      Navigator.of(context).pop();
                      _selectAlternative(pick);
                    },
                    onBrowse: () {
                      Navigator.of(context).pop();
                      router.go('/menu');
                    },
                  ),
                );
              },
              onSwitchVibe: () => context.go('/vibe'),
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

// ─── Done screen ──────────────────────────────────────────────────────────────

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
                'back to trombl →',
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
                style: TextStyle(color: TromblColors.textMuted, fontSize: 13)),
          ),
          const Spacer(),
          Text(
            vibe == 'fomo'
                ? "ok, what's the\nmove?"
                : "what's calling\nto u?",
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
            style: TextStyle(color: TromblColors.textSub, fontSize: 14),
          ),
          const Spacer(),
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
                'lemme browse',
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
    required this.onExplore,
    required this.onSwitchVibe,
    required this.onBack,
  });
  final AiPick pick;
  final String vibe;
  final Color accent;
  final int rerollCount;
  final bool actionLoading;
  final VoidCallback onDoIt;
  final VoidCallback onReroll;
  // Level 3: opens the alternatives sheet.
  final VoidCallback onExplore;
  final VoidCallback onSwitchVibe;
  final VoidCallback onBack;

  String get _chipLabel {
    if (rerollCount == 0) return 'trom says';
    if (rerollCount == 1) return 'ok, try this';
    return 'last try before trom asks —';
  }

  String get _doItLabel => switch (pick.tag) {
        'squad'    => 'trom, send it →',
        'order in' => 'trom, order →',
        'rest'     => 'trom, lock in →',
        'discover' => 'trom, find it →',
        'content'  => 'trom, post it →',
        _          => 'noted. go. →',
      };

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
                style: TextStyle(color: TromblColors.textMuted, fontSize: 13)),
          ),
          const Spacer(),

          // "trom says" chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

          // Primary CTA
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

          // Nah / reroll — always visible; 3rd tap triggers Level 4 ask.
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
          const SizedBox(height: 10),

          // Level 3: see other options — secondary, never primary.
          GestureDetector(
            onTap: onExplore,
            child: const SizedBox(
              width: double.infinity,
              child: Text(
                'show me more →',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TromblColors.textMuted,
                  fontSize: 12,
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

// ─── Level 3: alternatives sheet ─────────────────────────────────────────────

class _AlternativesSheet extends StatelessWidget {
  const _AlternativesSheet({
    required this.vibe,
    required this.hour,
    required this.sessionId,
    required this.currentPickText,
    required this.accent,
    required this.onSelect,
    required this.onBrowse,
  });
  final String vibe;
  final int hour;
  final String? sessionId;
  final String currentPickText;
  final Color accent;
  final void Function(AiPick) onSelect;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    // Generate fallback options, skipping the one already shown.
    final options = <AiPick>[];
    for (int i = 0; options.length < 4 && i < 20; i++) {
      final p = PickFallback.get(vibe, hour, sessionId, rerollCount: i);
      if (p.pickText != currentPickText &&
          !options.any((o) => o.pickText == p.pickText)) {
        options.add(p);
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: TromblColors.cardLit,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        22, 14, 22,
        MediaQuery.of(context).padding.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: TromblColors.borderMid,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'other picks',
            style: TextStyle(
              fontFamily: TromblText.serif,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'tap one. go.',
            style: TextStyle(
              color: TromblColors.textMuted,
              fontSize: 12,
              fontFamily: TromblText.sans,
            ),
          ),
          const SizedBox(height: 16),
          ...options.map((p) => GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onSelect(p);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: TromblColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: accent.withValues(alpha: 0.14)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.pickText,
                              style: const TextStyle(
                                color: TromblColors.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: TromblText.sans,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.reasonText,
                              style: const TextStyle(
                                color: TromblColors.textSub,
                                fontSize: 12,
                                fontFamily: TromblText.sans,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 11,
                        color: accent.withValues(alpha: 0.45),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onBrowse();
            },
            child: const SizedBox(
              width: double.infinity,
              child: Text(
                'or just browse →',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TromblColors.textMuted,
                  fontSize: 12,
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

// ─── Level 4: trom asks ONE question ─────────────────────────────────────────

class _Ask extends StatefulWidget {
  const _Ask({
    required this.vibe,
    required this.accent,
    required this.onAnswer,
    required this.onBack,
  });
  final String vibe;
  final Color accent;
  final void Function(String mood) onAnswer;
  final VoidCallback onBack;

  @override
  State<_Ask> createState() => _AskState();
}

class _AskState extends State<_Ask> {
  String? _selected;
  final _ctrl = TextEditingController();
  bool _showInput = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Time-aware chips — calibrated so the answer re-anchors the pick correctly.
  List<String> get _chips {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 5) {
      return ["can't sleep", 'restless', 'want something quiet', 'just winding down'];
    }
    if (hour >= 5 && hour < 12) {
      return ['low energy', 'hungry', 'need to move', 'want quiet time'];
    }
    if (hour >= 12 && hour < 17) {
      return ['bored', 'hungry', 'need a break', 'want to go out'];
    }
    if (hour >= 17 && hour < 22) {
      return ['social', 'hungry', 'tired but restless', 'need to chill'];
    }
    return ['restless', 'want something calm', 'need company', 'just scrolling'];
  }

  bool get _canSubmit =>
      _selected != null || (_showInput && _ctrl.text.trim().isNotEmpty);

  void _submit() {
    if (!_canSubmit) return;
    final answer =
        _showInput ? _ctrl.text.trim() : _selected!;
    HapticFeedback.mediumImpact();
    widget.onAnswer(answer);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 14, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onBack,
            child: const Text('← back',
                style:
                    TextStyle(color: TromblColors.textMuted, fontSize: 13)),
          ),
          const Spacer(),

          const Text(
            "ok i'm clearly missing it.\nwhat's actually going on?",
            style: TextStyle(
              fontFamily: TromblText.serif,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: TromblColors.text,
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'pick one. trom handles the rest.',
            style: TextStyle(
              color: TromblColors.textSub,
              fontSize: 13,
              fontFamily: TromblText.sans,
            ),
          ),
          const SizedBox(height: 28),

          // Tappable chips
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              ..._chips.map((chip) => GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selected = chip;
                        _showInput = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _selected == chip
                            ? accent.withValues(alpha: 0.14)
                            : TromblColors.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _selected == chip
                              ? accent.withValues(alpha: 0.45)
                              : TromblColors.border,
                          width: _selected == chip ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        chip,
                        style: TextStyle(
                          color: _selected == chip
                              ? accent
                              : TromblColors.textSub,
                          fontSize: 13,
                          fontWeight: _selected == chip
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontFamily: TromblText.sans,
                        ),
                      ),
                    ),
                  )),
              // "type it" chip
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showInput = true;
                    _selected = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _showInput
                        ? accent.withValues(alpha: 0.08)
                        : TromblColors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _showInput
                          ? accent.withValues(alpha: 0.3)
                          : TromblColors.border,
                    ),
                  ),
                  child: Text(
                    'type it →',
                    style: TextStyle(
                      color:
                          _showInput ? accent : TromblColors.textMuted,
                      fontSize: 13,
                      fontFamily: TromblText.sans,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_showInput) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: const TextStyle(
                  color: TromblColors.text,
                  fontSize: 14,
                  fontFamily: TromblText.sans),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'working but restless, hungry, anxious...',
                hintStyle: const TextStyle(
                    color: TromblColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: TromblColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ],

          const Spacer(),

          // Submit — enabled only once something is picked/typed.
          GestureDetector(
            onTap: _canSubmit ? _submit : null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _canSubmit ? 1.0 : 0.35,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 17),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [TromblColors.fomo, TromblColors.jomo],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'trom, figure it out →',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF090909),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    fontFamily: TromblText.sans,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
