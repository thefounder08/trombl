import 'dart:convert';
import 'package:http/http.dart' as http;

/// Open-Meteo weather lookup (free, no API key).
/// Returns a simple condition string, or null on any failure — callers inject
/// a "no outdoor" rule only when a non-null bad-weather value comes back.
abstract final class WeatherService {
  static final Map<String, (String, DateTime)> _geoCache = {};
  static (String? condition, DateTime?) _weatherCache = (null, null);

  static Future<String?> getCondition(String? city) async {
    if (city == null || city.trim().isEmpty) return null;
    try {
      final geo = await _geocode(city.trim());
      if (geo == null) return null;
      final code = await _weatherCode(geo.$1, geo.$2);
      if (code == null) return null;
      return _condition(code);
    } catch (_) {
      return null;
    }
  }

  static Future<(double lat, double lon)?> _geocode(String city) async {
    // Cache geocoding results — cities don't move
    final cached = _geoCache[city.toLowerCase()];
    if (cached != null) {
      final parts = cached.$1.split(',');
      return (double.parse(parts[0]), double.parse(parts[1]));
    }
    final res = await http
        .get(Uri.parse(
            'https://geocoding-api.open-meteo.com/v1/search'
            '?name=${Uri.encodeComponent(city)}&count=1&format=json'))
        .timeout(const Duration(seconds: 3));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final results = body['results'] as List?;
    if (results == null || results.isEmpty) return null;
    final lat = (results[0]['latitude'] as num).toDouble();
    final lon = (results[0]['longitude'] as num).toDouble();
    _geoCache[city.toLowerCase()] = ('$lat,$lon', DateTime.now());
    return (lat, lon);
  }

  static Future<int?> _weatherCode(double lat, double lon) async {
    // Cache weather for 30 minutes — no point hitting the API on every pick
    final (cached, cachedAt) = _weatherCache;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt).inMinutes < 30) {
      return int.tryParse(cached);
    }
    final res = await http
        .get(Uri.parse(
            'https://api.open-meteo.com/v1/forecast'
            '?latitude=$lat&longitude=$lon&current_weather=true'))
        .timeout(const Duration(seconds: 3));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final cw = body['current_weather'] as Map<String, dynamic>?;
    final code = (cw?['weathercode'] as num?)?.toInt();
    if (code != null) _weatherCache = ('$code', DateTime.now());
    return code;
  }

  /// WMO code → trom condition string.
  /// Returns 'clear'/'cloudy' for benign; 'rainy'/'snowy'/'stormy' for bad.
  static String _condition(int code) {
    if (code == 0 || code == 1) return 'clear';
    if (code == 2 || code == 3) return 'cloudy';
    if (code >= 45 && code <= 48) return 'foggy';
    if (code >= 51 && code <= 67) return 'rainy';
    if (code >= 71 && code <= 77) return 'snowy';
    if (code >= 80 && code <= 82) return 'rainy';
    if (code >= 85 && code <= 86) return 'snowy';
    if (code >= 95) return 'stormy';
    return 'clear';
  }
}
