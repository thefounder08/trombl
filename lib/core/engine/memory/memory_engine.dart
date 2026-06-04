import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which recommendations the user has repeatedly seen/ignored.
/// Rule: if the same action is shown and NOT accepted 5+ times,
/// it receives a significant score penalty in subsequent rounds.
class MemoryEngine {
  static const _prefKey = 'trombl_memory_v1';
  static const _penaltyThreshold = 5;
  static const _penaltyMultiplier = 0.2; // score × 0.2 after threshold

  // In-memory for the session; persisted to SharedPreferences.
  final Map<String, int> _ignoredCount = {};
  bool _loaded = false;

  /// Load from disk (call once at startup).
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefKey) ?? [];
      for (final entry in raw) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          _ignoredCount[parts[0]] = int.tryParse(parts[1]) ?? 0;
        }
      }
      _loaded = true;
      debugPrint('[Memory] loaded ${_ignoredCount.length} entries');
    } catch (e) {
      debugPrint('[Memory] load error: $e');
    }
  }

  /// Record that an action was shown but not accepted.
  Future<void> recordIgnored(String actionId) async {
    _ignoredCount[actionId] = (_ignoredCount[actionId] ?? 0) + 1;
    await _persist();
  }

  /// Record that an action was accepted (reset its ignored count).
  Future<void> recordAccepted(String actionId) async {
    _ignoredCount.remove(actionId);
    await _persist();
  }

  /// Apply memory penalties to a score map.
  Map<String, double> applyPenalties(Map<String, double> scores) {
    final result = Map<String, double>.from(scores);
    for (final entry in _ignoredCount.entries) {
      if (entry.value >= _penaltyThreshold && result.containsKey(entry.key)) {
        result[entry.key] = result[entry.key]! * _penaltyMultiplier;
        debugPrint('[Memory] penalised ${entry.key} '
            '(ignored ${entry.value}x) → ${result[entry.key]!.toStringAsFixed(1)}');
      }
    }
    return result;
  }

  int ignoredCount(String actionId) => _ignoredCount[actionId] ?? 0;

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          _ignoredCount.entries.map((e) => '${e.key}:${e.value}').toList();
      await prefs.setStringList(_prefKey, raw);
    } catch (e) {
      debugPrint('[Memory] persist error: $e');
    }
  }
}
