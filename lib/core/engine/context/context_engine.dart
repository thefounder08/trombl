import '../../../core/services/weather_service.dart';
import 'context_models.dart';
import 'human_rhythm_engine.dart';

/// Assembles a ContextSnapshot from raw inputs.
/// Pure, synchronous once weather is resolved (weather is I/O).
abstract final class ContextEngine {
  static const _days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  /// Build from the current moment. Fetches weather if city is provided.
  static Future<ContextSnapshot> build({
    required String vibe,
    String? city,
    String? moodText,
  }) async {
    final now = DateTime.now();
    final dayOfWeek = _days[now.weekday - 1];
    final dayType = HumanRhythmEngine.dayTypeFor(dayOfWeek);
    final period = HumanRhythmEngine.periodFor(now.hour, dayType);
    final rhythm = HumanRhythmEngine.derive(period);
    final weather = await WeatherService.getCondition(city);

    return ContextSnapshot(
      period: period,
      dayType: dayType,
      dayOfWeek: dayOfWeek,
      hour: now.hour,
      vibe: vibe,
      rhythm: rhythm,
      weather: weather,
      city: city,
      moodText: moodText,
    );
  }

  /// Synchronous build for contexts where weather is already resolved.
  static ContextSnapshot buildSync({
    required String vibe,
    required String? weather,
    String? city,
    String? moodText,
  }) {
    final now = DateTime.now();
    final dayOfWeek = _days[now.weekday - 1];
    final dayType = HumanRhythmEngine.dayTypeFor(dayOfWeek);
    final period = HumanRhythmEngine.periodFor(now.hour, dayType);
    final rhythm = HumanRhythmEngine.derive(period);

    return ContextSnapshot(
      period: period,
      dayType: dayType,
      dayOfWeek: dayOfWeek,
      hour: now.hour,
      vibe: vibe,
      rhythm: rhythm,
      weather: weather,
      city: city,
      moodText: moodText,
    );
  }
}
