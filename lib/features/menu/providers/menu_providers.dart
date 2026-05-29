import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/menu_models.dart';

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
