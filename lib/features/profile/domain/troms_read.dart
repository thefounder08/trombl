import '../../../shared/models/models.dart';
import '../../decide/domain/ai_pick_model.dart';

/// Pure, template-driven copy for the "trom's read on u" screen.
/// No live AI call — everything here is computed from real rows so the
/// screen loads instantly and costs nothing.

const _weekdayNames = [
  'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
];

const _prefLabels = {
  'usual_place': 'ur usual',
  'comfort_show': 'comfort show',
};

String _weekdayName(DateTime d) => _weekdayNames[d.weekday - 1];

String _dayLabelFor(DateTime d) {
  final now = DateTime.now();
  final diff = DateTime(now.year, now.month, now.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return 'yesterday';
  return _weekdayName(d);
}

/// "usual_place: zomato" → key: usual_place, value: zomato.
/// Returns null for non-preference nodes or malformed/empty content.
MapEntry<String, String>? parsePreference(MemoryNode node) {
  if (node.type != 'preference') return null;
  final parts = node.content.split(': ');
  if (parts.length < 2) return null;
  final key = parts[0].trim();
  final value = parts.sublist(1).join(': ').trim();
  if (key.isEmpty || value.isEmpty) return null;
  return MapEntry(key, value);
}

/// Human label for a known preference key, or null if unrecognised
/// (unrecognised keys are skipped — never shown raw).
String? preferenceLabel(String key) => _prefLabels[key];

/// Latest value saved for [key] among preference memory nodes, or null.
String? preferenceValue(List<MemoryNode> nodes, String key) {
  for (final n in nodes) {
    final parsed = parsePreference(n);
    if (parsed != null && parsed.key == key) return parsed.value;
  }
  return null;
}

/// First 40 chars of a journal entry + "..." if longer. Never the raw entry.
String emotionPreview(MemoryNode node) {
  final text = node.content.trim();
  if (text.length <= 40) return text;
  return '${text.substring(0, 40)}...';
}

int fomoCountThisWeek(List<Session> sessions) {
  final weekAgo = DateTime.now().subtract(const Duration(days: 7));
  return sessions
      .where((s) =>
          s.vibe == 'fomo' && s.startedAt != null && s.startedAt!.isAfter(weekAgo))
      .length;
}

/// A weekday name where the user has gone quiet (no session) in the last
/// week, while being active on other days — or null if no clean gap exists.
String? quietDayThisWeek(List<Session> sessions) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final activeDates = sessions
      .where((s) => s.startedAt != null)
      .map((s) =>
          DateTime(s.startedAt!.year, s.startedAt!.month, s.startedAt!.day))
      .toSet();
  final missing = <DateTime>[];
  for (var i = 1; i < 7; i++) {
    final day = today.subtract(Duration(days: i));
    if (!activeDates.contains(day)) missing.add(day);
  }
  if (missing.length == 1) return _weekdayName(missing.first);
  return null;
}

/// "always go jomo on sundays" — a weekday with >=2 sessions, all same vibe.
String? weekdayVibeRepeat(List<Session> sessions) {
  final byWeekday = <int, List<String>>{};
  for (final s in sessions) {
    final d = s.startedAt;
    if (d == null) continue;
    byWeekday.putIfAbsent(d.weekday, () => []).add(s.vibe);
  }
  for (final entry in byWeekday.entries) {
    if (entry.value.length >= 2 && entry.value.toSet().length == 1) {
      return 'always go ${entry.value.first} on ${_weekdayNames[entry.key - 1]}s';
    }
  }
  return null;
}

/// True when "order in" is the dominant tag among recent picks.
bool alwaysOrdersIn(List<AiPick> picks) {
  if (picks.length < 3) return false;
  final tagCounts = <String, int>{};
  for (final p in picks) {
    tagCounts[p.tag] = (tagCounts[p.tag] ?? 0) + 1;
  }
  final orderCount = tagCounts['order in'] ?? 0;
  if (orderCount < 2) return false;
  final maxCount = tagCounts.values.reduce((a, b) => a > b ? a : b);
  return orderCount == maxCount;
}

/// True when every pick with a known hour landed before 10pm.
bool quietAfter10pm(List<AiPick> picks) {
  final withHour = picks.where((p) => p.pickHour != null).toList();
  if (withHour.length < 3) return false;
  return withHour.every((p) => p.pickHour! < 22);
}

String? lastEmotionDay(List<MemoryNode> nodes) {
  final emotions = nodes
      .where((n) => n.type == 'emotion' && n.createdAt != null)
      .toList()
    ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
  if (emotions.isEmpty) return null;
  return _dayLabelFor(emotions.first.createdAt!);
}

/// The headline paragraph — trom's voice, computed from real data.
String buildTromsRead({
  required int sessionCount,
  required int pickCount,
  required List<Session> sessions,
  required List<AiPick> picks,
  required List<MemoryNode> memoryNodes,
}) {
  if (sessionCount == 0) {
    return "we just met. trom's still figuring u out.\n"
        "pick something and come back —\n"
        "that's when it gets interesting.";
  }

  if (sessionCount <= 2 && pickCount < 5) {
    return "we just met. trom's still figuring u out.\n"
        "come back after a few more sessions —\n"
        "that's when it gets interesting.";
  }

  if (sessionCount >= 8 && pickCount >= 15) {
    final weekdayPattern = weekdayVibeRepeat(sessions);
    final orders = alwaysOrdersIn(picks);
    if (weekdayPattern != null && orders) {
      return "u $weekdayPattern and u always order in.\n"
          "trom called it before u did.";
    }
    if (weekdayPattern != null) {
      return "u $weekdayPattern.\ntrom called it before u did.";
    }
    return "u've shown up $sessionCount times now.\n"
        "trom's got ur range figured out.";
  }

  // Week 1 tier — one specific observation + a preference if we have one.
  final fomoCount = fomoCountThisWeek(sessions);
  final quietDay = quietDayThisWeek(sessions);
  String observation;
  if (fomoCount > 0 && quietDay != null) {
    observation = "u've been fomo all week but went quiet $quietDay.\n"
        "trom clocked that.";
  } else if (fomoCount > 0) {
    observation =
        "u've picked fomo $fomoCount time${fomoCount > 1 ? 's' : ''} this week.\n"
        "trom's taking notes.";
  } else {
    observation = "u've shown up $sessionCount times so far.\n"
        "trom's starting to notice patterns.";
  }

  final usual = preferenceValue(memoryNodes, 'usual_place');
  final show = preferenceValue(memoryNodes, 'comfort_show');
  final prefParts = <String>[
    if (usual != null) 'ur usual is $usual',
    if (show != null) 'ur comfort show is $show',
  ];
  if (prefParts.isNotEmpty) {
    observation += '\n${prefParts.join('. ')}.';
  }
  return observation;
}

/// Up to 3 short, specific lines — only for slots with real data.
List<String> buildWhatTromClocked({
  required List<Session> sessions,
  required List<AiPick> picks,
  required List<MemoryNode> memoryNodes,
}) {
  final lines = <String>[];

  final fomoCount = fomoCountThisWeek(sessions);
  if (fomoCount > 0) {
    lines.add('⚡ picked fomo ${fomoCount}x this week');
  }

  if (quietAfter10pm(picks)) {
    lines.add('🛌 always goes quiet after 10pm');
  }

  final usual = preferenceValue(memoryNodes, 'usual_place');
  if (usual != null) {
    lines.add('📍 ur usual: $usual');
  }

  final show = preferenceValue(memoryNodes, 'comfort_show');
  if (show != null) {
    lines.add('📺 comfort show: $show');
  }

  final emotionDay = lastEmotionDay(memoryNodes);
  if (emotionDay != null) {
    lines.add('✍️ wrote something on $emotionDay — trom hasn\'t forgotten');
  }

  return lines.take(3).toList();
}

/// Last [max] accepted picks, newest first, deduplicated by pick text.
List<AiPick> dedupedAcceptedPicks(List<AiPick> picks, {int max = 3}) {
  final accepted = picks.where((p) => p.accepted).toList()
    ..sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  final seen = <String>{};
  final result = <AiPick>[];
  for (final p in accepted) {
    if (!seen.add(p.pickText)) continue;
    result.add(p);
    if (result.length >= max) break;
  }
  return result;
}

/// Plans deduplicated by id, capped at [max].
List<Plan> dedupedPlans(List<Plan> plans, {int max = 3}) {
  final seen = <String>{};
  final result = <Plan>[];
  for (final p in plans) {
    if (!seen.add(p.id)) continue;
    result.add(p);
    if (result.length >= max) break;
  }
  return result;
}
