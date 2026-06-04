/// All value types produced by the Context + Human Rhythm engines.
library;

// ─── Time period ─────────────────────────────────────────────────────────────

/// A named slice of the 24-hour clock, differentiated by day type.
/// This is the primary key for all rhythm lookups.
enum TimePeriod {
  deepNight,        // 00-05  any day  — sleep / quiet only
  earlyMorning,     // 05-09  any day  — wake up, ease in
  workMorning,      // 09-12  weekday  — deep work
  workAfternoon,    // 12-18  weekday  — focus / lunch / recharge
  leisureMorning,   // 09-12  weekend  — explore / cafes
  leisureAfternoon, // 12-18  weekend  — social / outings
  primeTime,        // 18-22  any day  — social / events / hobbies
  windDown,         // 22-00  any day  — decompress / prep sleep
}

extension TimePeriodExt on TimePeriod {
  bool get isSleepOnly => this == TimePeriod.deepNight;
  bool get isWorkHours =>
      this == TimePeriod.workMorning || this == TimePeriod.workAfternoon;
  bool get isLeisure =>
      this == TimePeriod.leisureMorning ||
      this == TimePeriod.leisureAfternoon ||
      this == TimePeriod.primeTime;
  String get label => name;
}

// ─── Day type ─────────────────────────────────────────────────────────────────

enum DayType { weekday, weekend }

// ─── Human Rhythm Context ─────────────────────────────────────────────────────

/// What people are TYPICALLY doing at this time.
/// Mood overrides this — rhythm is the default, not a cage.
class HumanRhythmContext {
  const HumanRhythmContext({
    required this.period,
    required this.likelyNeeds,
    required this.forbiddenCategories,
    required this.allowedCategories,
    required this.directive,
  });

  final TimePeriod period;

  /// What this person likely needs right now (used in prompt as context).
  final List<String> likelyNeeds;

  /// Activity categories the engine should avoid suggesting.
  final List<String> forbiddenCategories;

  /// Activity categories that are appropriate.
  final List<String> allowedCategories;

  /// The explicit directive block injected into every prompt.
  final String directive;
}

// ─── Context Snapshot ─────────────────────────────────────────────────────────

/// The fully assembled context for a single decision moment.
/// Every engine call receives a ContextSnapshot — no engine touches DateTime directly.
class ContextSnapshot {
  const ContextSnapshot({
    required this.period,
    required this.dayType,
    required this.dayOfWeek,
    required this.hour,
    required this.vibe,
    required this.rhythm,
    this.weather,
    this.city,
    this.moodText,
  });

  final TimePeriod period;
  final DayType dayType;
  final String dayOfWeek;
  final int hour;
  final String vibe;
  final HumanRhythmContext rhythm;
  final String? weather;
  final String? city;

  /// User-typed mood — overrides rhythm when present.
  final String? moodText;

  bool get hasMood => moodText != null && moodText!.isNotEmpty;
  bool get isWeekend => dayType == DayType.weekend;

  /// Human-readable summary for debugging.
  @override
  String toString() =>
      'ContextSnapshot(period=${period.name}, day=$dayOfWeek, hour=$hour, '
      'vibe=$vibe, mood=$moodText, weather=$weather)';
}
