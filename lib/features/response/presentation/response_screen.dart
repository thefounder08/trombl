import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../../shared/models/models.dart';
import '../../chat/presentation/chat_args.dart';
import '../../home/providers/home_providers.dart';
import '../../menu/domain/action_engine.dart';
import '../../menu/domain/menu_models.dart';
import '../../menu/presentation/action_launcher.dart';
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
  bool _launched = false;

  // Secondary button shown after a DualUrlAction's primary URL is launched.
  String? _secondaryLabel;
  String? _secondaryUrl;

  // Memory-query state.
  bool _showMemoryPrompt = false;
  MemoryQueryAction? _pendingMemoryAction;
  final _memoryController = TextEditingController();

  ResponseArgs get args => widget.args;

  // Pre-compute action once so MultiButtonAction buttons render on first build.
  late final ActionResult _preAction = ActionEngine.resolve(
    option: MenuOption(id: args.pick.optionId, label: args.optionLabel, tag: args.tag),
    vibe: args.vibe,
    tromMessage: args.tromMessage,
  );

  @override
  void dispose() {
    _memoryController.dispose();
    super.dispose();
  }

  static String _contextLine(String vibe) => vibe == 'fomo'
      ? '⚡ fomo pick · going for it'
      : '🛌 jomo pick · protecting ur energy';

  static String _fallbackFirstStep(String tag) => switch (tag) {
        'squad'    => "open the group chat and send smth rn.",
        'discover' => "search it up right now. don't save it for later.",
        'order in' => "open the app and just browse. u don't have to decide yet.",
        'rest'     => "put ur phone face down. that's literally the whole move.",
        'content'  => "open the app first. don't draft — just open it.",
        'solo'     => "close this and go. u already know what to do.",
        _          => "one thing. right now. just start.",
      };

  // ── WhatsApp draft button (squad options with tromMessage) ─────────────────

  Future<void> _textSquad() async {
    if (_loading) return;
    setState(() => _loading = true);
    HapticFeedback.heavyImpact();
    final option = MenuOption(
      id: args.pick.optionId,
      label: args.optionLabel,
      tag: args.tag,
    );
    final result = ActionEngine.resolve(
      option: option,
      vibe: args.vibe,
      tromMessage: args.tromMessage,
    );
    ref.read(analyticsRepositoryProvider).trackActionLaunched(tag: args.tag, result: result.name);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result case ExternalUrlAction(:final url, :final fallbackUrl)) {
      final ok = await ActionLauncher.launchExternal(
        url,
        fallbackUrl: fallbackUrl,
        context: context,
      );
      if (!mounted) return;
      if (ok) setState(() => _launched = true);
    } else if (result case DualUrlAction(
      primaryUrl: final url,
      primaryFallbackUrl: final fallback,
      secondaryLabel: final sLabel,
      secondaryUrl: final sUrl,
    )) {
      setState(() { _secondaryLabel = sLabel; _secondaryUrl = sUrl; });
      final ok = await ActionLauncher.launchExternal(
        url,
        fallbackUrl: fallback,
        context: context,
      );
      if (!mounted) return;
      if (ok) setState(() => _launched = true);
    }
  }

  // ── Primary CTA handler ────────────────────────────────────────────────────

  Future<void> _onIt() async {
    if (_loading) return;
    HapticFeedback.heavyImpact();

    final def = ActionEngine.definitionFor(args.tag);

    // Squad with a visible draft block → "i'm on it →" returns home.
    // The "text ur squad →" button inside the draft block is the primary CTA.
    if (args.tag == 'squad' && args.tromMessage != null) {
      ref.invalidate(homeGreetingProvider);
      context.go('/home');
      return;
    }

    if (def == null) {
      ref.invalidate(homeGreetingProvider);
      context.go('/home');
      return;
    }

    setState(() => _loading = true);
    final option = MenuOption(
      id: args.pick.optionId,
      label: args.optionLabel,
      tag: args.tag,
    );
    final result = ActionEngine.resolve(
      option: option,
      vibe: args.vibe,
      city: ref.read(cityProvider),
      tromMessage: args.tromMessage,
    );
    ref.read(analyticsRepositoryProvider).trackActionLaunched(tag: args.tag, result: result.name);
    if (!mounted) return;

    switch (result) {
      case InternalRouteAction(:final route):
        setState(() => _loading = false);
        if (route == '/dnd') {
          ref.read(analyticsRepositoryProvider).trackDndEntered();
          context.go(route);
        } else {
          context.push(route);
        }

      case ExternalUrlAction(:final url, :final fallbackUrl):
        final ok = await ActionLauncher.launchExternal(
          url, fallbackUrl: fallbackUrl, context: context,
        );
        if (!mounted) return;
        setState(() { _loading = false; if (ok) _launched = true; });

      case DualUrlAction(
          primaryUrl: final url,
          primaryFallbackUrl: final fallback,
          secondaryLabel: final sLabel,
          secondaryUrl: final sUrl,
        ):
        final ok = await ActionLauncher.launchExternal(
          url, fallbackUrl: fallback, context: context,
        );
        if (!mounted) return;
        setState(() {
          _loading = false;
          if (ok) {
            _launched = true;
            _secondaryLabel = sLabel;
            _secondaryUrl = sUrl;
          }
        });

      case MultiButtonAction():
        // Rendered as buttons in build — should not reach _onIt.
        setState(() => _loading = false);

      case MemoryQueryAction():
        await _handleMemoryAction(result);

      case ChatSeedAction(:final seedText):
        setState(() => _loading = false);
        context.push('/chat', extra: ChatArgs(seedText: seedText));

      case ComingSoonAction():
        setState(() => _loading = false);
        ActionLauncher.showComingSoon(context);

      case FailedAction(:final message):
        setState(() => _loading = false);
        ActionLauncher.showFailed(context, message);
    }
  }

  // ── Memory query helpers ───────────────────────────────────────────────────

  Future<void> _handleMemoryAction(MemoryQueryAction action) async {
    final repo = ref.read(sessionRepositoryProvider);
    final saved = await repo.readPreference(action.memoryKey);
    if (!mounted) return;

    if (saved != null && saved.isNotEmpty) {
      final url = action.urlTemplate.replaceAll(
        '{value}', Uri.encodeComponent(saved),
      );
      final ok = await ActionLauncher.launchExternal(url, context: context);
      if (!mounted) return;
      setState(() { _loading = false; if (ok) _launched = true; });
    } else {
      setState(() {
        _loading = false;
        _showMemoryPrompt = true;
        _pendingMemoryAction = action;
      });
    }
  }

  Future<void> _submitMemoryPrompt() async {
    final value = _memoryController.text.trim();
    if (value.isEmpty || _pendingMemoryAction == null) return;
    setState(() => _loading = true);

    await ref.read(sessionRepositoryProvider).saveMemoryNode(
      type: 'preference',
      content: '${_pendingMemoryAction!.memoryKey}: $value',
    );

    final url = _pendingMemoryAction!.urlTemplate.replaceAll(
      '{value}', Uri.encodeComponent(value),
    );
    if (!mounted) return;
    setState(() { _showMemoryPrompt = false; _pendingMemoryAction = null; });

    final ok = await ActionLauncher.launchExternal(url, context: context);
    if (!mounted) return;
    setState(() { _loading = false; if (ok) _launched = true; });
  }

  // ── Multi-button tap handler ───────────────────────────────────────────────

  Future<void> _onMultiButtonTap(String url) async {
    if (_loading) return;
    setState(() => _loading = true);
    HapticFeedback.heavyImpact();
    final ok = await ActionLauncher.launchExternal(url, context: context);
    if (!mounted) return;
    setState(() { _loading = false; if (ok) _launched = true; });
  }

  // ── Secondary URL tap (after DualUrlAction primary launch) ────────────────

  Future<void> _onSecondaryTap(String url) async {
    await ActionLauncher.launchExternal(url, context: context);
  }

  // ── Done / not done ───────────────────────────────────────────────────────

  Future<void> _markDone(bool done) async {
    HapticFeedback.selectionClick();
    await ref.read(sessionRepositoryProvider).setPickDone(args.pick.id, done);
    ref.invalidate(homeGreetingProvider);
    if (mounted) context.go('/home');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = TromblColors.accentFor(args.vibe);
    final cardTint = accent.withValues(alpha: 0.11);
    final reactionArgs = (vibe: args.vibe, optionLabel: args.optionLabel);
    ref.listen(reactionProvider(reactionArgs), (previous, next) {
      if (next.hasValue && !(previous?.hasValue ?? false)) {
        ref.read(analyticsRepositoryProvider)
            .trackReactionLoaded(vibe: args.vibe, tag: args.tag);
      }
    });
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
                  context.go('/home');
                },
                child: const Text(
                  '← back',
                  style: TextStyle(
                    color: TromblColors.textSub,
                    fontSize: 13,
                    fontFamily: TromblText.sans,
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 26, 0, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          args.vibe == 'fomo' ? '⚡' : '🛌',
                          style: const TextStyle(fontSize: 36),
                        ),
                        const SizedBox(height: 10),
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

                        const Row(
                          children: [
                            Text('🔥', style: TextStyle(fontSize: 13)),
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

                        // TROM'S TAKE card
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
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                    reaction.when(
                                      loading: () => const _TypingIndicator(),
                                      error: (_, _) => const Text(
                                        "here's something that'll do.",
                                        style: TextStyle(
                                          fontFamily: TromblText.sans,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: TromblColors.textMuted,
                                          height: 1.45,
                                        ),
                                      ),
                                      data: (r) => Text(
                                        r.reaction.isNotEmpty ? r.reaction : '…',
                                        style: const TextStyle(
                                          fontFamily: TromblText.sans,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: TromblColors.text,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

                        // TROM CLOCKED THIS
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
                                        fontSize: 12,
                                        fontFamily: TromblText.sans,
                                        height: 1.4,
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

                        // Squad draft block
                        if (args.tag == 'squad' &&
                            args.tromMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _loading ? 'opening…' : 'text ur squad →',
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

              // ── Pinned CTAs ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildCtas(accent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCtas(Color accent) {
    // Memory prompt replaces all CTAs.
    if (_showMemoryPrompt && _pendingMemoryAction != null) {
      return _MemoryPromptCta(
        promptText: _pendingMemoryAction!.promptText,
        controller: _memoryController,
        onSubmit: _submitMemoryPrompt,
        onCancel: () => setState(() {
          _showMemoryPrompt = false;
          _pendingMemoryAction = null;
        }),
        accent: accent,
        loading: _loading,
      );
    }

    // Post-launch CTAs (after any external app opened).
    if (_launched) {
      return _LaunchedCtas(
        accent: accent,
        tag: args.tag,
        onDone: _markDone,
        secondaryLabel: _secondaryLabel,
        onSecondary: _secondaryUrl != null
            ? () => _onSecondaryTap(_secondaryUrl!)
            : null,
      );
    }

    // MultiButtonAction — show buttons in place of "i'm on it →".
    if (_preAction case final MultiButtonAction multi) {
      return _MultiButtonCta(
        action: multi,
        accent: accent,
        loading: _loading,
        onTap: _onMultiButtonTap,
        onPlan: () {
          HapticFeedback.mediumImpact();
          context.push('/create-plan',
              extra: CreatePlanArgs(
                  vibe: args.vibe, optionLabel: args.optionLabel));
        },
        onShare: () {
          HapticFeedback.lightImpact();
          ref.read(analyticsRepositoryProvider).trackShareClicked(surface: 'response_multi');
          final vibeEmoji = args.vibe == 'fomo' ? '⚡' : '🛌';
          SharePlus.instance.share(ShareParams(
            text: '$vibeEmoji trombl says: ${args.optionLabel}\ntrombl.com',
            subject: 'trombl pick',
          ));
        },
        onPickElse: () => context.go('/home'),
      );
    }

    // Standard CTAs.
    return Column(
      children: [
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
                  colors: [accent, accent.withValues(alpha: 0.8)],
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
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.push('/create-plan',
                      extra: CreatePlanArgs(
                          vibe: args.vibe, optionLabel: args.optionLabel));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: TromblColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '🔥 make it a plan',
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
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(analyticsRepositoryProvider).trackShareClicked(surface: 'response_standard');
                  final vibeEmoji = args.vibe == 'fomo' ? '⚡' : '🛌';
                  SharePlus.instance.share(ShareParams(
                    text: '$vibeEmoji trombl says: ${args.optionLabel}\ntrombl.com',
                    subject: 'trombl pick',
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: TromblColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TromblColors.border),
                  ),
                  child: const Text(
                    '🔗 share this',
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
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => context.go('/home'),
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
      builder: (_, _) => Opacity(
        opacity: _anim.value,
        child: const Text(
          'trom is thinking…',
          style: TextStyle(
            fontFamily: TromblText.sans,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: TromblColors.textMuted,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

// ─── Post-launch CTAs ─────────────────────────────────────────────────────────

class _LaunchedCtas extends StatelessWidget {
  const _LaunchedCtas({
    required this.accent,
    required this.tag,
    required this.onDone,
    this.secondaryLabel,
    this.onSecondary,
  });
  final Color accent;
  final String tag;
  final void Function(bool done) onDone;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

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

        // Secondary follow-up button (e.g. "find a bar →" after WhatsApp)
        if (secondaryLabel != null && onSecondary != null) ...[
          GestureDetector(
            onTap: onSecondary,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: TromblColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: Text(
                secondaryLabel!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  fontFamily: TromblText.sans,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

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

// ─── Multi-button CTA (Netflix+YouTube, coffee options, etc.) ─────────────────

class _MultiButtonCta extends StatelessWidget {
  const _MultiButtonCta({
    required this.action,
    required this.accent,
    required this.loading,
    required this.onTap,
    required this.onPlan,
    required this.onShare,
    required this.onPickElse,
  });
  final MultiButtonAction action;
  final Color accent;
  final bool loading;
  final void Function(String url) onTap;
  final VoidCallback onPlan;
  final VoidCallback onShare;
  final VoidCallback onPickElse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // URL buttons
        ...action.buttons.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: loading ? null : () => onTap(b.url),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: loading ? 0.6 : 1.0,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.8)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      b.label,
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
            )),

        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onPlan,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: TromblColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '🔥 make it a plan',
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
                onTap: onShare,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: TromblColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TromblColors.border),
                  ),
                  child: const Text(
                    '🔗 share this',
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
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onPickElse,
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
    );
  }
}

// ─── Memory prompt CTA ────────────────────────────────────────────────────────

class _MemoryPromptCta extends StatelessWidget {
  const _MemoryPromptCta({
    required this.promptText,
    required this.controller,
    required this.onSubmit,
    required this.onCancel,
    required this.accent,
    required this.loading,
  });
  final String promptText;
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final Color accent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: TromblColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                promptText,
                style: const TextStyle(
                  color: TromblColors.text,
                  fontSize: 14,
                  fontFamily: TromblText.sans,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(
                  color: TromblColors.text,
                  fontFamily: TromblText.sans,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'type here…',
                  hintStyle: const TextStyle(
                    color: TromblColors.textMuted,
                    fontFamily: TromblText.sans,
                  ),
                  filled: true,
                  fillColor: TromblColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: loading ? null : onSubmit,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: loading ? 0.6 : 1.0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient:
                    LinearGradient(colors: [accent, accent.withValues(alpha: 0.8)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                loading ? 'opening…' : 'ok, save & open →',
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
        GestureDetector(
          onTap: onCancel,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TromblColors.border),
            ),
            child: const Text(
              'skip for now',
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
