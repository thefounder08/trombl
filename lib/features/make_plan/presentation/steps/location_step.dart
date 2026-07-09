import 'package:flutter/material.dart';

import '../../../../core/theme/trombl_theme.dart';

/// Step 4 — where's it happening (optional, skippable — not every activity
/// needs a physical place, e.g. content/rest picks).
class LocationStep extends StatefulWidget {
  const LocationStep({
    super.key,
    required this.accent,
    required this.location,
    required this.onChanged,
  });
  final Color accent;
  final String? location;
  final ValueChanged<String?> onChanged;

  @override
  State<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<LocationStep> {
  late final _ctrl = TextEditingController(text: widget.location ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        const Text(
          'where at? 📍',
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
          "optional — add it if u already know.",
          style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _ctrl,
          onChanged: (v) => widget.onChanged(v.trim().isEmpty ? null : v.trim()),
          style: const TextStyle(
            fontFamily: TromblText.sans,
            color: TromblColors.text,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'a place, a neighbourhood, "my place"...',
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
              borderSide: BorderSide(color: widget.accent.withValues(alpha: 0.4)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
