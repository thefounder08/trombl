import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/repositories/session_repository.dart';
import '../../../shared/result.dart';

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(supabaseProvider));
});

/// Holds the currently active session (null until a vibe is picked).
class ActiveSessionNotifier extends Notifier<Session?> {
  @override
  Session? build() => null;

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

  void clear() => state = null;
}

final activeSessionProvider =
    NotifierProvider<ActiveSessionNotifier, Session?>(ActiveSessionNotifier.new);
