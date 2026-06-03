import 'dart:convert';

import 'menu_data.dart';
import 'menu_models.dart';

/// Time bucket used as part of the cache key and prompt context.
enum TimeBucket {
  night,     // 22–5
  morning,   // 5–11
  afternoon, // 11–17
  evening;   // 17–22

  static TimeBucket fromHour(int h) {
    if (h >= 5 && h < 11) return morning;
    if (h >= 11 && h < 17) return afternoon;
    if (h >= 17 && h < 22) return evening;
    return night;
  }

  String get label => name; // 'morning' etc.

  /// The hour when this bucket ends (exclusive), used to set expiresAt.
  DateTime get endsAt {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      morning   => today.add(const Duration(hours: 11)),
      afternoon => today.add(const Duration(hours: 17)),
      evening   => today.add(const Duration(hours: 22)),
      night     => DateTime(now.year, now.month, now.day + 1, 5),
    };
  }
}

/// The full AI-generated (or static-fallback) menu for one vibe + bucket.
class DynamicMenu {
  const DynamicMenu({
    required this.categories,
    required this.newDrop,
    required this.isAiGenerated,
    required this.cacheKey,
    required this.expiresAt,
  });

  final List<MenuCategory> categories;
  final MenuCategory newDrop;

  /// false when this is a static fallback (AI failed / quota hit).
  final bool isAiGenerated;
  final String cacheKey;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  // ─── Serialisation (for SharedPreferences) ───────────────────────────────

  String toJsonString() => jsonEncode(_toMap());

  Map<String, dynamic> _toMap() => {
        'categories': categories.map(_catToMap).toList(),
        'new_drop': _catToMap(newDrop, isNewDrop: true),
        'is_ai_generated': isAiGenerated,
        'cache_key': cacheKey,
        'expires_at': expiresAt.toIso8601String(),
      };

  /// Restore from a SharedPreferences-persisted JSON string.
  static DynamicMenu? fromJsonString(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return DynamicMenu(
        categories: (map['categories'] as List)
            .map((c) => _catFromMap(c as Map<String, dynamic>))
            .toList(),
        newDrop: _catFromMap(
          map['new_drop'] as Map<String, dynamic>,
          isNewDrop: true,
        ),
        isAiGenerated: map['is_ai_generated'] as bool? ?? true,
        cacheKey: map['cache_key'] as String? ?? '',
        expiresAt: DateTime.parse(map['expires_at'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  /// Parse the raw JSON object returned by the AI (no metadata fields).
  static DynamicMenu? fromAiResponse(
    Map<String, dynamic> json, {
    required String cacheKey,
    required String vibe,
  }) {
    try {
      final rawCats = json['categories'] as List?;
      final rawDrop = json['new_drop'] as Map<String, dynamic>?;
      if (rawCats == null || rawDrop == null) return null;
      if (rawCats.length < 4) return null;

      final categories = rawCats
          .take(4)
          .map((c) => _catFromAi(c as Map<String, dynamic>))
          .toList();
      final newDrop = _catFromAi(rawDrop, isNewDrop: true);

      if (categories.any((c) => c.options.length < 2)) return null;

      final bucket = TimeBucket.fromHour(DateTime.now().hour);
      return DynamicMenu(
        categories: categories,
        newDrop: newDrop,
        isAiGenerated: true,
        cacheKey: cacheKey,
        expiresAt: bucket.endsAt,
      );
    } catch (_) {
      return null;
    }
  }

  /// Static fallback — never shows blank content, never throws.
  factory DynamicMenu.fromStatic(String vibe, String cacheKey) {
    final bucket = TimeBucket.fromHour(DateTime.now().hour);
    return DynamicMenu(
      categories: TromblMenu.core(vibe),
      newDrop: TromblMenu.newDrop(vibe),
      isAiGenerated: false,
      cacheKey: cacheKey,
      expiresAt: bucket.endsAt,
    );
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  static Map<String, dynamic> _catToMap(
    MenuCategory c, {
    bool isNewDrop = false,
  }) =>
      {
        'id': c.id,
        'emoji': c.emoji,
        'title': c.title,
        'sub': c.sub,
        'is_new_drop': c.isNewDrop || isNewDrop,
        'options': c.options
            .map((o) => {'id': o.id, 'label': o.label, 'tag': o.tag})
            .toList(),
      };

  static MenuCategory _catFromMap(
    Map<String, dynamic> j, {
    bool isNewDrop = false,
  }) =>
      MenuCategory(
        id: j['id'] as String? ?? 'cat_${j['title']}',
        emoji: j['emoji'] as String? ?? '✨',
        title: j['title'] as String? ?? '',
        sub: j['sub'] as String? ?? '',
        isNewDrop: j['is_new_drop'] as bool? ?? isNewDrop,
        options: ((j['options'] as List?) ?? [])
            .map((o) => MenuOption(
                  id: o['id'] as String? ?? 'opt_${o['label']}',
                  label: o['label'] as String? ?? '',
                  tag: _safeTag(o['tag'] as String?),
                ))
            .toList(),
      );

  static MenuCategory _catFromAi(
    Map<String, dynamic> j, {
    bool isNewDrop = false,
  }) {
    final title = (j['title'] as String? ?? '').toLowerCase().trim();
    final id = 'ai_${title.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z_]'), '')}';
    final rawOpts = (j['options'] as List?) ?? [];
    return MenuCategory(
      id: id,
      emoji: j['emoji'] as String? ?? '✨',
      title: title,
      sub: (j['sub'] as String? ?? '').toLowerCase().trim(),
      isNewDrop: isNewDrop,
      options: rawOpts.take(4).map((o) {
        final label = (o['label'] as String? ?? '').toLowerCase().trim();
        return MenuOption(
          id: 'aio_${label.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z_]'), '')}',
          label: label,
          tag: _safeTag(o['tag'] as String?),
        );
      }).toList(),
    );
  }

  static const _validTags = {
    'squad', 'discover', 'order in', 'rest', 'content', 'solo',
  };

  static String _safeTag(String? t) =>
      _validTags.contains(t) ? t! : 'solo';
}
