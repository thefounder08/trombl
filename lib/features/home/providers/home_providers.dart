import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../../decide/domain/ai_pick_model.dart';
import '../../decide/providers/decide_providers.dart';
import '../../vibe/providers/session_providers.dart';

typedef HomeGreetingData = ({
  String? firstName,
  List<Session> recentSessions,
  List<AiPick> recentAccepted,
});

/// Fetches all data needed for the home greeting. No LLM calls — templated only.
final homeGreetingProvider =
    FutureProvider.autoDispose<HomeGreetingData>((ref) async {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final decideRepo = ref.watch(decideRepositoryProvider);

  final profileFuture = sessionRepo.getProfile();
  final sessionsFuture = sessionRepo.recentSessions(days: 7);
  final picksFuture = decideRepo.recentAiPicks(limit: 10);

  final profile = await profileFuture;
  final sessions = await sessionsFuture;
  final picks = await picksFuture;

  return (
    firstName: _firstName(profile?.displayName),
    recentSessions: sessions,
    recentAccepted: picks.where((p) => p.accepted).toList(),
  );
});

String? _firstName(String? displayName) {
  if (displayName == null || displayName.isEmpty) return null;
  return displayName.split(' ').first;
}

/// Builds the one-line greeting shown in Zone 1.
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

  // Simple returning user
  return '$tod$nameStr.';
}

/// Returns a one-line continuity note referencing yesterday's session, or null.
String? buildContinuity(HomeGreetingData data) {
  if (data.recentSessions.isEmpty) return null;

  final now = DateTime.now();
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final last = data.recentSessions.first;
  final d = last.startedAt;
  if (d == null) return null;

  final lastDay = DateTime(d.year, d.month, d.day);
  if (lastDay == yesterday) {
    return 'last night was ${last.vibe}.';
  }

  return null;
}
