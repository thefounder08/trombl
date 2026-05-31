import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_config.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/result.dart';
import '../providers/plan_providers.dart';

class CreatePlanSheet extends ConsumerStatefulWidget {
  const CreatePlanSheet({
    super.key,
    required this.vibe,
    required this.initialTitle,
  });
  final String vibe;
  final String initialTitle;

  @override
  ConsumerState<CreatePlanSheet> createState() => _CreatePlanSheetState();
}

class _CreatePlanSheetState extends ConsumerState<CreatePlanSheet> {
  late final TextEditingController _ctrl;
  Plan? _created;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _ctrl.text.trim();
    if (title.isEmpty) return;
    setState(() { _loading = true; _error = null; });

    final Result<Plan> result = await ref.read(planRepositoryProvider).createPlan(
      vibe: widget.vibe,
      title: title,
    );

    setState(() { _loading = false; });

    switch (result) {
      case Success(:final data):
        setState(() => _created = data);
        ref.invalidate(myPlansProvider);
      case Failure(:final error):
        setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = TromblColors.accentFor(widget.vibe);

    return Container(
      decoration: const BoxDecoration(
        color: TromblColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: TromblColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _created == null ? 'make it a plan' : 'plan created 🙌',
            style: TextStyle(
              fontFamily: TromblText.serif,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 20),
          if (_created == null) ...[
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: const TextStyle(color: TromblColors.text, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'what\'s the plan?',
                hintStyle: const TextStyle(color: TromblColors.textMuted),
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
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loading ? null : _create,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _loading ? TromblColors.card : accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _loading ? 'making it...' : 'create plan →',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _loading
                        ? TromblColors.textSub
                        : const Color(0xFF0B0B0D),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ] else ...[
            _ShareSection(plan: _created!, vibe: widget.vibe),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                context.push('/plan/${_created!.id}');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: TromblColors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'view plan →',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: TromblColors.textSub,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShareSection extends StatelessWidget {
  const _ShareSection({required this.plan, required this.vibe});
  final Plan plan;
  final String vibe;

  @override
  Widget build(BuildContext context) {
    final token = plan.shareToken;
    final shareText =
        "i'm planning: ${plan.title}. you in?\n${AppConfig.shareBaseUrl}/p/$token";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'share the code with ur crew:',
          style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        // Code + copy
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Clipboard.setData(ClipboardData(text: token));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('code copied 👌')),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: TromblColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TromblColors.borderMid),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  token,
                  style: const TextStyle(
                    color: TromblColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    fontFamily: TromblText.sans,
                  ),
                ),
                const Text('tap to copy',
                    style: TextStyle(
                        color: TromblColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Native share
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Share.share(shareText, subject: "join my trombl plan");
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: TromblColors.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'share 🔗',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: TromblColors.textSub,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // WhatsApp
            Expanded(
              child: GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse(
                      'whatsapp://send?text=${Uri.encodeComponent(shareText)}'),
                  mode: LaunchMode.externalApplication,
                ).catchError((_) async {
                  // fallback to web WhatsApp
                  return launchUrl(
                    Uri.parse(
                        'https://api.whatsapp.com/send?text=${Uri.encodeComponent(shareText)}'),
                    mode: LaunchMode.externalApplication,
                  );
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'whatsapp 💬',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF25D366),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
