import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/trombl_theme.dart';
import '../../../shared/result.dart';
import '../providers/plan_providers.dart';

/// Args passed via GoRouter extra when navigating to /create-plan.
class CreatePlanArgs {
  const CreatePlanArgs({
    required this.vibe,
    required this.optionLabel,
    this.reactionText,
  });
  final String vibe;
  final String optionLabel;
  final String? reactionText; // pre-fills the plan detail from LLM reaction
}

/// Full-screen create-plan flow — accessible from response screen when
/// a squad-tagged option is picked.
///
/// Pre-fills title from option label. Generates share URL and opens the
/// system share sheet on confirm.
class CreatePlanScreen extends ConsumerStatefulWidget {
  const CreatePlanScreen({super.key, required this.args});
  final CreatePlanArgs args;

  @override
  ConsumerState<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends ConsumerState<CreatePlanScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _detailCtrl;
  bool _loading = false;
  String? _shareUrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.args.optionLabel);
    _detailCtrl =
        TextEditingController(text: widget.args.reactionText ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);

    final result = await ref.read(featurePlanRepoProvider).createPlan(
          vibe: widget.args.vibe,
          title: title,
          detail: _detailCtrl.text.trim().isEmpty ? null : _detailCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case Success(:final data):
        final shareUrl = data.shareUrl;
        setState(() => _shareUrl = shareUrl);
        // Open system share sheet immediately
        await Share.share(
          "trom says we should do this.\n\n${data.plan.title}\n\n$shareUrl",
          subject: data.plan.title,
        );
      case Failure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = TromblColors.accentFor(widget.args.vibe);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 28),

              // Heading
              const Text(
                'make it a plan.',
                style: TextStyle(
                  fontFamily: TromblText.serif,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: TromblColors.text,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'trom will write the invite. u just hit send.',
                style: TextStyle(
                  fontFamily: TromblText.sans,
                  color: TromblColors.textSub,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Title field
              const _Label('WHAT\'S THE PLAN'),
              const SizedBox(height: 8),
              _Field(
                controller: _titleCtrl,
                hint: 'give it a name',
                maxLines: 1,
              ),
              const SizedBox(height: 16),

              // Detail field (pre-filled from LLM reaction)
              const _Label('DETAILS (OPTIONAL)'),
              const SizedBox(height: 8),
              _Field(
                controller: _detailCtrl,
                hint: 'any extra context...',
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Share URL banner (shown after plan is created)
              if (_shareUrl != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TromblColors.cardLit,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'plan created.',
                        style: TextStyle(
                          fontFamily: TromblText.serif,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _shareUrl!,
                        style: const TextStyle(
                          fontFamily: TromblText.sans,
                          color: TromblColors.textSub,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Re-share button
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await Share.share(_shareUrl!);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: TromblColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TromblColors.border),
                    ),
                    child: const Text(
                      'share again 🔗',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TromblText.sans,
                        color: TromblColors.textSub,
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
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: TromblColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TromblColors.border),
                    ),
                    child: const Text(
                      'back to menu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TromblText.sans,
                        color: TromblColors.textSub,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Create button
                GestureDetector(
                  onTap: _loading ? null : _create,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: BoxDecoration(
                      color: _loading ? TromblColors.card : accent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _loading ? 'trom is making it...' : 'create + share →',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TromblText.sans,
                        color: _loading
                            ? TromblColors.textMuted
                            : const Color(0xFF090909),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontFamily: TromblText.sans,
          color: TromblColors.textMuted,
          fontSize: 9,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint, this.maxLines = 1});
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
          fontFamily: TromblText.sans,
          color: TromblColors.text,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontFamily: TromblText.sans,
            color: TromblColors.textMuted,
          ),
          filled: true,
          fillColor: TromblColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}
