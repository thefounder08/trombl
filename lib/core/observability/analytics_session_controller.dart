import 'package:flutter/widgets.dart';

import 'analytics_repository.dart';

/// Starts/ends an analytics session as the app moves between foreground and
/// background. Owns a [WidgetsBindingObserver] so no screen has to know
/// sessions exist.
///
/// Lifecycle: `resumed` (first time) → `trackAppOpened` + `startSession`;
/// `resumed` (subsequent) → `trackAppForeground`; `paused`/`detached` →
/// `trackAppBackground` + `endSession`.
class AnalyticsSessionController with WidgetsBindingObserver {
  AnalyticsSessionController(this._repository);
  final AnalyticsRepository _repository;

  bool _started = false;

  /// Call once, after `AnalyticsRepository.init()`, before the first frame.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _repository.trackAppOpened();
    await _repository.startSession();
  }

  void dispose() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _repository.trackAppForeground();
        if (_repository.hasEndedSession) {
          _repository.startSession();
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _repository.trackAppBackground();
        _repository.endSession();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }
}
