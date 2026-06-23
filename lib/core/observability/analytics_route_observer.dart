import 'package:flutter/widgets.dart';

import 'analytics_repository.dart';

/// Drop into `GoRouter(observers: [...])` for automatic screen-view
/// tracking — no screen needs a manual `trackScreenView` call. Reads the
/// route's `settings.name`, which GoRouter sets to the matched location
/// (e.g. `/home`) automatically, so no `name:` has to be added to every
/// `GoRoute` either.
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver(this._repository);
  final AnalyticsRepository _repository;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _report(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _report(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) _report(previousRoute);
  }

  void _report(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    _repository.trackScreenView(
      screenName: name,
      screenClass: _screenClassFor(name),
    );
  }

  /// `/plan/123` → `PlanDetailScreen`-ish label derived from the path
  /// segment, without needing a lookup table kept in sync with every route.
  String _screenClassFor(String routeName) {
    final clean = routeName.split('?').first;
    final segments = clean.split('/').where((s) => s.isNotEmpty && !s.startsWith(':')).toList();
    if (segments.isEmpty) return 'RootScreen';
    final words = segments.last.split(RegExp(r'[-_]'));
    final pascal = words.map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1)).join();
    return '${pascal}Screen';
  }
}
