import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/dynamic_menu.dart';

/// SharedPreferences-backed persistence for generated menus.
/// Cache key format: "{userId}_{vibe}_{bucket}_{YYYYMMDD}"
class MenuCacheService {
  static const _prefix = 'trombl_menu_v1_';

  static String _spKey(String cacheKey) => '$_prefix$cacheKey';

  Future<DynamicMenu?> read(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_spKey(cacheKey));
      if (raw == null) return null;
      final menu = DynamicMenu.fromJsonString(raw);
      if (menu == null || menu.isExpired) {
        // Clean up stale entry silently
        unawaited(prefs.remove(_spKey(cacheKey)));
        return null;
      }
      return menu;
    } catch (e) {
      debugPrint('[MenuCache] read error: $e');
      return null;
    }
  }

  Future<void> write(DynamicMenu menu) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_spKey(menu.cacheKey), menu.toJsonString());
    } catch (e) {
      debugPrint('[MenuCache] write error: $e');
    }
  }

  /// Remove all trombl menu cache entries (e.g. on sign-out).
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stale = prefs.getKeys()
          .where((k) => k.startsWith(_prefix))
          .toList();
      for (final k in stale) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}

void unawaited(Future<void> future) {
  future.catchError((_) {});
}
