import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/trombl_theme.dart';
import '../../../shared/result.dart';
import '../domain/plan_phrasing.dart';
import '../providers/plan_providers.dart';

/// Args passed via GoRouter's `extra` when navigating to /create-plan.
class CreatePlanArgs {
  const CreatePlanArgs({
    required this.vibe,
    required this.optionLabel,
  });
  final String vibe;
  final String optionLabel;
}

// ─── Time-chip helpers ────────────────────────────────────────────────────────

const _kChips = [
  (value: 'tonight',  label: 'tonight'),
  (value: 'tomorrow', label: 'tomorrow'),
  (value: 'weekend',  label: 'this weekend'),
  (value: 'custom',   label: 'pick a time'),
];

DateTime _chipDateTime(String chip) {
  final now = DateTime.now();
  switch (chip) {
    case 'tonight':
      return DateTime(now.year, now.month, now.day, 20, 0);
    case 'tomorrow':
      final tm = now.add(const Duration(days: 1));
      return DateTime(tm.year, tm.month, tm.day, 20, 0);
    case 'weekend':
      final diff = (6 - now.weekday) % 7;
      final sat = now.add(Duration(days: diff == 0 ? 7 : diff));
      return DateTime(sat.year, sat.month, sat.day, 20, 0);
    default:
      return now;
  }
}

String _formatTime(DateTime dt) {
  final hour = dt.hour;
  final min  = dt.minute;
  final amPm = hour >= 12 ? 'PM' : 'AM';
  final h    = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
  return min == 0 ? '$h $amPm' : '$h:${min.toString().padLeft(2, '0')} $amPm';
}

String _chipTimeLabel(String chip, DateTime dt) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final t = _formatTime(dt);
  switch (chip) {
    case 'tonight':  return 'tonight · $t';
    case 'tomorrow': return 'tomorrow · $t';
    case 'weekend':  return '${days[dt.weekday - 1]} · $t';
    default:         return '${days[dt.weekday - 1]} · $t';
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class CreatePlanScreen extends ConsumerStatefulWidget {
  const CreatePlanScreen({super.key, required this.args});
  final CreatePlanArgs args;

  @override
  ConsumerState<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends ConsumerState<CreatePlanScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _detailCtrl;

  bool    _loading     = false;
  String? _shareUrl;
  String? _planId;

  // Time selection — stored locally; persisted to starts_at once the
  // DB migration (alter table plans add column starts_at timestamptz) is applied.
  String?   _selectedChip;
  DateTime? _startsAt;

  @override
  void initState() {
    super.initState();
    // BUG FIX: title uses human phrasing, NOT the raw menu-option label.
    // BUG FIX: detail always starts empty — never pre-fill with LLM output.
    _titleCtrl  = TextEditingController(text: planPhrasing(widget.args.optionLabel));
    _detailCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  // ── Time chip handling ─────────────────────────────────────────────────────

  void _onChipTap(String chip) async {
    if (_selectedChip == chip && chip != 'custom') {
      // Deselect
      setState(() { _selectedChip = null; _startsAt = null; });
      return;
    }
    if (chip == 'custom') {
      await _pickCustomTime();
    } else {
      setState(() {
        _selectedChip = chip;
        _startsAt     = _chipDateTime(chip);
      });
    }
  }

  Future<void> _pickCustomTime() async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary:   TromblColors.jomo,
            surface:   TromblColors.card,
            onSurface: TromblColors.text,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary:   TromblColors.jomo,
            surface:   TromblColors.card,
            onSurface: TromblColors.text,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _selectedChip = 'custom';
      _startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  Future<void> _create() async {
    final title  = _titleCtrl.text.trim();
    final detail = _detailCtrl.text.trim();
    if (title.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() => _loading = true);

    final result = await ref.read(featurePlanRepoProvider).createPlan(
      vibe:   widget.args.vibe,
      title:  title,
      detail: detail.isEmpty ? null : detail,
      // TODO: add startsAt: _startsAt once the DB migration is applied:
      //   alter table public.plans add column starts_at timestamptz;
      //   alter table public.plans add column expires_at timestamptz;
    );

    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case Success(:final data):
        setState(() {
          _shareUrl = data.shareUrl;
          _planId   = data.plan.id;
        });
        // Open share sheet immediately with human title + trombl link.
        await Share.share(
          "trom says we should do this.\n\n${data.plan.title}\n\n${data.shareUrl}",
          subject: data.plan.title,
        );
      case Failure(:final error):
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
          );
        }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = TromblColors.accentFor(widget.args.vibe);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back
              GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); context.go('/menu'); },
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

              if (_shareUrl == null) ...[
                // ── Create form ────────────────────────────────────────────

                // Title
                const _FieldLabel('WHAT\'S THE PLAN'),
                const SizedBox(height: 8),
                _Field(
                  controller: _titleCtrl,
                  hint: 'what are we doing?',
                  maxLines: 1,
                  accent: accent,
                ),
                const SizedBox(height: 20),

                // When chips
                const _FieldLabel('WHEN? (OPTIONAL)'),
                const SizedBox(height: 10),
                _TimeChips(
                  selected: _selectedChip,
                  startsAt: _startsAt,
                  accent: accent,
                  onTap: _onChipTap,
                ),
                const SizedBox(height: 20),

                // Detail
                const _FieldLabel('DETAILS (OPTIONAL)'),
                const SizedBox(height: 8),
                _Field(
                  controller: _detailCtrl,
                  hint: 'add a time, place, or vibe...',
                  maxLines: 3,
                  accent: accent,
                ),
                const SizedBox(height: 32),

                // Primary CTA
                GestureDetector(
                  onTap: _loading ? null : _create,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _loading ? 0.6 : 1.0,
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
                ),
              ] else ...[
                // ── Post-creation ──────────────────────────────────────────

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TromblColors.cardLit,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
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

                // Re-share
                _ShareButton(
                  label: 'share again 🔗',
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await Share.share(
                      "trom says we should do this.\n\n${_titleCtrl.text.trim()}\n\n$_shareUrl",
                    );
                  },
                ),
                const SizedBox(height: 10),

                // View plan
                if (_planId != null)
                  _ShareButton(
                    label: 'view plan →',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/plan/$_planId');
                    },
                  ),
                const SizedBox(height: 10),

                _ShareButton(
                  label: 'back to menu',
                  onTap: () => context.go('/menu'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Time chips widget ────────────────────────────────────────────────────────

class _TimeChips extends StatelessWidget {
  const _TimeChips({
    required this.selected,
    required this.startsAt,
    required this.accent,
    required this.onTap,
  });
  final String?   selected;
  final DateTime? startsAt;
  final Color     accent;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _kChips.map((chip) {
        final isSelected = selected == chip.value;
        final label = (isSelected && startsAt != null && chip.value != 'custom')
            ? _chipTimeLabel(chip.value, startsAt!)
            : (isSelected && startsAt != null && chip.value == 'custom')
                ? _chipTimeLabel('custom', startsAt!)
                : chip.label;

        return GestureDetector(
          onTap: () => onTap(chip.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? accent.withValues(alpha: 0.14)
                  : TromblColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? accent.withValues(alpha: 0.5)
                    : TromblColors.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: TromblText.sans,
                color: isSelected ? accent : TromblColors.textSub,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
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
  const _Field({
    required this.controller,
    required this.hint,
    required this.accent,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String hint;
  final Color  accent;
  final int    maxLines;

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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accent.withValues(alpha: 0.4)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
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
              fontFamily: TromblText.sans,
              color: TromblColors.textSub,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      );
}
