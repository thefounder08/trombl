import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/theme/trombl_theme.dart';
import '../../../../shared/models/models.dart';
import '../../providers/make_plan_providers.dart';

/// Step 5 — invite specific existing Trombl users (optional). There's no
/// friends/contacts model in this app, so this is a direct profile search,
/// not a social graph. Anyone not found here can still be reached the
/// existing way — sharing the plan link — once the plan exists (see
/// PlanDetailScreen's share row), so this step doesn't duplicate that.
class InviteFriendsStep extends ConsumerStatefulWidget {
  const InviteFriendsStep({
    super.key,
    required this.accent,
    required this.invited,
    required this.onToggle,
  });
  final Color accent;
  final List<Profile> invited;
  final void Function(Profile) onToggle;

  @override
  ConsumerState<InviteFriendsStep> createState() => _InviteFriendsStepState();
}

class _InviteFriendsStepState extends ConsumerState<InviteFriendsStep> {
  final _ctrl = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  bool _isInvited(Profile p) => widget.invited.any((i) => i.id == p.id);

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(profileSearchProvider(_query));

    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        const Text(
          "who's pulling up? 👀",
          style: TextStyle(
            fontFamily: TromblText.serif,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: TromblColors.text,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'search by name or handle — optional, u can share the link after too.',
          style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _ctrl,
          onChanged: _onChanged,
          style: const TextStyle(
            fontFamily: TromblText.sans,
            color: TromblColors.text,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'search trombl users...',
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
        ),
        if (widget.invited.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.invited
                .map((p) => _InvitedChip(
                      profile: p,
                      accent: widget.accent,
                      onRemove: () => widget.onToggle(p),
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        if (_query.isNotEmpty)
          resultsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('searching...',
                  style: TextStyle(color: TromblColors.textMuted, fontSize: 13)),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (results) => results.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('no one found.',
                        style:
                            TextStyle(color: TromblColors.textMuted, fontSize: 13)),
                  )
                : Column(
                    children: results
                        .map((p) => _ResultRow(
                              profile: p,
                              accent: widget.accent,
                              selected: _isInvited(p),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                widget.onToggle(p);
                              },
                            ))
                        .toList(),
                  ),
          ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.profile,
    required this.accent,
    required this.selected,
    required this.onTap,
  });
  final Profile profile;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName ??
        (profile.handle != null ? '@${profile.handle}' : 'trombl user');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.08) : TromblColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.3) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: TromblColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: TromblText.sans,
                ),
              ),
            ),
            Text(
              selected ? 'invited ✓' : 'invite',
              style: TextStyle(
                color: selected ? accent : TromblColors.textSub,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvitedChip extends StatelessWidget {
  const _InvitedChip({
    required this.profile,
    required this.accent,
    required this.onRemove,
  });
  final Profile profile;
  final Color accent;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName ??
        (profile.handle != null ? '@${profile.handle}' : 'trombl user');
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Text(
          '$name  ×',
          style: TextStyle(
            color: accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
