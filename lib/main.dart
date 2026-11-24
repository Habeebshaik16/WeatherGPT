
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
            home: Scaffold(
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
                  onTemperatureUnitChanged: _changeTemperatureUnit,
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
                    selectedIcon: const Icon(Icons.location_on_rounded),
                    label: language.text('Location'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: const Icon(Icons.settings_rounded),
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
