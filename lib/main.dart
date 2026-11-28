
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models/location_model.dart';
import 'models/weather_model.dart';
import 'screens/home_screen.dart';
import 'screens/weathergpt_screen.dart';
import 'screens/location_screen.dart';
import 'screens/settings_screen.dart';
import 'themes/app_theme.dart';
import 'services/app_language.dart';
import 'services/weather_alert_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WeatherGPTApp());
}

class WeatherGPTApp extends StatefulWidget {
  const WeatherGPTApp({super.key});

  @override
  State<WeatherGPTApp> createState() => _WeatherGPTAppState();
}

class _WeatherGPTAppState extends State<WeatherGPTApp> {
  late final AppLanguageController _languageController;
  late final WeatherAlertService _weatherAlertService;

  bool isDarkMode = false;
  bool _showSplash = true;

  String temperatureUnit = '°C';
  String selectedLocation = 'Visakhapatnam';

  LocationModel? selectedPlace;
  WeatherModel? currentWeather;

  String? pendingQuestion;

  int questionRequestId = 0;
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    _languageController = AppLanguageController();
    _weatherAlertService = WeatherAlertService();

    unawaited(_languageController.initialize());
    unawaited(_weatherAlertService.initialize());
  }

  void _finishSplash() {
    if (!mounted) return;

    setState(() {
      _showSplash = false;
    });
  }

  void _changeLocation(LocationModel place) {
    setState(() {
      selectedPlace = place;
      selectedLocation = place.displayName;
      currentWeather = null;
      selectedIndex = 0;
    });
  }

  void _updateWeather(WeatherModel? weather) {
    if (!mounted) return;

    setState(() {
      currentWeather = weather;
    });

    if (weather != null) {
      unawaited(_weatherAlertService.checkWeather(weather));
    }
  }

  void _openLocation() {
    setState(() {
      selectedIndex = 2;
    });
  }

  void _openSettings() {
    setState(() {
      selectedIndex = 3;
    });
  }

  void _openWeatherGPT(String question, WeatherModel? weather) {
    setState(() {
      pendingQuestion = question;

      if (weather != null) {
        currentWeather = weather;
      }

      questionRequestId++;
      selectedIndex = 1;
    });
  }

  void _changeTheme(bool value) {
    setState(() {
      isDarkMode = value;
    });
  }

  void _changeTemperatureUnit(String value) {
    if (value != '°C' && value != '°F') return;

    setState(() {
      temperatureUnit = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppLanguageScope(
      controller: _languageController,
      child: AnimatedBuilder(
        animation: _languageController,
        builder: (context, child) {
          final language = _languageController;

          return MaterialApp(
            title: 'WeatherGPT',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
            locale: language.locale,
            supportedLocales: AppLanguageController.languages
                .map((o) => o.locale)
                .toList(),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            localeResolutionCallback: (locale, supportedLocales) {
              if (locale == null) {
                return const Locale('en');
              }

              for (final supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale.languageCode) {
                  return supportedLocale;
                }
              }

              return const Locale('en');
            },
            home: _showSplash
                ? WeatherSplashScreen(onFinished: _finishSplash)
                : Scaffold(
                    backgroundColor: Colors.transparent,
                    body: IndexedStack(
                      index: selectedIndex,
                      children: [
                        HomeScreen(
                          location: selectedLocation,
                          latitude: selectedPlace?.latitude,
                          longitude: selectedPlace?.longitude,
                          temperatureUnit: temperatureUnit,
                          onLocationTap: _openLocation,
                          onSettingsTap: _openSettings,
                          onQuestionTap: _openWeatherGPT,
                          onWeatherLoaded: _updateWeather,
                        ),
                        WeatherGPTScreen(
                          key: ValueKey(questionRequestId),
                          initialQuestion: pendingQuestion,
                          location: selectedLocation,
                          weather: currentWeather,
                        ),
                        LocationScreen(
                          selectedLocation: selectedLocation,
                          onLocationSelected: _changeLocation,
                        ),
                        SettingsScreen(
                          isDarkMode: isDarkMode,
                          onDarkModeChanged: _changeTheme,
                          temperatureUnit: temperatureUnit,
                          onTemperatureUnitChanged:
                              _changeTemperatureUnit,
                          alertService: _weatherAlertService,
                        ),
                      ],
                    ),
                    bottomNavigationBar: NavigationBar(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (index) {
                        setState(() {
                          selectedIndex = index;
                        });
                      },
                      destinations: [
                        NavigationDestination(
                          icon: const Icon(Icons.home_outlined),
                          selectedIcon: const Icon(Icons.home_rounded),
                          label: language.text('Home'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.cloud_outlined),
                          selectedIcon: const Icon(Icons.cloud_rounded),
                          label: language.text('WeatherGPT'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.location_on_outlined),
                          selectedIcon:
                              const Icon(Icons.location_on_rounded),
                          label: language.text('Location'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.settings_outlined),
                          selectedIcon:
                              const Icon(Icons.settings_rounded),
                          label: language.text('Settings'),
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _languageController.dispose();
    super.dispose();
  }
}

class WeatherSplashScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const WeatherSplashScreen({
    super.key,
    required this.onFinished,
  });

  @override
  State<WeatherSplashScreen> createState() =>
      _WeatherSplashScreenState();
}

class _WeatherSplashScreenState extends State<WeatherSplashScreen> {
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();

    _splashTimer = Timer(
      const Duration(milliseconds: 2500),
      widget.onFinished,
    );
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF061B49),
              Color(0xFF0755A8),
              Color(0xFF16A9DB),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(38),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withValues(alpha: 0.35),
                      blurRadius: 35,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(38),
                  child: Image.asset(
                    'assets/icon/weather_gpt_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                  children: [
                    TextSpan(
                      text: 'Weather',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: 'GPT',
                      style: TextStyle(color: Color(0xFF32E5FF)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Your Smart Weather Companion',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Powered by AI',
                style: TextStyle(
                  color: Color(0xFF9BEAFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 38),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 25,
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Created by',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Habeeb Shaik',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.cyanAccent,
              ),

              const SizedBox(height: 18),

              const Text(
                'Stay Informed. Stay Ahead.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 35),
            ],
          ),
        ),
      ),
    );
  }
}
