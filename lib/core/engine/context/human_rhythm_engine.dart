import 'context_models.dart';

/// Derives what people TYPICALLY need at a given time.
///
/// This is the baseline. Mood ALWAYS overrides it.
/// Rhythm = smart default. Mood = override. Never invert this.
///
/// Architecture: pure static functions, no I/O.
/// Input: hour + day type. Output: HumanRhythmContext.
abstract final class HumanRhythmEngine {
  // ─── Public API ──────────────────────────────────────────────────────────────

  static HumanRhythmContext derive(TimePeriod period) {
    return switch (period) {
      TimePeriod.deepNight      => _deepNight(),
      TimePeriod.earlyMorning   => _earlyMorning(),
      TimePeriod.workMorning    => _workMorning(),
      TimePeriod.workAfternoon  => _workAfternoon(),
      TimePeriod.leisureMorning => _leisureMorning(),
      TimePeriod.leisureAfternoon => _leisureAfternoon(),
      TimePeriod.primeTime      => _primeTime(),
      TimePeriod.windDown       => _windDown(),
    };
  }

  static TimePeriod periodFor(int hour, DayType dayType) {
    if (hour >= 0 && hour < 5) return TimePeriod.deepNight;
    if (hour >= 5 && hour < 9) return TimePeriod.earlyMorning;
    if (hour >= 9 && hour < 12) {
      return dayType == DayType.weekday
          ? TimePeriod.workMorning
          : TimePeriod.leisureMorning;
    }
    if (hour >= 12 && hour < 18) {
      return dayType == DayType.weekday
          ? TimePeriod.workAfternoon
          : TimePeriod.leisureAfternoon;
    }
    if (hour >= 18 && hour < 22) return TimePeriod.primeTime;
    return TimePeriod.windDown;
  }

  static DayType dayTypeFor(String dayOfWeek) {
    return (dayOfWeek == 'sat' || dayOfWeek == 'sun')
        ? DayType.weekend
        : DayType.weekday;
  }

  // ─── Rhythm definitions ───────────────────────────────────────────────────

  static HumanRhythmContext _deepNight() => const HumanRhythmContext(
        period: TimePeriod.deepNight,
        likelyNeeds: ['sleep', 'rest', 'quiet wind-down', 'insomnia relief'],
        forbiddenCategories: [
          'going out', 'nightlife', 'social plans', 'errands',
          'exercise', 'exploration', 'food delivery (unless specified)',
        ],
        allowedCategories: [
          'sleep prep', 'breathing', 'quiet audio', 'dim lights',
          'lying in dark', 'journaling (if can\'t sleep)',
        ],
        directive: '''DEEP NIGHT (12am–5am):
ONLY: sleep, breathing exercises, quiet audio, lying in the dark.
FORBIDDEN: going outside, contacting people, high-energy anything.
If user says they can't sleep → real wind-down advice only.
If user says "night shift" / "working late" → acknowledge it and suggest focus/quiet productivity.''',
      );

  static HumanRhythmContext _earlyMorning() => const HumanRhythmContext(
        period: TimePeriod.earlyMorning,
        likelyNeeds: [
          'wake up', 'breakfast', 'sunlight', 'gentle movement',
          'meditation', 'planning the day', 'slow coffee',
        ],
        forbiddenCategories: [
          'nightlife', 'bars', 'clubs', 'late-night plans', 'heavy social',
        ],
        allowedCategories: [
          'morning routine', 'movement', 'food', 'sunlight',
          'journaling', 'quiet productivity',
        ],
        directive: '''EARLY MORNING (5–9am):
OK: gentle movement, breakfast, sunlight, slow coffee, journaling, ease-in planning.
NOT OK: bars, clubs, nightlife, heavy commitments.
Energy is building — suggest things that set up the day well.''',
      );

  static HumanRhythmContext _workMorning() => const HumanRhythmContext(
        period: TimePeriod.workMorning,
        likelyNeeds: [
          'deep work', 'focus', 'study', 'task completion',
          'proper break', 'hydration', 'coffee', 'lunch planning',
        ],
        forbiddenCategories: [
          'going out', 'parties', 'movies', 'shopping',
          'nightlife', 'exploration', 'social events',
        ],
        allowedCategories: [
          'focus sprint', 'work break (≤20 min)', 'coffee',
          'hydration', 'quick stretch', 'task planning',
        ],
        directive: '''WORK MORNING — weekday 9am-12pm:
This is standard working/study time. Most people are heads-down.
ALLOWED: focus activities, proper breaks, coffee runs, quick resets.
FORBIDDEN unless mood overrides: leisure, going out, social plans, shopping, any activity that assumes free time.
If mood says "day off" / "free today" / "not working" → IGNORE these restrictions, treat as weekend leisure.''',
      );

  static HumanRhythmContext _workAfternoon() => const HumanRhythmContext(
        period: TimePeriod.workAfternoon,
        likelyNeeds: [
          'lunch', 'focus sprint', 'energy recovery', 'coffee break',
          'finish tasks', 'afternoon walk', 'quick errands',
        ],
        forbiddenCategories: [
          'nightlife', 'parties', 'bars', 'clubs', 'movies (unless break)',
        ],
        allowedCategories: [
          'lunch', 'short walk', 'coffee', 'focus sprint',
          'task completion', 'quick errands', 'midday reset',
        ],
        directive: '''WORK AFTERNOON — weekday 12-6pm:
Lunch + focus + energy management time.
ALLOWED: lunch, 20-min outdoor walk reset, coffee, quick errands, finishing work tasks.
FORBIDDEN unless mood says day off: leisure outings, parties, any multi-hour commitment.
If mood says "day off" / "took the day" → switch to leisure mode entirely.''',
      );

  static HumanRhythmContext _leisureMorning() => const HumanRhythmContext(
        period: TimePeriod.leisureMorning,
        likelyNeeds: [
          'slow start', 'brunch', 'morning activity', 'cafes',
          'friends', 'errands', 'exploring', 'markets',
        ],
        forbiddenCategories: ['nightlife', 'bars', 'deep-night activities'],
        allowedCategories: [
          'brunch', 'cafes', 'markets', 'morning activities',
          'friends', 'errands', 'light exploring',
        ],
        directive: '''WEEKEND MORNING (9am-12pm):
It's the weekend — leisure is fully valid.
OK: brunch, cafes, markets, meeting friends, morning activities, exploring.
NOT OK: nightlife (save that for evening).''',
      );

  static HumanRhythmContext _leisureAfternoon() => const HumanRhythmContext(
        period: TimePeriod.leisureAfternoon,
        likelyNeeds: [
          'outings', 'cafes', 'events', 'shopping', 'exploring',
          'meeting friends', 'activities', 'movies', 'food',
        ],
        forbiddenCategories: ['deep-night activities', 'heavy wind-down'],
        allowedCategories: [
          'going out', 'social plans', 'cafes', 'events',
          'shopping', 'activities', 'exploring', 'food',
        ],
        directive: '''WEEKEND AFTERNOON (12-6pm):
Saturday 2pm ≠ Tuesday 2pm. Full leisure mode.
OK: outings, cafes, events, shopping, exploring, meeting friends, movies, any activity.
This is prime weekend time — be bold with suggestions.''',
      );

  static HumanRhythmContext _primeTime() => const HumanRhythmContext(
        period: TimePeriod.primeTime,
        likelyNeeds: [
          'socializing', 'going out', 'hobbies', 'gym', 'dates',
          'events', 'exploration', 'entertainment', 'dinner',
        ],
        forbiddenCategories: ['deep work', 'sleep', 'wind-down (too early)'],
        allowedCategories: [
          'going out', 'social plans', 'events', 'gym',
          'dinner', 'entertainment', 'dates', 'exploration',
        ],
        directive: '''PRIME TIME — 6pm-10pm any day:
This is the main social/activity window. Full range of suggestions valid.
fomo → going out, social plans, events, dinner, adventure.
jomo → home comforts, ordering in, low-key evening, entertainment.
All activity categories open.''',
      );

  static HumanRhythmContext _windDown() => const HumanRhythmContext(
        period: TimePeriod.windDown,
        likelyNeeds: [
          'wind down', 'journaling', 'reading', 'stretching',
          'sleep prep', 'light entertainment', 'reflecting',
        ],
        forbiddenCategories: [
          'starting big plans', 'loud social events', 'high-energy activities',
        ],
        allowedCategories: [
          'light entertainment', 'reading', 'journaling',
          'stretching', 'low-key social', 'ordering in',
        ],
        directive: '''WIND DOWN — 10pm-12am:
Evening is closing. Low-key, home-leaning suggestions.
OK: quiet entertainment, reading, journaling, light social (home / online), ordering in.
NOT OK: starting new big plans, loud events, high-energy commitments.
Nudge toward wrapping up gracefully.''',
      );
}
