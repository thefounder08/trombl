import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../core/services/task_popup_seen_store.dart';
import '../decide/providers/decide_providers.dart';
import '../vibe/providers/session_providers.dart';
import 'domain/checkin_item.dart';
import 'presentation/task_wrapup_sheet.dart';

/// On every app-foreground, checks for an open-loop task — an accepted AI
/// pick nobody's confirmed done/skipped yet ([DecideRepository.pendingCheckins]),
/// or a menu pick still unresolved in the current *unwrapped* session
/// ([SessionRepository.picksForSessions]) — and, if its wrap-up popup
/// hasn't already been shown, surfaces the "did u actually do it?" bottom
/// sheet. Once a session is wrapped, its picks are already finalized by
/// Wrap Up, so they're excluded here. A plain [WidgetsBindingObserver]
/// owned by the app root — same shape as [AnalyticsSessionController] — so
/// no screen needs to know this exists.
class TaskWrapupController with WidgetsBindingObserver {
  TaskWrapupController(this._ref);
  final WidgetRef _ref;

  bool _checking = false;

  void start() => WidgetsBinding.instance.addObserver(this);

  void dispose() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[TaskWrapup] lifecycle=$state');
    if (state == AppLifecycleState.resumed) _maybePrompt();
  }

  Future<void> _maybePrompt() async {
    if (_checking) return;
    _checking = true;
    try {
      final aiPending =
          await _ref.read(decideRepositoryProvider).pendingCheckins(limit: 5);

      final session = _ref.read(activeSessionProvider);
      var pickPending = <CheckinPickItem>[];
      if (session != null && session.wrappedAt == null) {
        final picks = await _ref
            .read(sessionRepositoryProvider)
            .picksForSessions([session.id]);
        pickPending =
            picks.where((p) => !p.done).map(CheckinPickItem.new).toList();
      }

      final candidates = <CheckinItem>[
        ...aiPending.map(CheckinAiPickItem.new),
        ...pickPending,
      ];
      debugPrint('[TaskWrapup] candidates found ${candidates.length}: '
          '${candidates.map((c) => c.id).toList()}');

      for (final task in candidates) {
        if (await TaskPopupSeenStore.hasSeen(task.id)) {
          debugPrint('[TaskWrapup] ${task.id} already seen, skipping');
          continue;
        }
        await TaskPopupSeenStore.markSeen(task.id);
        final ctx = appRouter?.routerDelegate.navigatorKey.currentContext;
        debugPrint('[TaskWrapup] showing sheet for ${task.id}, ctx=$ctx');
        if (ctx != null && ctx.mounted) {
          // AiPick carries its own vibe (may differ from the current
          // session, e.g. after a vibe switch); Pick has none, so fall
          // back to the active session's.
          final vibe = switch (task) {
            CheckinAiPickItem(:final aiPick) => aiPick.vibe,
            CheckinPickItem() => session?.vibe ?? 'fomo',
          };
          await showTaskWrapupSheet(ctx, task, vibe: vibe);
        }
        break; // one popup at a time
      }
    } catch (e) {
      debugPrint('[TaskWrapup] error: $e');
    } finally {
      _checking = false;
    }
  }
}
