import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/ai/llm_provider.dart';
import '../../../core/ai/models/llm_message.dart';
import '../../../shared/result.dart';
import '../../decide/domain/ai_pick_model.dart';
import '../domain/dynamic_menu.dart';
import '../domain/menu_prompt_builder.dart';
import 'menu_cache_service.dart';

class MenuRepository {
  MenuRepository(this._llm, this._cache);
  final LlmProvider _llm;
  final MenuCacheService _cache;

  // ── In-memory cache: survives navigation within the session ───────────────
  final Map<String, DynamicMenu> _memory = {};

  // ── In-flight dedup: one AI call per key at a time ────────────────────────
  final Map<String, Future<DynamicMenu>> _inFlight = {};

  Future<DynamicMenu> getMenu({
    required String cacheKey,
    required String vibe,
    required int hour,
    required String dayOfWeek,
    required List<AiPick> recentAccepted,
  }) async {
    // 1. Memory — zero I/O
    final mem = _memory[cacheKey];
    if (mem != null && !mem.isExpired) {
      debugPrint('[MenuAI] HIT memory  key=$cacheKey');
      return mem;
    }

    // 2. Disk — SharedPreferences
    final disk = await _cache.read(cacheKey);
    if (disk != null) {
      _memory[cacheKey] = disk;
      debugPrint('[MenuAI] HIT disk    key=$cacheKey  ai=${disk.isAiGenerated}');
      return disk;
    }

    // 3. Deduplicate in-flight requests for the same key
    final existing = _inFlight[cacheKey];
    if (existing != null) {
      debugPrint('[MenuAI] dedup await key=$cacheKey');
      return existing;
    }

    // 4. Cache miss — generate once, store, reuse
    debugPrint('[MenuAI] GENERATE     key=$cacheKey  vibe=$vibe  bucket=${TimeBucket.fromHour(hour).label}');

    final future = _generate(
      cacheKey: cacheKey,
      vibe: vibe,
      hour: hour,
      dayOfWeek: dayOfWeek,
      recentAccepted: recentAccepted,
    );
    _inFlight[cacheKey] = future;

    try {
      final menu = await future;
      _memory[cacheKey] = menu;
      // Write to disk after returning to caller so the UI doesn't wait on I/O
      _cache.write(menu).ignore();
      return menu;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  void invalidate(String cacheKey) {
    _memory.remove(cacheKey);
    debugPrint('[MenuAI] invalidated  key=$cacheKey');
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<DynamicMenu> _generate({
    required String cacheKey,
    required String vibe,
    required int hour,
    required String dayOfWeek,
    required List<AiPick> recentAccepted,
  }) async {
    try {
      final p = MenuPromptBuilder.build(
        vibe: vibe,
        hour: hour,
        dayOfWeek: dayOfWeek,
        recentAccepted: recentAccepted,
      );

      final result = await _llm.generate(
        LlmRequest(system: p.system, prompt: p.prompt),
      );

      switch (result) {
        case Success(:final data):
          return _parseOrFallback(data, cacheKey: cacheKey, vibe: vibe);
        case Failure(:final error):
          debugPrint('[MenuAI] LLM failure: $error — static fallback');
          return DynamicMenu.fromStatic(vibe, cacheKey);
      }
    } catch (e) {
      debugPrint('[MenuAI] generate error: $e — static fallback');
      return DynamicMenu.fromStatic(vibe, cacheKey);
    }
  }

  DynamicMenu _parseOrFallback(
    String raw, {
    required String cacheKey,
    required String vibe,
  }) {
    try {
      // Strip markdown code fences if the model added them
      final clean = raw
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final json = jsonDecode(clean) as Map<String, dynamic>;
      final menu = DynamicMenu.fromAiResponse(
        json,
        cacheKey: cacheKey,
        vibe: vibe,
      );
      if (menu != null) {
        debugPrint('[MenuAI] parsed OK — ${menu.categories.length} categories');
        return menu;
      }
      debugPrint('[MenuAI] parse returned null — static fallback');
      return DynamicMenu.fromStatic(vibe, cacheKey);
    } catch (e) {
      debugPrint('[MenuAI] JSON parse error: $e — static fallback');
      return DynamicMenu.fromStatic(vibe, cacheKey);
    }
  }
}
