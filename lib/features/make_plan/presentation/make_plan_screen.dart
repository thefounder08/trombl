import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../../shared/result.dart';
import '../../menu/domain/menu_models.dart';
import '../../plan/domain/plan_phrasing.dart';
import '../../plans/providers/plan_providers.dart';
import '../domain/make_plan_draft.dart';
import 'steps/choose_activity_step.dart';
import 'steps/choose_options_step.dart';
import 'steps/date_time_step.dart';
import 'steps/invite_friends_step.dart';
import 'steps/location_step.dart';
import 'steps/preview_step.dart';

/// Args passed via GoRouter's `extra` when navigating to /make-plan.
/// [initialOption] lets an entry point that already has an activity picked
/// (e.g. the response screen's "make it a plan" button) skip straight to
/// Date & Time instead of re-asking Choose Activity / Choose Options.
class MakePlanArgs {
  const MakePlanArgs({required this.vibe, this.initialOption});
  final String vibe;
  final MenuOption? initialOption;
}

const _kStepCount = 6; // activity, options, date/time, location, invite, preview

class MakePlanScreen extends ConsumerStatefulWidget {
  const MakePlanScreen({super.key, required this.args});
  final MakePlanArgs args;

  @override
  ConsumerState<MakePlanScreen> createState() => _MakePlanScreenState();
}

class _MakePlanScreenState extends ConsumerState<MakePlanScreen> {
  late int _step;
  late MakePlanDraft _draft;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _draft = MakePlanDraft(vibe: widget.args.vibe, option: widget.args.initialOption);
    // Skip Choose Activity / Choose Options when an option was already
    // picked upstream (e.g. from the response screen).
    _step = widget.args.initialOption != null ? 2 : 0;
  }

  int get _floor => widget.args.initialOption != null ? 2 : 0;

  void _back() {
    HapticFeedback.lightImpact();
    if (_step > _floor) {
      setState(() => _step -= 1);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _next() {
    if (_step < _kStepCount - 1) setState(() => _step += 1);
  }

  Future<void> _create() async {
    if (_creating) return;
    HapticFeedback.mediumImpact();
    setState(() => _creating = true);

    final title = _draft.option != null
        ? planPhrasing(_draft.option!.label)
        : 'trombl plan';
    final expiresAt = _draft.startsAt?.add(const Duration(hours: 3));

    final result = await ref.read(featurePlanRepoProvider).createPlan(
          vibe: _draft.vibe,
          title: title,
          location: _draft.location,
          startsAt: _draft.startsAt,
          expiresAt: expiresAt,
        );

    if (!mounted) return;

    switch (result) {
      case Success(:final data):
        ref.read(analyticsRepositoryProvider).trackPlanCreated(vibe: _draft.vibe);
        // Home stays mounted underneath this route (reached via push, not
        // go), so its myPlansProvider watch is still alive — without this,
        // it'd keep showing the stale pre-creation list until the app is
        // fully restarted, since autoDispose only refetches when a provider
        // goes from zero watchers back to one.
        ref.invalidate(myPlansProvider);
        // Pending invites for anyone found via search — the host sees these
        // as "pending" on Plan Details until each person responds.
        for (final p in _draft.invited) {
          unawaited(
              ref.read(featurePlanRepoProvider).invitePending(data.plan.id, p.id));
        }
        // Existing invite system — same share sheet CreatePlanScreen used to
        // trigger, still the primary way to reach anyone (including people
        // not on Trombl yet).
        await SharePlus.instance.share(ShareParams(
          text:
              "trom says we should do this.\n\n${data.plan.title}\n\n${data.shareUrl}",
          subject: data.plan.title,
        ));
        if (!mounted) return;
        context.pushReplacement('/plan/${data.plan.id}');
      case Failure(:final error):
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = TromblColors.accentFor(_draft.vibe);

    return PopScope(
      // Mid-wizard, the system/hardware back gesture should step back one
      // page (same as the "← back" text) instead of exiting the whole flow
      // and losing progress — it only pops the route once at the floor step.
      canPop: _step <= _floor,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _back,
                      child: const Text('← back',
                          style: TextStyle(
                              color: TromblColors.textMuted, fontSize: 13)),
                    ),
                    const Spacer(),
                    _StepDots(step: _step, count: _kStepCount, accent: accent),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(child: _buildStep(accent)),
                const SizedBox(height: 16),
                _buildFooter(accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(Color accent) {
    switch (_step) {
      case 0:
        return ChooseActivityStep(
          vibe: _draft.vibe,
          accent: accent,
          onSelect: (cat) {
            setState(() => _draft = _draft.copyWith(category: cat));
            _next();
          },
        );
      case 1:
        return ChooseOptionsStep(
          category: _draft.category!,
          accent: accent,
          onSelect: (opt) {
            setState(() => _draft = _draft.copyWith(option: opt));
            _next();
          },
        );
      case 2:
        return DateTimeStep(
          accent: accent,
          startsAt: _draft.startsAt,
          onChanged: (dt) => setState(() => _draft = _draft.copyWith(
              startsAt: dt, clearStartsAt: dt == null)),
        );
      case 3:
        return LocationStep(
          accent: accent,
          location: _draft.location,
          onChanged: (loc) => setState(() =>
              _draft = _draft.copyWith(location: loc, clearLocation: loc == null)),
        );
      case 4:
        return InviteFriendsStep(
          accent: accent,
          invited: _draft.invited,
          onToggle: (profile) {
            final already = _draft.invited.any((p) => p.id == profile.id);
            setState(() => _draft = _draft.copyWith(
                  invited: already
                      ? _draft.invited.where((p) => p.id != profile.id).toList()
                      : [..._draft.invited, profile],
                ));
          },
        );
      default:
        return PreviewStep(draft: _draft, accent: accent);
    }
  }

  Widget _buildFooter(Color accent) {
    // Steps 0 & 1 advance on tap (no separate continue button needed).
    if (_step == 0 || _step == 1) return const SizedBox.shrink();

    final isPreview = _step == _kStepCount - 1;
    return GestureDetector(
      onTap: isPreview ? _create : _next,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _creating ? 0.6 : 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            color: _creating ? TromblColors.card : accent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            isPreview
                ? (_creating ? 'locking it in...' : 'create plan →')
                : 'continue →',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TromblText.sans,
              color: _creating ? TromblColors.textMuted : const Color(0xFF090909),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.count, required this.accent});
  final int step;
  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i <= step;
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? accent : TromblColors.border,
            ),
          ),
        );
      }),
    );
  }
}
