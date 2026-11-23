class WeatherModel {
  final String location;
  final double temperature;
  final String condition;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int rainChance;
  final int weatherCode;
  final bool isNight;

  final String localTime;
  final String timezone;
  final List<Map<String, dynamic>> hourlyForecast;
  final List<Map<String, dynamic>> forecast;
  final int currentHourIndex;
  final DateTime fetchedAtUtc;

  WeatherModel({
    required this.location,
    required this.temperature,
    required this.condition,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.rainChance,
    required this.weatherCode,
    required this.isNight,
    this.localTime = '',
    this.timezone = 'Unknown',
    this.hourlyForecast = const [],
    this.forecast = const [],
    this.currentHourIndex = 0,
    DateTime? fetchedAtUtc,
  }) : fetchedAtUtc = fetchedAtUtc ?? DateTime.now().toUtc();
}