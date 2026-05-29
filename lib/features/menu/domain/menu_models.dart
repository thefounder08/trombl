import 'package:flutter/foundation.dart';

/// A single option inside a category.
/// [tag] is one of: "squad" | "discover" | "order in" | "rest" | "content" | "coming soon"
@immutable
class MenuOption {
  const MenuOption({
    required this.id,
    required this.label,
    required this.tag,
  });
  final String id;
  final String label;
  final String tag;

  bool get isComingSoon => tag == 'coming soon';
}

/// A top-level category grouping several options.
@immutable
class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.emoji,
    required this.title,
    required this.sub,
    required this.options,
    this.isNewDrop = false,
  });
  final String id;
  final String emoji;
  final String title;
  final String sub;
  final List<MenuOption> options;

  /// True for the rotating "new this week" drop.
  final bool isNewDrop;
}
