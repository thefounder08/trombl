import 'package:flutter/material.dart';

import '../../../../core/theme/trombl_theme.dart';

/// Same chip set + picker behaviour that used to live in CreatePlanScreen —
/// moved here rather than duplicated, since CreatePlanScreen is retired in
/// favour of this flow.
const _kChips = [
  (value: 'tonight', label: 'tonight'),
  (value: 'tomorrow', label: 'tomorrow'),
  (value: 'weekend', label: 'this weekend'),
  (value: 'custom', label: 'pick a time'),
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
  final min = dt.minute;
  final amPm = hour >= 12 ? 'PM' : 'AM';
  final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
  return min == 0 ? '$h $amPm' : '$h:${min.toString().padLeft(2, '0')} $amPm';
}

String _chipTimeLabel(String chip, DateTime dt) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final t = _formatTime(dt);
  switch (chip) {
    case 'tonight':
      return 'tonight · $t';
    case 'tomorrow':
      return 'tomorrow · $t';
    default:
      return '${days[dt.weekday - 1]} · $t';
  }
}

/// Step 3 — when's it happening (optional).
class DateTimeStep extends StatefulWidget {
  const DateTimeStep({
    super.key,
    required this.accent,
    required this.startsAt,
    required this.onChanged,
  });
  final Color accent;
  final DateTime? startsAt;
  final ValueChanged<DateTime?> onChanged;

  @override
  State<DateTimeStep> createState() => _DateTimeStepState();
}

class _DateTimeStepState extends State<DateTimeStep> {
  String? _selectedChip;

  @override
  void initState() {
    super.initState();
    // This widget is rebuilt fresh every time the wizard revisits this step
    // (e.g. going back from Location), so re-derive which chip is active
    // from the parent-held startsAt rather than always assuming 'custom'.
    final startsAt = widget.startsAt;
    if (startsAt == null) return;
    for (final chip in _kChips) {
      if (chip.value == 'custom') continue;
      if (startsAt == _chipDateTime(chip.value)) {
        _selectedChip = chip.value;
        return;
      }
    }
    _selectedChip = 'custom';
  }

  void _onChipTap(String chip) async {
    if (_selectedChip == chip && chip != 'custom') {
      setState(() => _selectedChip = null);
      widget.onChanged(null);
      return;
    }
    if (chip == 'custom') {
      await _pickCustomTime();
    } else {
      setState(() => _selectedChip = chip);
      widget.onChanged(_chipDateTime(chip));
    }
  }

  Future<void> _pickCustomTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: TromblColors.jomo,
            surface: TromblColors.card,
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
            primary: TromblColors.jomo,
            surface: TromblColors.card,
            onSurface: TromblColors.text,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(() => _selectedChip = 'custom');
    widget.onChanged(
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        const Text(
          'when we pulling up? ⏰',
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
          'optional — skip it if u don\'t know yet.',
          style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kChips.map((chip) {
            final isSelected = _selectedChip == chip.value;
            final label = (isSelected && widget.startsAt != null)
                ? _chipTimeLabel(chip.value, widget.startsAt!)
                : chip.label;
            return GestureDetector(
              onTap: () => _onChipTap(chip.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? widget.accent.withValues(alpha: 0.14)
                      : TromblColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? widget.accent.withValues(alpha: 0.5)
                        : TromblColors.border,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: TromblText.sans,
                    color: isSelected ? widget.accent : TromblColors.textSub,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
