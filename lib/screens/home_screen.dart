
import 'package:flutter/material.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import '../services/app_language.dart';
import '../widgets/weather_background.dart';
import '../widgets/weather_header.dart';
import '../widgets/weather_card.dart';
import '../widgets/forecast_card.dart';
import '../widgets/quick_question.dart';

class HomeScreen extends StatefulWidget {
  final String location;
  final double? latitude;
  final double? longitude;
  final String temperatureUnit;

  final VoidCallback? onLocationTap;
  final VoidCallback? onSettingsTap;
  final void Function(String, WeatherModel?)? onQuestionTap;
  final ValueChanged<WeatherModel?>? onWeatherLoaded;

  const HomeScreen({
    super.key,
    required this.location,
    this.latitude,
    this.longitude,
    this.temperatureUnit = '°C',
    this.onLocationTap,
    this.onSettingsTap,
    this.onQuestionTap,
    this.onWeatherLoaded,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WeatherService _weatherService = WeatherService();

  WeatherModel? _weather;
  bool _isLoading = true;
  String? _error;

  String _t(String value) {
    return AppLanguageScope.of(context).text(value);
  }

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.location != widget.location ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _loadWeather();
    }
  }

  double _convertTemperature(double celsius) {
    if (widget.temperatureUnit == '°F') {
      return (celsius * 9 / 5) + 32;
    }

    return celsius;
  }

  String _temperatureText(double celsius) {
    return '${_convertTemperature(celsius).round()}${widget.temperatureUnit}';
  }

  Future<void> _loadWeather() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lat = widget.latitude;
      final lon = widget.longitude;

      final WeatherModel result;

      if (lat != null && lon != null) {
        result = await _weatherService.getWeatherForCoordinates(
          lat,
          lon,
          location: widget.location,
        );
      } else {
        result = await _weatherService.getWeatherForCity(
          widget.location,
        );
      }

      if (!mounted) return;

      setState(() {
        _weather = result;
        _isLoading = false;
      });

      widget.onWeatherLoaded?.call(result);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
        _weather = null;
      });

      widget.onWeatherLoaded?.call(null);
    }
  }

  String _weatherBackgroundCondition(String condition) {
    final value = condition.toLowerCase();

    if (value.contains('thunder')) return 'storm';

    if (value.contains('rain') ||
        value.contains('drizzle') ||
        value.contains('shower')) {
      return 'rain';
    }

    if (value.contains('fog') || value.contains('mist')) {
      return 'fog';
    }

    if (value.contains('cloud') || value.contains('overcast')) {
      return 'cloudy';
    }

    return 'clear';
  }

  void _askWeatherGPT(String question) {
    widget.onQuestionTap?.call(question, _weather);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WeatherBackground(
        condition: _weather == null
            ? 'clear'
            : _weatherBackgroundCondition(_weather!.condition),
        isNight: _weather?.isNight ?? false,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadWeather,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      WeatherHeader(
                        location: _weather?.location ?? widget.location,
                        onLocationTap: widget.onLocationTap,
                        onSettingsTap: widget.onSettingsTap,
                      ),

                      const SizedBox(height: 22),

                      _SearchLocation(
                        location: widget.location,
                        onTap: widget.onLocationTap,
                        translate: _t,
                      ),

                      const SizedBox(height: 22),

                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_error != null)
                        _ErrorCard(
                          message: _error!,
                          onRetry: _loadWeather,
                          translate: _t,
                        )
                      else if (_weather != null)
                        WeatherCard(
                          temperature: _temperatureText(
                            _weather!.temperature,
                          ),
                          condition: _weather!.condition,
                          feelsLike:
                              '${_t('Feels like')} ${_temperatureText(_weather!.feelsLike)}',
                          humidity: '${_weather!.humidity}%',
                          wind: '${_weather!.windSpeed.round()} km/h',
                          rainChance: '${_weather!.rainChance}%',
                        ),

                      const SizedBox(height: 28),

                      _SectionHeader(
                        title: _t('Ask WeatherGPT'),
                        actionText: _t('Open AI'),
                        onActionTap: () {
                          _askWeatherGPT(
                            'Tell me about the weather in ${widget.location}.',
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      QuickQuestion(
                        question: _t('Will it rain today?'),
                        icon: Icons.cloudy_snowing,
                        onTap: () {
                          _askWeatherGPT(
                            'Will it rain today?',
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      QuickQuestion(
                        question: _t('What should I wear today?'),
                        icon: Icons.checkroom_rounded,
                        onTap: () {
                          _askWeatherGPT(
                            'What should I wear today?',
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      QuickQuestion(
                        question: _t('What will the weather be tomorrow?'),
                        icon: Icons.calendar_month_rounded,
                        onTap: () {
                          _askWeatherGPT(
                            'What will the weather be tomorrow?',
                          );
                        },
                      ),

                      const SizedBox(height: 28),

                      _GlassSection(
                        isDark: isDark,
                        child: _weather == null
                            ? Center(
                                child: Text(
                                  _t('Forecast unavailable'),
                                ),
                              )
                            : ForecastCard(
                                weather: _weather!,
                                temperatureUnit: widget.temperatureUnit,
                              ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchLocation extends StatelessWidget {
  final String location;
  final VoidCallback? onTap;
  final String Function(String) translate;

  const _SearchLocation({
    required this.location,
    required this.translate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.72 : 0.82,
            ),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: Color(0xFF3F7CFF),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  '${translate('Change location')} · $location',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: 0.75,
                    ),
                    fontSize: 15,
                  ),
                ),
              ),

              Icon(
                Icons.location_on_outlined,
                color: theme.colorScheme.onSurface.withValues(
                  alpha: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String Function(String) translate;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
    required this.translate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 40,
            ),

            const SizedBox(height: 12),

            Text(
              message,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(translate('Try again')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback onActionTap;

  const _SectionHeader({
    required this.title,
    required this.actionText,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),

        TextButton(
          onPressed: onActionTap,
          child: Text(actionText),
        ),
      ],
    );
  }
}

class _GlassSection extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _GlassSection({
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: isDark ? 0.58 : 0.70,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.10),
        ),
      ),
      child: child,
    );
  }
}