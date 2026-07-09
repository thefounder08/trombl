import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which "did u actually do it?" task popups have already been shown,
/// so a task is never nagged about twice — same SharedPreferences-backed
/// persistence approach as [PendingJoinService], just keyed per-task instead
/// of a single slot.
class TaskPopupSeenStore {
  static const _key = 'seen_task_popups';

  static Future<bool> hasSeen(String taskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key) ?? const []).contains(taskId);
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen(String taskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList(_key) ?? const [];
      if (seen.contains(taskId)) return;
      await prefs.setStringList(_key, [...seen, taskId]);
    } catch (_) {}
  }
}
