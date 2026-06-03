import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../data/menu_cache_service.dart';
import '../data/menu_repository.dart';
import '../domain/dynamic_menu.dart';
import '../domain/menu_models.dart';
import '../../decide/domain/ai_pick_model.dart';
import '../../decide/providers/decide_providers.dart';
import '../../vibe/providers/session_providers.dart';

// ─── Active pick ──────────────────────────────────────────────────────────────

/// The pick the user has just confirmed — held until the response screen
/// either confirms it (pick persisted) or the user backs out.
class ActivePick {
  const ActivePick({required this.category, required this.option});
  final MenuCategory category;
  final MenuOption option;
}

class ActivePickNotifier extends Notifier<ActivePick?> {
  @override
  ActivePick? build() => null;

  void set(MenuCategory category, MenuOption option) =>
      state = ActivePick(category: category, option: option);

  void clear() => state = null;
}

final activePickProvider =
    NotifierProvider<ActivePickNotifier, ActivePick?>(ActivePickNotifier.new);

// ─── Cache key ────────────────────────────────────────────────────────────────

/// Changes only when vibe, time-bucket, or calendar date changes.
/// Navigation away and back keeps the same key → no regeneration.
final menuCacheKeyProvider = Provider<String>((ref) {
  final session = ref.watch(activeSessionProvider);
  final vibe = session?.vibe ?? 'fomo';
  final uid =
      Supabase.instance.client.auth.currentUser?.id ?? 'anon';
  final now = DateTime.now();
  final bucket = TimeBucket.fromHour(now.hour).label;
  final date =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  return '${uid}_${vibe}_${bucket}_$date';
});

// ─── Infrastructure ───────────────────────────────────────────────────────────

final menuCacheServiceProvider = Provider<MenuCacheService>((_) => MenuCacheService());

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(
    ref.watch(llmProvider),
    ref.watch(menuCacheServiceProvider),
  );
});

// ─── Dynamic menu ─────────────────────────────────────────────────────────────

/// NOT autoDispose — persists for the app session so navigating away and back
/// returns the cached result instantly.
///
/// Rebuilds only when [menuCacheKeyProvider] changes (vibe switch or
/// time-bucket rolls over). All other navigation hits the in-memory cache
/// inside [MenuRepository] and returns without any I/O.
class DynamicMenuNotifier extends AsyncNotifier<DynamicMenu> {
  @override
  Future<DynamicMenu> build() async {
    final key = ref.watch(menuCacheKeyProvider);
    final repo = ref.read(menuRepositoryProvider);
    final session = ref.read(activeSessionProvider);
    final vibe = session?.vibe ?? 'fomo';

    // Fetch recent accepted picks for personalization — best-effort.
    List<AiPick> typedRecent = [];
    try {
      final all = await ref.read(decideRepositoryProvider).recentAiPicks(limit: 6);
      typedRecent = all.where((p) => p.accepted).toList();
    } catch (_) {}

    final now = DateTime.now();
    const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final dayOfWeek = days[now.weekday - 1];

    return repo.getMenu(
      cacheKey: key,
      vibe: vibe,
      hour: now.hour,
      dayOfWeek: dayOfWeek,
      recentAccepted: typedRecent,
    );
  }

  /// Force-regenerate for the current key (e.g. explicit user refresh).
  Future<void> refresh() async {
    final key = ref.read(menuCacheKeyProvider);
    ref.read(menuRepositoryProvider).invalidate(key);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

final dynamicMenuProvider =
    AsyncNotifierProvider<DynamicMenuNotifier, DynamicMenu>(
  DynamicMenuNotifier.new,
);
