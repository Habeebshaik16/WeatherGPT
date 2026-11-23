
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/weather_model.dart';
import '../services/weather_service.dart';
import '../services/app_language.dart';
import '../widgets/quick_question.dart';

class WeatherGPTScreen extends StatefulWidget {
  final String? initialQuestion;
  final String location;
  final WeatherModel? weather;

  const WeatherGPTScreen({
    super.key,
    this.initialQuestion,
    this.location = 'Vijayawada',
    this.weather,
  });

  @override
  State<WeatherGPTScreen> createState() => _WeatherGPTScreenState();
}

class _WeatherGPTScreenState extends State<WeatherGPTScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> messages = [];

  final WeatherService _weatherService = WeatherService();
  final SpeechToText _speechToText = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _audioCompleteSubscription;

  bool _isLoading = false;
  bool _speechInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _voiceRepliesEnabled = true;
  bool _isInitializingSpeech = true;
  bool _isStartingListening = false;
  bool _hasRequestedSpeech = false;
  bool _speechErrorOccurred = false;

  String _speechLocaleId = 'en-IN';
  Future<void>? _voiceInitialization;

  String _speechStatusMessage = '';

  double _soundLevel = 0;

  final List<String> _lastDiscussedLocations = [];

  static const String _apiUrl = 'http://127.0.0.1:8000/chat';
  static const String _speakApiUrl = 'http://127.0.0.1:8000/speak';

  String _t(String value) {
    if (!mounted) return value;
    return AppLanguageScope.of(context).text(value);
  }

  String _speechInputLocaleCode(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'en-IN';
      case 'te':
        return 'te-IN';
      case 'hi':
        return 'hi-IN';
      case 'ta':
        return 'ta-IN';
      case 'bn':
        return 'bn-IN';
      case 'mr':
        return 'mr-IN';
      case 'gu':
        return 'gu-IN';
      case 'kn':
        return 'kn-IN';
      case 'ml':
        return 'ml-IN';
      case 'pa':
        return 'pa-IN';
      case 'ur':
        return 'ur-IN';
      default:
        return languageCode;
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.initialQuestion != null) {
      _controller.text = widget.initialQuestion!;
    }

    _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
      });
    });

    _initializeVoiceFeatures();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isListening) {
      final selectedCode = AppLanguageScope.of(context).selected.code;
      _speechLocaleId = _speechInputLocaleCode(selectedCode);
    }
  }

  // --------------------------------------------------
  // INITIALIZE VOICE FEATURES
  // --------------------------------------------------

  Future<void> _initializeVoiceFeatures() {
    _voiceInitialization ??= _initializeVoiceFeaturesOnce();
    return _voiceInitialization!;
  }

  Future<void> _initializeVoiceFeaturesOnce() async {
    try {
      final available = await _speechToText.initialize(
        debugLogging: true,
        onStatus: (status) {
          if (!mounted) return;

          debugPrint('Speech status: $status');

          setState(() {
            if (status == SpeechToText.listeningStatus) {
              _isListening = true;
              _speechStatusMessage =
                  'Listening in ${_speechLocaleLabel()}... Speak clearly.';
            } else if (status == SpeechToText.doneStatus ||
                status == SpeechToText.notListeningStatus) {
              _isListening = false;

              if (_hasRequestedSpeech && !_speechErrorOccurred) {
                _speechStatusMessage = _controller.text.trim().isNotEmpty
                    ? 'Speech captured. Press Send.'
                    : 'No words received. Tap the microphone and try again.';
              }
            }
          });
        },
        onError: (error) {
          if (!mounted) return;

          debugPrint('Speech recognition error: ${error.errorMsg}');

          final friendlyMessage = _friendlySpeechError(error.errorMsg);

          _speechErrorOccurred = true;

          setState(() {
            _isListening = false;
            _speechStatusMessage = friendlyMessage;
          });

          _showMessage(friendlyMessage);
        },
      );

      if (!mounted) return;

      setState(() {
        _speechInitialized = available;
        _isInitializingSpeech = false;
        _speechStatusMessage = available
            ? 'Voice input ready · ${_speechLocaleLabel()}'
            : 'Speech recognition is unavailable in this browser.';
      });

      debugPrint('Speech recognition available: $available');
      debugPrint('Selected speech locale: $_speechLocaleId');
    } catch (error) {
      debugPrint('Voice initialization failed: $error');

      if (!mounted) return;

      setState(() {
        _speechInitialized = false;
        _isInitializingSpeech = false;
        _speechStatusMessage =
            'Voice initialization failed. Check Chrome microphone access.';
      });
    }
  }

  String _speechLocaleLabel() {
    switch (_speechLocaleId) {
      case 'te-IN':
        return 'Telugu';
      case 'hi-IN':
        return 'Hindi';
      case 'en-US':
        return 'English (US)';
      case 'en-IN':
        return 'English (India)';
      default:
        return AppLanguageScope.of(context).selected.displayName;
    }
  }

  String _friendlySpeechError(String rawError) {
    final error = rawError.toLowerCase().replaceAll('_', '-');

    if (error.contains('no-speech')) {
      return 'No speech detected. Check the selected microphone, speak close to it, and try again.';
    }

    if (error.contains('audio-capture')) {
      return 'Chrome cannot access an audio input. Select a working microphone in Chrome settings.';
    }

    if (error.contains('not-allowed') || error.contains('permission')) {
      return 'Microphone permission is blocked. Allow microphone access for this site in Chrome.';
    }

    if (error.contains('network')) {
      return 'Chrome could not reach its speech recognition service. Check your internet connection.';
    }

    if (error.contains('language-not-supported')) {
      return 'This speech language is not supported by Chrome. Choose another language.';
    }

    if (error.contains('service-not-allowed')) {
      return 'Chrome blocked its speech recognition service. Check browser and Windows speech settings.';
    }

    if (error.contains('aborted')) {
      return 'Voice input was stopped. Tap the microphone to try again.';
    }

    return 'Speech recognition failed: $rawError';
  }

  // --------------------------------------------------
  // START VOICE INPUT
  // --------------------------------------------------

  Future<void> _startListening() async {
    if (_isLoading || _isListening || _isStartingListening) return;

    if (_isInitializingSpeech) {
      _showMessage(
        'Voice recognition is still initializing. Try again in a moment.',
      );
      return;
    }

    _isStartingListening = true;

    try {
      if (_isSpeaking) {
        await _stopSpeaking();
      }

      if (!_speechInitialized) {
        await _initializeVoiceFeatures();
      }

      if (!_speechInitialized) {
        const message =
            'Speech recognition is unavailable. Check Chrome microphone permissions.';

        if (mounted) {
          setState(() {
            _speechStatusMessage = message;
          });
        }

        _showMessage(message);
        return;
      }

      _hasRequestedSpeech = true;
      _speechErrorOccurred = false;

      if (mounted) {
        setState(() {
          _controller.clear();
          _soundLevel = 0;
          _isListening = true;
          _speechStatusMessage =
              'Starting microphone · ${_speechLocaleLabel()}...';
        });
      }

      debugPrint('Starting speech recognition.');
      debugPrint('Speech locale: $_speechLocaleId');

      await _speechToText.listen(
        onResult: _onSpeechResult,
        onSoundLevelChange: _onSoundLevelChange,
        listenOptions: SpeechListenOptions(
          localeId: _speechLocaleId,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 8),
          partialResults: true,
          cancelOnError: false,
          onDevice: false,
          listenMode: ListenMode.dictation,
        ),
      );

      debugPrint(
        'Speech listen request completed. Plugin listening: ${_speechToText.isListening}',
      );
    } catch (error) {
      debugPrint('Microphone start failed: $error');

      if (!mounted) return;

      setState(() {
        _isListening = false;
        _speechStatusMessage =
            'Microphone could not start. Check Chrome microphone settings.';
      });

      _showMessage(_speechStatusMessage);
    } finally {
      _isStartingListening = false;
    }
  }

  // --------------------------------------------------
  // HANDLE RECOGNIZED WORDS
  // --------------------------------------------------

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;

    final recognizedText = result.recognizedWords.trim();

    debugPrint(
      'Recognized speech (${result.finalResult ? 'final' : 'partial'}): $recognizedText',
    );

    if (recognizedText.isEmpty) return;

    setState(() {
      _controller.value = TextEditingValue(
        text: recognizedText,
        selection: TextSelection.collapsed(offset: recognizedText.length),
      );

      _speechStatusMessage = result.finalResult
          ? 'Speech captured. Press Send.'
          : 'Recognizing: $recognizedText';

      if (result.finalResult) {
        _isListening = false;
      }
    });
  }

  // --------------------------------------------------
  // MICROPHONE SOUND LEVEL
  // --------------------------------------------------

  void _onSoundLevelChange(double level) {
    if (!mounted) return;

    setState(() {
      _soundLevel = level;
    });

    debugPrint('Microphone sound level: $level');
  }

  // --------------------------------------------------
  // STOP VOICE INPUT
  // --------------------------------------------------

  Future<void> _stopListening() async {
    try {
      await _speechToText.stop();
    } catch (error) {
      debugPrint('Stopping microphone failed: $error');
    }

    if (!mounted) return;

    setState(() {
      _isListening = false;

      _speechStatusMessage = _controller.text.trim().isNotEmpty
          ? 'Speech recognized. Press Send.'
          : 'No speech was recognized. Try again.';
    });
  }

  Future<void> _toggleListening() async {
    if (_isListening || _speechToText.isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  // --------------------------------------------------
  // AI VOICE RESPONSE
  // --------------------------------------------------

  Future<void> _speakReply(String text) async {
    if (!_voiceRepliesEnabled || text.trim().isEmpty) {
      return;
    }

    try {
      if (_isListening) {
        await _stopListening();
      }

      await _audioPlayer.stop();

      if (!mounted) return;

      final selectedLanguage = AppLanguageScope.of(context).selected;

      setState(() {
        _isSpeaking = true;
      });

      final response = await http
          .post(
            Uri.parse(_speakApiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'language_code': selectedLanguage.code,
              'language_name': selectedLanguage.displayName,
              'voice': 'Kore',
              'voice_style': 'Speak naturally, clearly and smoothly.',
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        throw Exception(
          'Speech generation failed (${response.statusCode}): '
          '${response.body}',
        );
      }

      if (response.bodyBytes.isEmpty) {
        throw Exception('WeatherGPT received an empty audio response.');
      }

      if (!mounted) return;

      await _audioPlayer.play(
        BytesSource(
          response.bodyBytes,
          mimeType: 'audio/wav',
        ),
      );
    } catch (error) {
      debugPrint('Gemini audio playback error: $error');

      if (!mounted) return;

      setState(() {
        _isSpeaking = false;
      });

      _showMessage('Could not play the WeatherGPT voice response.');
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await _audioPlayer.stop();
    } catch (error) {
      debugPrint('Audio stop error: $error');
    }

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
    });
  }

  // --------------------------------------------------
  // ENABLE / DISABLE AI VOICE
  // --------------------------------------------------

  Future<void> _toggleVoiceReplies() async {
    final enable = !_voiceRepliesEnabled;

    setState(() {
      _voiceRepliesEnabled = enable;
    });

    if (!enable) {
      await _stopSpeaking();
      _showMessage('AI voice responses disabled.');
    } else {
      _showMessage('AI voice responses enabled.');
    }
  }

  // --------------------------------------------------
  // SHOW MESSAGE
  // --------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t(message)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --------------------------------------------------
  // LOCATION DETECTION
  // --------------------------------------------------

  String _cleanLocation(String value) {
    String city = value.trim();

    city = city.replaceAll(
      RegExp(
        r'\b(today|tomorrow|tonight|now|currently|'
        r'this week|next week|weather|temperature|'
        r'forecast|climate|rain|wind|humidity|'
        r'please|right now|for the next \d+ days?)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    city = city.replaceAll(
      RegExp(r'^\s*(?:the|in|at|near|for|of)\s+', caseSensitive: false),
      '',
    );

    return city
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[, ]+|[, ]+$'), '')
        .trim();
  }

  List<String> _extractLocations(String message) {
    final text = message.trim();

    final followUpComparison = RegExp(
      r'\b(?:compare|comparing)\s+'
      r'(?:it|that|there|the previous location)\s+'
      r'(?:with|to|and|vs\.?|versus)\s+'
      r'(.+?)(?:[?.!]|$)',
      caseSensitive: false,
    ).firstMatch(text);

    if (followUpComparison != null) {
      final newLocation = _cleanLocation(followUpComparison.group(1)!);

      if (newLocation.isNotEmpty) {
        if (_lastDiscussedLocations.isNotEmpty) {
          return [_lastDiscussedLocations.first, newLocation];
        }

        return [newLocation];
      }
    }

    final comparisonPatterns = [
      RegExp(
        r'\bcompare\s+(.+?)\s+'
        r'\b(?:and|with|vs\.?|versus)\s+'
        r'(.+?)(?:[?.!]|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'\bbetween\s+(.+?)\s+\band\b\s+'
        r'(.+?)(?:[?.!]|$)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in comparisonPatterns) {
      final match = pattern.firstMatch(text);

      if (match != null) {
        final first = _cleanLocation(match.group(1)!);
        final second = _cleanLocation(match.group(2)!);

        if (first.isNotEmpty && second.isNotEmpty) {
          return [first, second];
        }
      }
    }

    final followUpLocation = RegExp(
      r'\b(?:what about|how about|and in|also in)\s+'
      r'(.+?)(?:[?.!]|$)',
      caseSensitive: false,
    ).firstMatch(text);

    if (followUpLocation != null) {
      final city = _cleanLocation(followUpLocation.group(1)!);

      if (city.isNotEmpty) return [city];
    }

    final locationPatterns = [
      RegExp(r'\b(?:in|at|near)\s+(.+?)(?:[?.!]|$)', caseSensitive: false),
      RegExp(r'\b(?:for|of)\s+(.+?)(?:[?.!]|$)', caseSensitive: false),
    ];

    for (final pattern in locationPatterns) {
      final matches = pattern.allMatches(text).toList();

      if (matches.isNotEmpty) {
        final city = _cleanLocation(matches.last.group(1)!);

        if (city.isNotEmpty) return [city];
      }
    }

    final cityFirst = RegExp(
      r'^\s*(.+?)\s+(?:weather|forecast)\s*[?.!]*$',
      caseSensitive: false,
    ).firstMatch(text);

    if (cityFirst != null) {
      final city = _cleanLocation(cityFirst.group(1)!);

      if (city.isNotEmpty) return [city];
    }

    return [];
  }

  List<String> _resolveLocations(String message) {
    final detected = _extractLocations(message);

    if (detected.isNotEmpty) {
      _lastDiscussedLocations
        ..clear()
        ..addAll(detected);

      return detected;
    }

    if (_lastDiscussedLocations.isNotEmpty) {
      return List<String>.from(_lastDiscussedLocations);
    }

    final selected = widget.location.trim();

    if (selected.isEmpty) return [];

    _lastDiscussedLocations.add(selected);

    return [selected];
  }

  bool _sameLocation(String first, String second) {
    final a = first.toLowerCase().trim();
    final b = second.toLowerCase().trim();

    if (a.isEmpty || b.isEmpty) return false;

    return a == b || a.startsWith('$b,') || b.startsWith('$a,');
  }

  // --------------------------------------------------
  // FORMAT WEATHER
  // --------------------------------------------------

  String _formatWeather(WeatherModel weather) {
    final buffer = StringBuffer();

    buffer.writeln('WEATHER DATA SOURCE: Open-Meteo');
    buffer.writeln('Location: ${weather.location}');
    buffer.writeln('Local time: ${weather.localTime}');
    buffer.writeln('Timezone: ${weather.timezone}');
    buffer.writeln('Condition: ${weather.condition}');
    buffer.writeln('Temperature: ${weather.temperature} °C');
    buffer.writeln('Feels like: ${weather.feelsLike} °C');
    buffer.writeln('Humidity: ${weather.humidity}%');
    buffer.writeln('Wind speed: ${weather.windSpeed} km/h');
    buffer.writeln('Rain probability: ${weather.rainChance}%');

    buffer.writeln('\nUPCOMING HOURLY FORECAST:');

    final start = weather.currentHourIndex;

    final end = (start + 24).clamp(0, weather.hourlyForecast.length);

    for (int i = start; i < end; i++) {
      final hour = weather.hourlyForecast[i];

      buffer.writeln(
        'Time: ${hour['time']}, '
        'Temperature: ${hour['temperature']} °C, '
        'Rain probability: ${hour['rainChance']}%, '
        'Weather code: ${hour['weatherCode']}',
      );
    }

    buffer.writeln('\nSEVEN-DAY FORECAST:');

    for (final day in weather.forecast) {
      buffer.writeln(
        'Date: ${day['date']}, '
        'Maximum: ${day['maxTemperature']} °C, '
        'Minimum: ${day['minTemperature']} °C, '
        'Rain probability: ${day['rainChance']}%, '
        'Weather code: ${day['weatherCode']}',
      );
    }

    buffer.writeln(
      '\nData fetched at UTC: '
      '${weather.fetchedAtUtc.toIso8601String()}',
    );

    return buffer.toString();
  }

  // --------------------------------------------------
  // FETCH WEATHER
  // --------------------------------------------------

  Future<String> _getQuestionWeatherContext(List<String> locations) async {
    final buffer = StringBuffer();

    if (locations.isEmpty) {
      return 'No location was detected.';
    }

    for (final place in locations.take(3)) {
      if (place.isEmpty) continue;

      if (widget.weather != null &&
          _sameLocation(place, widget.weather!.location)) {
        buffer.writeln(_formatWeather(widget.weather!));
        continue;
      }

      if (place.toLowerCase() == 'current location' &&
          widget.weather != null) {
        buffer.writeln(_formatWeather(widget.weather!));
        continue;
      }

      try {
        final weather = await _weatherService.getWeatherForCity(place);

        buffer.writeln('\nLIVE WEATHER DATA FROM OPEN-METEO:');
        buffer.writeln(_formatWeather(weather));
      } catch (error) {
        buffer.writeln('\nLIVE WEATHER LOOKUP FAILED FOR: $place');
        debugPrint('Weather fetching failed for $place: $error');
      }
    }

    return buffer.toString();
  }

  // --------------------------------------------------
  // CONVERSATION HISTORY
  // --------------------------------------------------

  List<Map<String, String>> _buildConversationHistory() {
    final recentMessages = messages
        .where((message) => !message.isError)
        .toList();

    final start = recentMessages.length > 12 ? recentMessages.length - 12 : 0;

    return recentMessages
        .skip(start)
        .map(
          (message) => {
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.text,
          },
        )
        .toList();
  }

  // --------------------------------------------------
  // SEND MESSAGE
  // --------------------------------------------------

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();

    if (message.isEmpty || _isLoading) return;

    final responseLanguage =
      AppLanguageScope.of(context).selected.displayName;

    if (_isSpeaking) {
      await _stopSpeaking();
    }

    if (_isListening) {
      await _stopListening();
    }

    final conversationHistory = _buildConversationHistory();
    final activeLocations = _resolveLocations(message);

    setState(() {
      messages.add(_ChatMessage(text: message, isUser: true));
      _controller.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final weatherContext = await _getQuestionWeatherContext(activeLocations);

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'location': activeLocations.join(' and '),
              'weather_context': weatherContext,
              'conversation_history': conversationHistory,
                'response_language': responseLanguage,
            }),
          )
          .timeout(const Duration(seconds: 120));

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final String reply =
            data['reply']?.toString() ?? 'No response received.';

        if (!mounted) return;

        setState(() {
          messages.add(_ChatMessage(text: reply, isUser: false));
        });

        if (_voiceRepliesEnabled) {
          unawaited(_speakReply(reply));
        }
      } else {
        final String error =
            data['detail']?.toString() ??
            'Unable to get a response from WeatherGPT.';

        _addError(error);
      }
    } on http.ClientException {
      _addError(
        'Cannot connect to WeatherGPT backend. '
        'Please check whether the Python server is running.',
      );
    } on FormatException {
      _addError(
        'The backend returned an invalid response. '
        'Please try again.',
      );
    } catch (error) {
      _addError(
        'Unable to retrieve weather information. '
        'Please check your internet connection and try again.',
      );

      debugPrint('WeatherGPT error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _scrollToBottom();
      }
    }
  }

  // --------------------------------------------------
  // ERROR MESSAGE
  // --------------------------------------------------

  void _addError(String message) {
    if (!mounted) return;

    setState(() {
      messages.add(
        _ChatMessage(
          text: _t(message),
          isUser: false,
          isError: true,
        ),
      );
    });
  }

  // --------------------------------------------------
  // SCROLL
  // --------------------------------------------------

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _useQuestion(String question) {
    setState(() {
      _controller.text = question;
    });
  }

  // --------------------------------------------------
  // DISPOSE
  // --------------------------------------------------

  @override
  void dispose() {
    _speechToText.cancel();
    _audioCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // MAIN UI
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final language = AppLanguageScope.of(context);

    String t(String value) => language.text(value);

    return Directionality(
      textDirection: language.isRightToLeft
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: theme.colorScheme.onSurface,
          titleSpacing: 18,
          title: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3F7CFF), Color(0xFF6C63FF)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3F7CFF).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.cloud_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WeatherGPT',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${t('Weather assistant')} · ${widget.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              tooltip: t('Speech input language'),
              initialValue: _speechLocaleId,
              onSelected: (localeId) async {
                if (_isListening || _speechToText.isListening) {
                  await _stopListening();
                }

                if (!mounted) return;

                setState(() {
                  _speechLocaleId = localeId;
                  _speechStatusMessage =
                      'Voice input language: ${_speechLocaleLabel()}';
                });
              },
              itemBuilder: (context) => [
                if (!const ['en-IN', 'en-US', 'te-IN', 'hi-IN']
                    .contains(_speechLocaleId))
                  PopupMenuItem(
                    value: _speechLocaleId,
                    child: Text(language.selected.displayName),
                  ),
                PopupMenuItem(
                  value: 'en-IN',
                  child: Text(t('English (India)')),
                ),
                PopupMenuItem(
                  value: 'en-US',
                  child: Text(t('English (US)')),
                ),
                PopupMenuItem(
                  value: 'te-IN',
                  child: Text(t('Telugu')),
                ),
                PopupMenuItem(
                  value: 'hi-IN',
                  child: Text(t('Hindi')),
                ),
              ],
              icon: Icon(
                Icons.translate_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            IconButton(
              onPressed: _toggleVoiceReplies,
              tooltip: _voiceRepliesEnabled
                  ? t('Disable AI voice')
                  : t('Enable AI voice'),
              icon: Icon(
                _voiceRepliesEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: _voiceRepliesEnabled
                    ? const Color(0xFF3F7CFF)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_isSpeaking)
              IconButton(
                onPressed: _stopSpeaking,
                tooltip: t('Stop speaking'),
                icon: const Icon(
                  Icons.stop_circle_outlined,
                  color: Colors.redAccent,
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            _WeatherBackground(isDark: isDark),
            SafeArea(
              child: Column(
                children: [
                  if (_isListening)
                    _ListeningStatus(
                      message: _speechStatusMessage,
                      soundLevel: _soundLevel,
                    ),
                  Expanded(
                    child: messages.isEmpty
                        ? _WelcomeView(
                            location: widget.location,
                            onQuestionTap: _useQuestion,
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(
                              18,
                              80,
                              18,
                              20,
                            ),
                            itemCount:
                                messages.length + (_isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index < messages.length) {
                                final chatMessage = messages[index];

                                if (chatMessage.isUser) {
                                  return _UserMessage(
                                    message: chatMessage.text,
                                  );
                                }

                                return _AIMessage(
                                  message: chatMessage.text,
                                  isError: chatMessage.isError,
                                );
                              }

                              return const _TypingIndicator();
                            },
                          ),
                  ),
                  if (_speechStatusMessage.isNotEmpty &&
                      !_isListening &&
                      !_isInitializingSpeech)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      child: Text(
                        t(_speechStatusMessage),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                              (_speechStatusMessage.toLowerCase().contains(
                                        'no speech',
                                      ) ||
                                      _speechStatusMessage.toLowerCase().contains(
                                        'failed',
                                      ) ||
                                      _speechStatusMessage.toLowerCase().contains(
                                        'blocked',
                                      ) ||
                                      _speechStatusMessage.toLowerCase().contains(
                                        'cannot',
                                      ) ||
                                      _speechStatusMessage.toLowerCase().contains(
                                        'could not',
                                      ) ||
                                      _speechStatusMessage.toLowerCase().contains(
                                        'unavailable',
                                      ))
                                  ? Colors.redAccent
                                  : theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  _MessageInput(
                    controller: _controller,
                    onSend: _sendMessage,
                    onMicTap: _toggleListening,
                    isLoading: _isLoading,
                    isListening: _isListening,
                    voiceAvailable: _speechInitialized,
                    isInitializing: _isInitializingSpeech,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// LISTENING STATUS
// --------------------------------------------------

class _ListeningStatus extends StatelessWidget {
  final String message;
  final double soundLevel;

  const _ListeningStatus({
    required this.message,
    required this.soundLevel,
  });

  @override
  Widget build(BuildContext context) {
    final language = AppLanguageScope.of(context);
    final normalizedLevel = ((soundLevel + 2) / 12).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3F7CFF).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.mic_rounded,
                color: Color(0xFF3F7CFF),
                size: 18,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  language.text(message),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(
                height: 15,
                width: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF3F7CFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          LinearProgressIndicator(
            value: normalizedLevel,
            minHeight: 4,
            borderRadius: BorderRadius.circular(5),
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            color: const Color(0xFF3F7CFF),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------
// CHAT MESSAGE MODEL
// --------------------------------------------------

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}

// --------------------------------------------------
// WEATHER BACKGROUND
// --------------------------------------------------

class _WeatherBackground extends StatelessWidget {
  final bool isDark;

  const _WeatherBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF101A35),
                    Color(0xFF0D1117),
                    Color(0xFF090D14),
                  ]
                : const [
                    Color(0xFFEAF4FF),
                    Color(0xFFF5F8FF),
                    Color(0xFFF5F7FB),
                  ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -50,
              child: Container(
                height: 230,
                width: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF3F7CFF)
                          .withValues(alpha: isDark ? 0.18 : 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 150,
              left: -100,
              child: Icon(
                Icons.cloud_rounded,
                size: 190,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.035)
                    : Colors.white.withValues(alpha: 0.65),
              ),
            ),
            Positioned(
              top: 260,
              right: -70,
              child: Icon(
                Icons.cloud_rounded,
                size: 150,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// WELCOME SCREEN
// --------------------------------------------------

class _WelcomeView extends StatelessWidget {
  final String location;
  final Function(String) onQuestionTap;

  const _WelcomeView({
    required this.location,
    required this.onQuestionTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = AppLanguageScope.of(context);

    String t(String value) => language.text(value);

    return Directionality(
      textDirection: language.isRightToLeft
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 82, 20, 24),
        child: Column(
          children: [
            Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3F7CFF), Color(0xFF6C63FF)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3F7CFF).withValues(alpha: 0.25),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              t('Hi! I’m WeatherGPT'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t(
                'Your intelligent weather assistant.\n'
                'Ask me about weather anywhere in the world.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t('Try asking'),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 13),
            QuickQuestion(
              question: t('Will it rain today in Delhi?'),
              icon: Icons.umbrella_outlined,
              onTap: () => onQuestionTap('Will it rain today in Delhi?'),
            ),
            const SizedBox(height: 10),
            QuickQuestion(
              question: t('What should I wear today in London?'),
              icon: Icons.checkroom_outlined,
              onTap: () => onQuestionTap('What should I wear today in London?'),
            ),
            const SizedBox(height: 10),
            QuickQuestion(
              question: t('How will the weather be tomorrow in Tokyo?'),
              icon: Icons.calendar_today_outlined,
              onTap: () =>
                  onQuestionTap('How will the weather be tomorrow in Tokyo?'),
            ),
            const SizedBox(height: 10),
            QuickQuestion(
              question: t('Compare Delhi and Mumbai weather'),
              icon: Icons.compare_arrows_rounded,
              onTap: () => onQuestionTap('Compare Delhi and Mumbai weather'),
            ),
            const SizedBox(height: 10),
            QuickQuestion(
              question: t('Explain how thunderstorms form'),
              icon: Icons.thunderstorm_outlined,
              onTap: () => onQuestionTap('Explain how thunderstorms form'),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// USER MESSAGE
// --------------------------------------------------

class _UserMessage extends StatelessWidget {
  final String message;

  const _UserMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3F7CFF), Color(0xFF6C63FF)],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(19),
            topRight: Radius.circular(19),
            bottomLeft: Radius.circular(19),
            bottomRight: Radius.circular(5),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3F7CFF).withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------
// AI MESSAGE
// --------------------------------------------------

class _AIMessage extends StatelessWidget {
  final String message;
  final bool isError;

  const _AIMessage({
    required this.message,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF202B40) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(19),
            topRight: Radius.circular(19),
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(19),
          ),
          border: Border.all(
            color: isError
                ? Colors.red.withValues(alpha: 0.35)
                : theme.colorScheme.primary.withValues(alpha: 0.10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.auto_awesome_rounded,
              color: isError ? Colors.redAccent : const Color(0xFF6C63FF),
              size: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError
                      ? Colors.redAccent
                      : theme.colorScheme.onSurface,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// TYPING INDICATOR
// --------------------------------------------------

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final language = AppLanguageScope.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF202B40) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(width: 11),
            Text(
              language.text('WeatherGPT is thinking...'),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// MESSAGE INPUT WITH MICROPHONE
// --------------------------------------------------

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onMicTap;
  final bool isLoading;
  final bool isListening;
  final bool voiceAvailable;
  final bool isInitializing;

  const _MessageInput({
    required this.controller,
    required this.onSend,
    required this.onMicTap,
    required this.isLoading,
    required this.isListening,
    required this.voiceAvailable,
    required this.isInitializing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final language = AppLanguageScope.of(context);

    String t(String value) => language.text(value);

    return Directionality(
      textDirection: language.isRightToLeft
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF202B40).withValues(alpha: 0.96)
                  : const Color(0xFFFFFFFF).withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFF3F7CFF).withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.25 : 0.07,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: isLoading || isInitializing ? null : onMicTap,
                  tooltip: isListening
                      ? t('Stop recording')
                      : t('Start voice input'),
                  icon: Icon(
                    isListening
                        ? Icons.mic_rounded
                        : isInitializing
                            ? Icons.hourglass_empty_rounded
                            : Icons.mic_none_rounded,
                    color: isListening
                        ? Colors.redAccent
                        : voiceAvailable
                            ? const Color(0xFF3F7CFF)
                            : Colors.grey,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isLoading,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF202638),
                      fontSize: 15,
                    ),
                    cursorColor: const Color(0xFF3F7CFF),
                    decoration: InputDecoration(
                      hintText: isListening
                          ? t('Listening... Speak now')
                          : t('Ask WeatherGPT...'),
                      hintStyle: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.50)
                            : const Color(0xFF596579).withValues(alpha: 0.65),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3F7CFF), Color(0xFF6C63FF)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: IconButton(
                    onPressed: isLoading ? null : onSend,
                    tooltip: t('Send message'),
                    icon: Icon(
                      isLoading
                          ? Icons.hourglass_empty_rounded
                          : Icons.arrow_upward_rounded,
                      color: Colors.white,
                    ),
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
