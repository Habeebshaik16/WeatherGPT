
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_model.dart';
import 'weather_notification_service_stub.dart'
    if (dart.library.js_interop) 'weather_notification_service_web.dart'
    as notifications;

enum WeatherAlertLevel {
  advisory,
  warning,
  severe,
}

class WeatherAlert {
  final String id;
  final String title;
  final String message;
  final String location;
  final String category;
  final WeatherAlertLevel level;
  final DateTime createdAt;

  const WeatherAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.location,
    required this.category,
    required this.level,
    required this.createdAt,
  });
}

class WeatherAlertService {
  static const String _enabledKey = 'weather_alerts_enabled';
  static const String _categoriesKey = 'weather_alert_categories';
  static const String _lastAlertTimeKeyPrefix =
      'weather_alert_last_time_';

  static const Duration _alertCooldown = Duration(hours: 3);

  final SharedPreferencesAsync _preferences =
      SharedPreferencesAsync();

  bool _enabled = true;

  final Map<String, bool> _categories = {
    'storms': true,
    'rain': true,
    'heat': true,
    'cold': true,
    'wind': true,
    'fog': true,
    'snow': true,
    'dust': true,
  };

  bool get enabled => _enabled;

  Map<String, bool> get categories =>
      Map.unmodifiable(_categories);

  Future<void> initialize() async {
    _enabled = await _preferences.getBool(_enabledKey) ?? true;

    final savedCategories =
        await _preferences.getStringList(_categoriesKey);

    if (savedCategories != null) {
      for (final category in _categories.keys) {
        _categories[category] =
            savedCategories.contains(category);
      }
    }
  }

  Future<bool> setEnabled(bool value) async {
    _enabled = value;

    await _preferences.setBool(_enabledKey, value);

    if (!value) return true;

    return notifications.requestNotificationPermission();
  }

  Future<bool> setCategory(
    String category,
    bool value,
  ) async {
    if (!_categories.containsKey(category)) {
      return false;
    }

    _categories[category] = value;

    final enabledCategories = _categories.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    await _preferences.setStringList(
      _categoriesKey,
      enabledCategories,
    );

    return true;
  }

  Future<bool> requestNotificationPermission() async {
    return notifications.requestNotificationPermission();
  }

  List<WeatherAlert> detectAlerts(WeatherModel weather) {
    if (!_enabled) return [];

    final alerts = <WeatherAlert>[];
    final now = DateTime.now();

    void addAlert({
      required String id,
      required String category,
      required String title,
      required String message,
      required WeatherAlertLevel level,
    }) {
      if (_categories[category] != true) return;

      alerts.add(
        WeatherAlert(
          id: '${weather.location}_$id',
          title: title,
          message: message,
          location: weather.location,
          category: category,
          level: level,
          createdAt: now,
        ),
      );
    }

    final code = weather.weatherCode;

    // Thunderstorms
    if (code >= 95 && code <= 99) {
      addAlert(
        id: 'thunderstorm',
        category: 'storms',
        title: 'Thunderstorm Alert',
        message:
            'Thunderstorms are detected in ${weather.location}. Stay indoors and avoid exposed areas.',
        level: code >= 96
            ? WeatherAlertLevel.severe
            : WeatherAlertLevel.warning,
      );
    }

    // Heavy rain
    if (code == 65 || code == 67 || code == 82) {
      addAlert(
        id: 'heavy_rain',
        category: 'rain',
        title: 'Heavy Rain Alert',
        message:
            'Heavy or intense rain is reported in ${weather.location}. Be careful around flooded roads.',
        level: WeatherAlertLevel.warning,
      );
    }

    // Hail
    if (code == 96 || code == 99) {
      addAlert(
        id: 'hail',
        category: 'storms',
        title: 'Hail Alert',
        message:
            'Hail is indicated in the forecast for ${weather.location}. Protect yourself and vehicles.',
        level: WeatherAlertLevel.severe,
      );
    }

    // Extreme heat
    if (weather.temperature >= 40) {
      addAlert(
        id: 'extreme_heat',
        category: 'heat',
        title: 'Extreme Heat Advisory',
        message:
            'The temperature is ${weather.temperature.toStringAsFixed(1)}°C in ${weather.location}. Stay hydrated and avoid prolonged outdoor activity.',
        level: WeatherAlertLevel.warning,
      );
    }

    // Extreme cold
    if (weather.temperature <= 0) {
      addAlert(
        id: 'extreme_cold',
        category: 'cold',
        title: 'Extreme Cold Advisory',
        message:
            'The temperature is ${weather.temperature.toStringAsFixed(1)}°C in ${weather.location}. Dress warmly and watch for icy surfaces.',
        level: WeatherAlertLevel.warning,
      );
    }

    // Strong wind
    if (weather.windSpeed >= 50) {
      addAlert(
        id: 'strong_wind',
        category: 'wind',
        title: 'Strong Wind Alert',
        message:
            'Wind speed is ${weather.windSpeed.toStringAsFixed(0)} km/h in ${weather.location}. Secure loose outdoor objects.',
        level: weather.windSpeed >= 75
            ? WeatherAlertLevel.severe
            : WeatherAlertLevel.warning,
      );
    }

    // Fog
    if (code == 45 || code == 48) {
      addAlert(
        id: 'fog',
        category: 'fog',
        title: 'Fog Advisory',
        message:
            'Fog is reported in ${weather.location}. Reduce speed and use appropriate lights while travelling.',
        level: WeatherAlertLevel.advisory,
      );
    }

    // Snow and ice
    if ((code >= 71 && code <= 77) ||
        code == 85 ||
        code == 86) {
      addAlert(
        id: 'snow',
        category: 'snow',
        title: 'Snow and Ice Advisory',
        message:
            'Snow is reported in ${weather.location}. Watch for slippery roads and surfaces.',
        level: WeatherAlertLevel.warning,
      );
    }

    // Dust and sand
    if (code >= 30 && code <= 35) {
      addAlert(
        id: 'dust_storm',
        category: 'dust',
        title: 'Dust Storm Advisory',
        message:
            'Dusty or blowing sand conditions are indicated in ${weather.location}. Avoid unnecessary outdoor activity.',
        level: WeatherAlertLevel.warning,
      );
    }

    return alerts;
  }

  Future<void> checkWeather(WeatherModel weather) async {
    if (!_enabled) return;

    final alerts = detectAlerts(weather);

    for (final alert in alerts) {
      await _sendNotification(alert);
    }
  }

  Future<void> _sendNotification(WeatherAlert alert) async {
    final storageKey =
        '$_lastAlertTimeKeyPrefix${alert.id}';

    final previousTime =
        await _preferences.getInt(storageKey);

    final now = DateTime.now().millisecondsSinceEpoch;

    if (previousTime != null) {
      final elapsed =
          Duration(milliseconds: now - previousTime);

      if (elapsed < _alertCooldown) return;
    }

    if (!notifications.notificationPermissionGranted) {
      return;
    }

    try {
      notifications.showNotification(
        alert.title,
        alert.message,
        alert.id,
      );

      await _preferences.setInt(storageKey, now);
    } catch (_) {
      // Notification may be unavailable or blocked.
    }
  }
}
