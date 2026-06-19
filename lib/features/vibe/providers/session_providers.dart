import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/providers.dart';
import '../../../shared/result.dart';
import '../../../shared/models/models.dart';
import '../../../shared/repositories/session_repository.dart';

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(supabaseProvider));
});

/// Holds the currently active session (null until a vibe is picked).
class ActiveSessionNotifier extends Notifier<Session?> {
  @override
  Session? build() {
    // Reset so the vibe screen blanks correctly on each auth change.
    ref.read(_sessionRestoredProvider.notifier).state = false;
    // Restore today's unwrapped session on every cold start / auth change.
    Future.microtask(_tryRestore);
    return null;
  }

  Future<void> _tryRestore() async {
    try {
      final client = ref.read(supabaseProvider);
      if (client.auth.currentUser == null) return;
      final existing =
          await ref.read(sessionRepositoryProvider).todaySession();
      if (existing != null) state = existing;
    } finally {
      // Always mark restored — even if the DB call throws — so the vibe
      // screen never gets stuck on a blank screen.
      ref.read(_sessionRestoredProvider.notifier).state = true;
    }
  }

  Future<String?> start(String vibe, {String? city}) async {
    final res =
        await ref.read(sessionRepositoryProvider).startSession(vibe, city: city);
    switch (res) {
      case Success(:final data):
        state = data;
        return null;
      case Failure(:final error):
        return error;
    }
  }

  /// Flip fomo ↔ jomo on the active session (updates DB + local state).
  Future<void> switchVibe() async {
    final session = state;
    if (session == null) return;
    final newVibe = session.vibe == 'fomo' ? 'jomo' : 'fomo';
    await ref.read(sessionRepositoryProvider).switchVibe(session.id, newVibe);
    state = session.copyWith(vibe: newVibe);
  }

  void clear() => state = null;
}

final activeSessionProvider =
    NotifierProvider<ActiveSessionNotifier, Session?>(ActiveSessionNotifier.new);

/// True once the initial DB restore attempt has finished (whether or not a
/// session was found). Used by VibeScreen to avoid a flash of the picker
/// before we know if the user already has a session today.
final _sessionRestoredProvider = StateProvider<bool>((_) => false);
final sessionRestoredProvider = Provider<bool>(
  (ref) => ref.watch(_sessionRestoredProvider),
);

/// Consecutive days with a wrapped session (streak counter).
final streakProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(sessionRepositoryProvider);
  final all = await repo.recentSessions(days: 60);
  final wrapped = all.where((s) => s.wrappedAt != null).toList()
    ..sort((a, b) =>
        (b.startedAt ?? DateTime(0)).compareTo(a.startedAt ?? DateTime(0)));
  if (wrapped.isEmpty) return 0;

  int streak = 0;
  DateTime? prevDay;
  for (final s in wrapped) {
    final d = s.startedAt;
    if (d == null) continue;
    final day = DateTime(d.year, d.month, d.day);
    if (prevDay == null) {
      prevDay = day;
      streak = 1;
    } else {
      final diff = prevDay.difference(day).inDays;
      if (diff == 1) {
        streak++;
        prevDay = day;
      } else if (diff == 0) {
        continue; // duplicate same-day session
      } else {
        break; // gap — streak ends
      }
    }
  }
  return streak;
});

/// The user's city from their profile, cached in memory.
final cityProvider =
    StateNotifierProvider<CityNotifier, String?>((ref) {
  return CityNotifier(ref.watch(sessionRepositoryProvider));
});

class CityNotifier extends StateNotifier<String?> {
  CityNotifier(this._repo) : super(null) {
    _load();
  }
  final SessionRepository _repo;

  Future<void> _load() async {
    final profile = await _repo.getProfile();
    if (profile?.city != null) state = profile!.city;
  }

  Future<void> setCity(String city) async {
    state = city;
    await _repo.updateProfile(city: city);
  }
}
