import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../../decide/domain/ai_pick_model.dart';
import '../../decide/providers/decide_providers.dart';
import '../../vibe/providers/session_providers.dart';

typedef HomeGreetingData = ({
  String? firstName,
  List<Session> recentSessions,
  List<AiPick> recentAccepted,
  List<AiPick> pendingCheckins,
});

/// Fetches all data needed for the home. No LLM calls — templated only.
final homeGreetingProvider =
    FutureProvider.autoDispose<HomeGreetingData>((ref) async {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final decideRepo = ref.watch(decideRepositoryProvider);

  final profileFuture = sessionRepo.getProfile();
  final sessionsFuture = sessionRepo.recentSessions(days: 7);
  final picksFuture = decideRepo.recentAiPicks(limit: 10);
  final checkinsFuture = decideRepo.pendingCheckins(limit: 3);

  final profile = await profileFuture;
  final sessions = await sessionsFuture;
  final picks = await picksFuture;
  final checkins = await checkinsFuture;

  return (
    firstName: _firstName(profile?.displayName),
    recentSessions: sessions,
    recentAccepted: picks.where((p) => p.accepted && !p.rerolled).toList(),
    pendingCheckins: checkins,
  );
});

String? _firstName(String? displayName) {
  if (displayName == null || displayName.isEmpty) return null;
  return displayName.split(' ').first;
}

/// Builds the one-line greeting for Zone 1.
/// Uses only real data — never fakes a pattern that doesn't exist.
String buildGreeting(HomeGreetingData data, String currentVibe) {
  final now = DateTime.now();
  final h = now.hour;
  final tod = h < 12
      ? 'morning'
      : h < 17
          ? 'afternoon'
          : h < 21
              ? 'evening'
              : 'hey';

  final name = data.firstName?.toLowerCase() ?? '';
  final nameStr = name.isNotEmpty ? ', $name' : '';

  // --- Check for a very recent accepted pick (last 6 hours) ---
  final recentCutoff = now.subtract(const Duration(hours: 6));
  final lastPick = data.recentAccepted.isNotEmpty
      ? data.recentAccepted.first
      : null;

  if (lastPick != null &&
      lastPick.createdAt != null &&
      lastPick.createdAt!.isAfter(recentCutoff)) {
    return _pickGreeting(lastPick, nameStr, tod);
  }

  // Sessions from BEFORE today (to avoid counting today's fresh pick)
  final today = DateTime(now.year, now.month, now.day);
  final pastSessions = data.recentSessions.where((s) {
    final d = s.startedAt;
    if (d == null) return false;
    return DateTime(d.year, d.month, d.day).isBefore(today);
  }).toList();

  // Brand new user — honest, no fake patterns
  if (pastSessions.isEmpty) {
    return '$tod$nameStr. let\'s find ur thing.';
  }

  // Strong vibe pattern: 3+ past days same vibe
  final jomoDays = pastSessions.where((s) => s.vibe == 'jomo').length;
  final fomoDays = pastSessions.where((s) => s.vibe == 'fomo').length;

  if (pastSessions.length >= 3) {
    if (jomoDays >= 3 && jomoDays > fomoDays) {
      return '$tod$nameStr. you\'ve gone jomo $jomoDays days running.';
    }
    if (fomoDays >= 3 && fomoDays > jomoDays) {
      return '$tod$nameStr. full fomo mode lately.';
    }
  }

  // Weekend context
  final weekday = now.weekday; // 1=Mon 7=Sun
  if (weekday == 7 && currentVibe == 'jomo' && jomoDays > 0) {
    return '$tod$nameStr. sunday jomo, as expected.';
  }
  if ((weekday == 5 || weekday == 6) && currentVibe == 'fomo' && fomoDays > 0) {
    return '$tod$nameStr. weekend fomo energy.';
  }

  return '$tod$nameStr.';
}

/// Produces a greeting line referencing a real recent pick.
String _pickGreeting(AiPick pick, String nameStr, String tod) {
  final v = pick.vibe;
  final text = pick.pickText.toLowerCase();

  if (v == 'jomo') {
    if (text.contains('coffee') || text.contains('tea')) {
      return '$tod$nameStr. slow brew vibes — still winding down?';
    }
    if (text.contains('walk') || text.contains('outside') || text.contains('fresh air')) {
      return '$tod$nameStr. you chose outside. nice.';
    }
    if (text.contains('sleep') || text.contains('nap') || text.contains('rest')) {
      return '$tod$nameStr. you went full rest mode.';
    }
    return '$tod$nameStr. earlier you went jomo — still winding down?';
  }

  if (v == 'fomo') {
    if (text.contains('walk') || text.contains('outside') || text.contains('run')) {
      return '$tod$nameStr. you got outside earlier. keeping the energy?';
    }
    if (text.contains('friend') || text.contains('squad') || text.contains('people')) {
      return '$tod$nameStr. social mode was on. what\'s next?';
    }
    return '$tod$nameStr. you picked something — ready for more?';
  }

  return '$tod$nameStr. you made a pick earlier.';
}

/// Relative time label: "just now", "this morning", "tonight", "yesterday"
String relativePickTime(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 60) return 'just now';

  final todayStart = DateTime(now.year, now.month, now.day);
  final pickDay = DateTime(dt.year, dt.month, dt.day);

  if (pickDay == todayStart) {
    final h = dt.hour;
    if (h < 12) return 'this morning';
    if (h < 17) return 'this afternoon';
    return 'tonight';
  }

  final yesterday = todayStart.subtract(const Duration(days: 1));
  if (pickDay == yesterday) return 'yesterday';

  return '${diff.inDays}d ago';
}

/// Vibe emoji prefix for a pick row.
String vibeEmoji(String vibe) => vibe == 'jomo' ? '🌙' : '⚡';
