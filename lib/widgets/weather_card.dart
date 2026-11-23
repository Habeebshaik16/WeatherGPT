
import 'package:flutter/material.dart';

import '../services/app_language.dart';

class WeatherCard extends StatelessWidget {
  final String temperature;
  final String condition;
  final String feelsLike;
  final String humidity;
  final String wind;
  final String rainChance;

  const WeatherCard({
    super.key,
    this.temperature = '28°',
    this.condition = 'Partly Cloudy',
    this.feelsLike = 'Feels like 30°',
    this.humidity = '72%',
    this.wind = '14 km/h',
    this.rainChance = '20%',
  });

  @override
  Widget build(BuildContext context) {
    final language = AppLanguageScope.of(context);

    String t(String value) => language.text(value);

    return Directionality(
      textDirection: language.isRightToLeft
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF3F7CFF),
              Color(0xFF6C63FF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3F7CFF).withValues(alpha: 0.20),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Current Weather'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      temperature,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 58,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ],
                ),

                const Icon(
                  Icons.wb_sunny_rounded,
                  color: Colors.white,
                  size: 72,
                ),
              ],
            ),

            const SizedBox(height: 18),

            Text(
              condition,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              feelsLike,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                _WeatherInfo(
                  icon: Icons.water_drop_rounded,
                  label: t('Humidity'),
                  value: humidity,
                ),

                const SizedBox(width: 12),

                _WeatherInfo(
                  icon: Icons.air_rounded,
                  label: t('Wind'),
                  value: wind,
                ),

                const SizedBox(width: 12),

                _WeatherInfo(
                  icon: Icons.cloudy_snowing,
                  label: t('Rain'),
                  value: rainChance,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),

            const SizedBox(height: 6),

            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
