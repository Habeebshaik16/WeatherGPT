import 'package:flutter/material.dart';
import '../models/weather_model.dart';

class ForecastCard extends StatelessWidget {
  final WeatherModel weather;
  final String temperatureUnit;

  const ForecastCard({
    super.key,
    required this.weather,
    this.temperatureUnit = '°C',
  });

  double _convertTemperature(double celsius) {
    if (temperatureUnit == '°F') {
      return (celsius * 9 / 5) + 32;
    }
    return celsius;
  }

  String _temperature(dynamic value) {
    if (value == null) return '--$temperatureUnit';

    final celsius = (value as num).toDouble();

    return '${_convertTemperature(celsius).round()}$temperatureUnit';
  }

  IconData _weatherIcon(dynamic code) {
    final weatherCode = (code as num?)?.toInt() ?? 0;

    if (weatherCode == 0) return Icons.wb_sunny_rounded;

    if (weatherCode == 1 || weatherCode == 2) {
      return Icons.cloud_queue_rounded;
    }

    if (weatherCode == 3) return Icons.cloud_rounded;

    if (weatherCode == 45 || weatherCode == 48) {
      return Icons.foggy;
    }

    if (weatherCode >= 51 && weatherCode <= 67) {
      return Icons.grain_rounded;
    }

    if (weatherCode >= 71 && weatherCode <= 77) {
      return Icons.ac_unit_rounded;
    }

    if (weatherCode >= 80 && weatherCode <= 82) {
      return Icons.water_drop_rounded;
    }

    if (weatherCode >= 85 && weatherCode <= 86) {
      return Icons.ac_unit_rounded;
    }

    if (weatherCode >= 95) {
      return Icons.thunderstorm_rounded;
    }

    return Icons.cloud_rounded;
  }

  String _formatTime(dynamic value) {
    if (value == null) return '--';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');

    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '$displayHour:$minute $period';
  }

  String _formatDay(dynamic value) {
    if (value == null) return '--';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return days[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hourlyForecast = weather.hourlyForecast;
    final dailyForecast = weather.forecast;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hourly Forecast',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 15),

        SizedBox(
          height: 125,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: hourlyForecast.length > 24
                ? 24
                : hourlyForecast.length,
            itemBuilder: (context, index) {
              final hour = hourlyForecast[
                (weather.currentHourIndex + index)
                    .clamp(0, hourlyForecast.length - 1)
              ];

              return Container(
                width: 82,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(
                    alpha: 0.75,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTime(hour['time']),
                      style: const TextStyle(fontSize: 11),
                    ),

                    Icon(
                      _weatherIcon(hour['weatherCode']),
                      color: const Color(0xFF3F7CFF),
                      size: 25,
                    ),

                    Text(
                      _temperature(hour['temperature']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 25),

        const Text(
          '7-Day Forecast',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 15),

        ...dailyForecast.map((day) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    _formatDay(day['date']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                Icon(
                  _weatherIcon(day['weatherCode']),
                  color: const Color(0xFF3F7CFF),
                  size: 23,
                ),

                const SizedBox(width: 12),

                Expanded(
                  flex: 2,
                  child: Text(
                    '${day['rainChance'] ?? 0}% rain',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                ),

                Text(
                  '${_temperature(day['minTemperature'])} / ${_temperature(day['maxTemperature'])}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}