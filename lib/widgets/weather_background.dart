import 'package:flutter/material.dart';

class WeatherBackground extends StatelessWidget {
  final Widget child;
  final String condition;
  final bool isNight;

  const WeatherBackground({
    super.key,
    required this.child,
    this.condition = 'clear',
    this.isNight = false,
  });

  String get backgroundPath {
    final weather = condition.toLowerCase();

    if (weather.contains('storm') ||
        weather.contains('thunder')) {
      return isNight
          ? 'assets/backgrounds/storm_night.jpg'
          : 'assets/backgrounds/storm_day.jpg';
    }

    if (weather.contains('rain') ||
        weather.contains('drizzle') ||
        weather.contains('shower')) {
      return isNight
          ? 'assets/backgrounds/rain_night.jpg'
          : 'assets/backgrounds/rain_day.jpg';
    }

    if (weather.contains('fog') ||
        weather.contains('mist')) {
      return 'assets/backgrounds/fog_day.jpg';
    }

    if (weather.contains('cloud') ||
        weather.contains('overcast')) {
      return isNight
          ? 'assets/backgrounds/cloudy_night.jpg'
          : 'assets/backgrounds/cloudy_day.jpg';
    }

    return isNight
        ? 'assets/backgrounds/clear_night.jpg'
        : 'assets/backgrounds/clear_day.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          backgroundPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: isDark
                  ? const Color(0xFF0D1117)
                  : const Color(0xFFDCEEFF),
            );
          },
        ),

        Container(
          color: Colors.black.withValues(alpha: 0.12),
        ),

        child,
      ],
    );
  }
}