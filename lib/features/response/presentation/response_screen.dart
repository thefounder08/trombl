import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/trombl_theme.dart';
import '../../../shared/models/models.dart';
import '../../menu/data/categories.dart';
import '../../plans/presentation/create_plan_sheet.dart';
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
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => context.go('/menu'),
                child: const Text(
                  '← back',
                  style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
                ),
              ),
              const Spacer(),
              Text(
                args.optionLabel,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              reaction.when(
                loading: () => const _TypingIndicator(),
                error: (_, __) => const Text(
                  "trom went quiet. but u already picked, so go.",
                  style: TextStyle(
                    fontFamily: TromblText.serif,
                    fontSize: 26,
                    color: TromblColors.text,
                    height: 1.25,
                  ),
                ),
                data: (text) => Text(
                  text,
                  style: const TextStyle(
                    fontFamily: TromblText.serif,
                    fontSize: 26,
                    color: TromblColors.text,
                    height: 1.25,
                  ),
                ),
              ),
              const Spacer(),
              if (args.action != ActionType.none) ...[
                _ActionButton(action: args.action, actionData: args.actionData),
                const SizedBox(height: 12),
              ],
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => CreatePlanSheet(
                    vibe: args.vibe,
                    initialTitle: args.optionLabel,
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: TromblColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'make it a plan 🤙',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => context.go('/menu'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: TromblColors.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'pick something else',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: TromblColors.textSub,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
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
            fontSize: 26,
            color: TromblColors.textMuted,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, this.actionData});
  final ActionType action;
  final String? actionData;

  @override
  Widget build(BuildContext context) {
    final (label, uri) = _resolve();
    return GestureDetector(
      onTap: () => _launch(uri),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [TromblColors.fomo, TromblColors.jomo]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF090909),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  (String, String) _resolve() => switch (action) {
    ActionType.zomato => ('open zomato →', 'https://zomato.com'),
    ActionType.bookmyshow => ('open bookmyshow →', 'https://bookmyshow.com'),
    ActionType.whatsapp => (
      'open whatsapp →',
      'whatsapp://send?text=${Uri.encodeComponent(actionData ?? "let's do something 👀")}',
    ),
    ActionType.dnd => ('enable do not disturb →', ''),
    ActionType.none => ('', ''),
  };

  Future<void> _launch(String uri) async {
    if (action == ActionType.dnd) {
      // Can't programmatically enable DND — open sound settings instead
      await launchUrl(
        Uri.parse('android.settings.SOUND_SETTINGS'),
        mode: LaunchMode.externalApplication,
      ).catchError((_) => false);
      return;
    }
    final parsed = Uri.parse(uri);
    if (await canLaunchUrl(parsed)) {
      await launchUrl(parsed, mode: LaunchMode.externalApplication);
    } else if (action == ActionType.whatsapp) {
      await launchUrl(
        Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(actionData ?? "")}'),
        mode: LaunchMode.externalApplication,
      );
    }
  }
}
