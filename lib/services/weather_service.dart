
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/location_model.dart';
import '../models/weather_model.dart';

class WeatherService {
  static const Duration _timeout = Duration(seconds: 15);

  Future<List<LocationModel>> searchLocations(String query) async {
    final searchQuery = query.trim();

    if (searchQuery.isEmpty) {
      return [];
    }

    try {
      final uri = Uri.https(
        'geocoding-api.open-meteo.com',
        '/v1/search',
        {
          'name': searchQuery,
          'count': '10',
          'language': 'en',
          'format': 'json',
        },
      );

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Could not search for locations.');
      }

      final data = jsonDecode(response.body);

      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid location search response.');
      }

      final results = data['results'];

      if (results is! List || results.isEmpty) {
        return [];
      }

      return results
          .whereType<Map>()
          .map(
            (item) => LocationModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception('Unable to search locations. Please try again.');
    }
  }

  Future<WeatherModel> getWeatherForCity(String city) async {
    final query = city.trim();

    if (query.isEmpty) {
      throw Exception('Please enter a city name.');
    }

    final locations = await searchLocations(query);

    if (locations.isEmpty) {
      throw Exception(
        'City not found. Please check the spelling and try again.',
      );
    }

    final normalizedQuery = query.toLowerCase();

    final exactMatches = locations.where((place) {
      return place.name.trim().toLowerCase() == normalizedQuery;
    }).toList();

    final selectedLocation = exactMatches.isNotEmpty
        ? exactMatches.first
        : locations.first;

    return getWeatherForLocation(selectedLocation);
  }

  Future<WeatherModel> getWeatherForLocation(
    LocationModel place,
  ) async {
    return getWeatherForCoordinates(
      place.latitude,
      place.longitude,
      location: place.displayName,
    );
  }

  Future<WeatherModel> getWeatherForCoordinates(
    double latitude,
    double longitude, {
    String? location,
  }) async {
    if (latitude < -90 || latitude > 90 ||
        longitude < -180 || longitude > 180) {
      throw Exception('Invalid location coordinates.');
    }

    final uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m,precipitation,weather_code',
        'hourly':
            'temperature_2m,weather_code,precipitation_probability',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset',
        'forecast_days': '7',
        'timezone': 'auto',
      },
    );

    try {
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Could not load weather data.');
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid weather response.');
      }

      final data = decoded;

      final current = data['current'];
      final hourly = data['hourly'];
      final daily = data['daily'];

      if (current is! Map<String, dynamic> ||
          hourly is! Map<String, dynamic> ||
          daily is! Map<String, dynamic>) {
        throw Exception('Weather information is incomplete.');
      }

      final currentTime = current['time']?.toString();

      if (currentTime == null || currentTime.isEmpty) {
        throw Exception('Current weather time is unavailable.');
      }

      final now = DateTime.parse(currentTime);

      final sunriseList = daily['sunrise'];
      final sunsetList = daily['sunset'];

      if (sunriseList is! List ||
          sunsetList is! List ||
          sunriseList.isEmpty ||
          sunsetList.isEmpty) {
        throw Exception('Sunrise and sunset information is unavailable.');
      }

      final sunrise = DateTime.parse(sunriseList.first.toString());
      final sunset = DateTime.parse(sunsetList.first.toString());

      final isNight = now.isBefore(sunrise) || !now.isBefore(sunset);

      final hourlyTimes = _requiredList(hourly, 'time');
      final hourlyTemperatures = _requiredList(hourly, 'temperature_2m');
      final hourlyCodes = _requiredList(hourly, 'weather_code');
      final hourlyRain = _requiredList(
        hourly,
        'precipitation_probability',
      );

      final hourlyLength = [
        hourlyTimes.length,
        hourlyTemperatures.length,
        hourlyCodes.length,
        hourlyRain.length,
      ].reduce((a, b) => a < b ? a : b);

      if (hourlyLength == 0) {
        throw Exception('Hourly forecast is unavailable.');
      }

      int currentHourIndex = hourlyTimes.indexOf(currentTime);

      if (currentHourIndex == -1) {
        currentHourIndex = 0;

        for (var i = 0; i < hourlyLength; i++) {
          final time = DateTime.parse(hourlyTimes[i].toString());

          if (!time.isAfter(now)) {
            currentHourIndex = i;
          } else {
            break;
          }
        }
      }

      currentHourIndex = currentHourIndex
          .clamp(0, hourlyLength - 1)
          .toInt();

      final hourlyForecast = <Map<String, dynamic>>[];

      for (var i = 0; i < hourlyLength; i++) {
        hourlyForecast.add({
          'time': hourlyTimes[i],
          'temperature': hourlyTemperatures[i],
          'weatherCode': hourlyCodes[i],
          'rainChance': hourlyRain[i],
        });
      }

      final dailyDates = _requiredList(daily, 'time');
      final dailyCodes = _requiredList(daily, 'weather_code');
      final maximumTemperatures = _requiredList(
        daily,
        'temperature_2m_max',
      );
      final minimumTemperatures = _requiredList(
        daily,
        'temperature_2m_min',
      );
      final dailyRain = _requiredList(
        daily,
        'precipitation_probability_max',
      );

      final dailyLength = [
        dailyDates.length,
        dailyCodes.length,
        maximumTemperatures.length,
        minimumTemperatures.length,
        dailyRain.length,
      ].reduce((a, b) => a < b ? a : b);

      if (dailyLength == 0) {
        throw Exception('Daily forecast is unavailable.');
      }

      final forecast = <Map<String, dynamic>>[];

      for (var i = 0; i < dailyLength; i++) {
        forecast.add({
          'date': dailyDates[i],
          'weatherCode': dailyCodes[i],
          'rainChance': dailyRain[i],
          'maxTemperature': maximumTemperatures[i],
          'minTemperature': minimumTemperatures[i],
        });
      }

      final codeValue = current['weather_code'];
      final temperatureValue = current['temperature_2m'];
      final feelsLikeValue = current['apparent_temperature'];
      final humidityValue = current['relative_humidity_2m'];
      final windValue = current['wind_speed_10m'];

      if (codeValue is! num ||
          temperatureValue is! num ||
          feelsLikeValue is! num ||
          humidityValue is! num ||
          windValue is! num) {
        throw Exception('Current weather data is incomplete.');
      }

      final code = codeValue.toInt();

      final rainValue = hourlyRain[currentHourIndex];
      final rainChance = rainValue is num ? rainValue.toInt() : 0;

      return WeatherModel(
        location: location ?? 'Current Location',
        temperature: temperatureValue.toDouble(),
        condition: getWeatherDescription(code),
        feelsLike: feelsLikeValue.toDouble(),
        humidity: humidityValue.toInt(),
        windSpeed: windValue.toDouble(),
        rainChance: rainChance,
        weatherCode: code,
        isNight: isNight,
        localTime: currentTime,
        timezone: data['timezone']?.toString() ?? 'Unknown',
        hourlyForecast: hourlyForecast,
        forecast: forecast,
        currentHourIndex: currentHourIndex,
        fetchedAtUtc: DateTime.now().toUtc(),
      );
    } on FormatException {
      throw Exception('Weather service returned invalid data.');
    } on http.ClientException {
      throw Exception('Unable to connect to the weather service.');
    } catch (error) {
      if (error is Exception) {
        rethrow;
      }

      throw Exception('Unable to load weather. Please try again.');
    }
  }

  List<dynamic> _requiredList(
    Map<String, dynamic> data,
    String key,
  ) {
    final value = data[key];

    if (value is! List) {
      throw FormatException('Missing weather field: $key');
    }

    return value;
  }

  String getWeatherDescription(int code) {
    if (code == 0) return 'Clear Sky';
    if (code == 1) return 'Mainly Clear';
    if (code == 2) return 'Partly Cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rainy';
    if (code >= 71 && code <= 77) return 'Snowy';
    if (code >= 80 && code <= 82) return 'Rain Showers';
    if (code == 85 || code == 86) return 'Snow Showers';
    if (code >= 95 && code <= 99) return 'Thunderstorm';

    return 'Unknown';
  }

  String getBackgroundCondition(int code) {
    if (code >= 95 && code <= 99) return 'storm';
    if (code >= 51 && code <= 82) return 'rain';
    if (code == 45 || code == 48) return 'fog';
    if (code == 2 || code == 3) return 'cloudy';

    return 'clear';
  }
}
