
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguageOption {
  final String code;
  final String name;
  final String nativeName;

  const AppLanguageOption(this.code, this.name, this.nativeName);

  Locale get locale {
    final parts = code.split('-');

    return parts.length > 1
        ? Locale.fromSubtags(
            languageCode: parts[0],
            countryCode: parts[1],
          )
        : Locale(parts[0]);
  }

  String get displayName =>
      nativeName == name ? name : '$name · $nativeName';
}

class AppLanguageController extends ChangeNotifier {
  AppLanguageController({
    this.baseUrl = 'http://127.0.0.1:8000',
  });

  final String baseUrl;

  final SharedPreferencesAsync _preferences =
      SharedPreferencesAsync();

  final Map<String, String> _translations = {};
  final Set<String> _pendingTexts = {};

  // English is the default language.
  AppLanguageOption _selected =
      const AppLanguageOption('en', 'English', 'English');

  bool _isTranslating = false;
  bool _flushScheduled = false;
  bool _retryScheduled = false;

  String? _lastError;

  Timer? _retryTimer;
  int _retryAttempt = 0;

  static const int _maximumRetries = 2;

  AppLanguageOption get selected => _selected;
  String get languageCode => _selected.code;
  String get languageName => _selected.name;
  Locale get locale => _selected.locale;
  bool get isTranslating => _isTranslating;
  String? get lastError => _lastError;

  Map<String, String> get translations =>
      Map.unmodifiable(_translations);

  bool get isRightToLeft => const {
        'ar',
        'fa',
        'he',
        'iw',
        'ur',
        'ps',
        'sd',
        'ug',
        'yi',
      }.contains(languageCode);

  // --------------------------------------------------
  // SUPPORTED LANGUAGES
  // --------------------------------------------------

  static const List<AppLanguageOption> languages = [
    AppLanguageOption('af', 'Afrikaans', 'Afrikaans'),
    AppLanguageOption('sq', 'Albanian', 'Shqip'),
    AppLanguageOption('am', 'Amharic', 'አማርኛ'),
    AppLanguageOption('ar', 'Arabic', 'العربية'),
    AppLanguageOption('hy', 'Armenian', 'Հայերեն'),
    AppLanguageOption('as', 'Assamese', 'অসমীয়া'),
    AppLanguageOption('az', 'Azerbaijani', 'Azərbaycanca'),
    AppLanguageOption('eu', 'Basque', 'Euskara'),
    AppLanguageOption('be', 'Belarusian', 'Беларуская'),
    AppLanguageOption('bn', 'Bengali', 'বাংলা'),
    AppLanguageOption('bs', 'Bosnian', 'Bosanski'),
    AppLanguageOption('bg', 'Bulgarian', 'Български'),
    AppLanguageOption('my', 'Burmese', 'မြန်မာ'),
    AppLanguageOption('ca', 'Catalan', 'Català'),
    AppLanguageOption('zh-CN', 'Chinese (Simplified)', '简体中文'),
    AppLanguageOption('zh-TW', 'Chinese (Traditional)', '繁體中文'),
    AppLanguageOption('hr', 'Croatian', 'Hrvatski'),
    AppLanguageOption('cs', 'Czech', 'Čeština'),
    AppLanguageOption('da', 'Danish', 'Dansk'),
    AppLanguageOption('nl', 'Dutch', 'Nederlands'),
    AppLanguageOption('en', 'English', 'English'),
    AppLanguageOption('et', 'Estonian', 'Eesti'),
    AppLanguageOption('fil', 'Filipino', 'Filipino'),
    AppLanguageOption('fi', 'Finnish', 'Suomi'),
    AppLanguageOption('fr', 'French', 'Français'),
    AppLanguageOption('fy', 'Frisian', 'Frysk'),
    AppLanguageOption('gl', 'Galician', 'Galego'),
    AppLanguageOption('ka', 'Georgian', 'ქართული'),
    AppLanguageOption('de', 'German', 'Deutsch'),
    AppLanguageOption('el', 'Greek', 'Ελληνικά'),
    AppLanguageOption('gn', 'Guarani', 'Avañe’ẽ'),
    AppLanguageOption('gu', 'Gujarati', 'ગુજરાતી'),
    AppLanguageOption('ha', 'Hausa', 'Hausa'),
    AppLanguageOption('he', 'Hebrew', 'עברית'),
    AppLanguageOption('hi', 'Hindi', 'हिन्दी'),
    AppLanguageOption('hu', 'Hungarian', 'Magyar'),
    AppLanguageOption('is', 'Icelandic', 'Íslenska'),
    AppLanguageOption('id', 'Indonesian', 'Bahasa Indonesia'),
    AppLanguageOption('ga', 'Irish', 'Gaeilge'),
    AppLanguageOption('it', 'Italian', 'Italiano'),
    AppLanguageOption('ja', 'Japanese', '日本語'),
    AppLanguageOption('kn', 'Kannada', 'ಕನ್ನಡ'),
    AppLanguageOption('km', 'Khmer', 'ខ្មែរ'),
    AppLanguageOption('ko', 'Korean', '한국어'),
    AppLanguageOption('ky', 'Kyrgyz', 'Кыргызча'),
    AppLanguageOption('lo', 'Lao', 'ລາວ'),
    AppLanguageOption('lv', 'Latvian', 'Latviešu'),
    AppLanguageOption('lt', 'Lithuanian', 'Lietuvių'),
    AppLanguageOption('lb', 'Luxembourgish', 'Lëtzebuergesch'),
    AppLanguageOption('mk', 'Macedonian', 'Македонски'),
    AppLanguageOption('ms', 'Malay', 'Bahasa Melayu'),
    AppLanguageOption('ml', 'Malayalam', 'മലയാളം'),
    AppLanguageOption('mt', 'Maltese', 'Malti'),
    AppLanguageOption('mr', 'Marathi', 'मराठी'),
    AppLanguageOption('mn', 'Mongolian', 'Монгол'),
    AppLanguageOption('ne', 'Nepali', 'नेपाली'),
    AppLanguageOption('nb', 'Norwegian Bokmål', 'Norsk bokmål'),
    AppLanguageOption('or', 'Odia', 'ଓଡ଼ିଆ'),
    AppLanguageOption('fa', 'Persian', 'فارسی'),
    AppLanguageOption('pl', 'Polish', 'Polski'),
    AppLanguageOption('pt-BR', 'Portuguese (Brazil)', 'Português (Brasil)'),
    AppLanguageOption('pt-PT', 'Portuguese (Portugal)', 'Português (Portugal)'),
    AppLanguageOption('pa', 'Punjabi', 'ਪੰਜਾਬੀ'),
    AppLanguageOption('ro', 'Romanian', 'Română'),
    AppLanguageOption('ru', 'Russian', 'Русский'),
    AppLanguageOption('gd', 'Scottish Gaelic', 'Gàidhlig'),
    AppLanguageOption('sr', 'Serbian', 'Српски'),
    AppLanguageOption('sk', 'Slovak', 'Slovenčina'),
    AppLanguageOption('sl', 'Slovenian', 'Slovenščina'),
    AppLanguageOption('so', 'Somali', 'Soomaali'),
    AppLanguageOption('es', 'Spanish', 'Español'),
    AppLanguageOption('sw', 'Swahili', 'Kiswahili'),
    AppLanguageOption('sv', 'Swedish', 'Svenska'),
    AppLanguageOption('tl', 'Tagalog', 'Tagalog'),
    AppLanguageOption('tg', 'Tajik', 'Тоҷикӣ'),
    AppLanguageOption('ta', 'Tamil', 'தமிழ்'),
    AppLanguageOption('te', 'Telugu', 'తెలుగు'),
    AppLanguageOption('th', 'Thai', 'ไทย'),
    AppLanguageOption('tr', 'Turkish', 'Türkçe'),
    AppLanguageOption('uk', 'Ukrainian', 'Українська'),
    AppLanguageOption('ur', 'Urdu', 'اردو'),
    AppLanguageOption('uz', 'Uzbek', 'Oʻzbekcha'),
    AppLanguageOption('vi', 'Vietnamese', 'Tiếng Việt'),
    AppLanguageOption('cy', 'Welsh', 'Cymraeg'),
    AppLanguageOption('zu', 'Zulu', 'isiZulu'),
    AppLanguageOption('bho', 'Bhojpuri', 'भोजपुरी'),
    AppLanguageOption('doi', 'Dogri', 'डोगरी'),
    AppLanguageOption('sa', 'Sanskrit', 'संस्कृतम्'),
    AppLanguageOption('mai', 'Maithili', 'मैथिली'),
    AppLanguageOption('kok', 'Konkani', 'कोंकणी'),
    AppLanguageOption('mni', 'Manipuri', 'মৈতৈলোন্'),
    AppLanguageOption('brx', 'Bodo', 'बर’'),
    AppLanguageOption('ks', 'Kashmiri', 'कॉशुर'),
    AppLanguageOption('sd', 'Sindhi', 'سنڌي'),
    AppLanguageOption('ps', 'Pashto', 'پښتو'),
    AppLanguageOption('si', 'Sinhala', 'සිංහල'),
    AppLanguageOption('jv', 'Javanese', 'Basa Jawa'),
    AppLanguageOption('su', 'Sundanese', 'Basa Sunda'),
    AppLanguageOption('ceb', 'Cebuano', 'Cebuano'),
    AppLanguageOption('ny', 'Chichewa', 'Chichewa'),
    AppLanguageOption('co', 'Corsican', 'Corsu'),
    AppLanguageOption('eo', 'Esperanto', 'Esperanto'),
    AppLanguageOption('fj', 'Fijian', 'Vosa Vakaviti'),
    AppLanguageOption('ht', 'Haitian Creole', 'Kreyòl ayisyen'),
    AppLanguageOption('haw', 'Hawaiian', 'ʻŌlelo Hawaiʻi'),
    AppLanguageOption('hmn', 'Hmong', 'Hmoob'),
    AppLanguageOption('ku', 'Kurdish', 'Kurdî'),
    AppLanguageOption('mg', 'Malagasy', 'Malagasy'),
    AppLanguageOption('mi', 'Māori', 'Te Reo Māori'),
    AppLanguageOption('sm', 'Samoan', 'Gagana Sāmoa'),
    AppLanguageOption('sn', 'Shona', 'chiShona'),
    AppLanguageOption('yo', 'Yoruba', 'Yorùbá'),
    AppLanguageOption('ig', 'Igbo', 'Asụsụ Igbo'),
    AppLanguageOption('ee', 'Ewe', 'Eʋegbe'),
  ];

  // --------------------------------------------------
  // INITIALIZE SAVED LANGUAGE
  // --------------------------------------------------

  Future<void> initialize() async {
    try {
      final savedCode = await _preferences.getString(
        'weathergpt_language_code',
      );

      if (savedCode == null) {
        return;
      }

      AppLanguageOption? match;

      for (final option in languages) {
        if (option.code == savedCode) {
          match = option;
          break;
        }
      }

      if (match == null) {
        return;
      }

      final cached = await _preferences.getString(
        'weathergpt_translations_$savedCode',
      );

      final cachedTranslations = <String, String>{};

      if (cached != null && cached.isNotEmpty) {
        final decoded = jsonDecode(cached);

        if (decoded is Map) {
          for (final entry in decoded.entries) {
            cachedTranslations[entry.key.toString()] =
                entry.value.toString();
          }
        }
      }

      _selected = match;
      _translations
        ..clear()
        ..addAll(cachedTranslations);

      notifyListeners();
    } catch (error) {
      debugPrint('Language preferences could not be loaded: $error');
      notifyListeners();
    }
  }

  // --------------------------------------------------
  // SELECT LANGUAGE
  // --------------------------------------------------

  Future<void> selectLanguage(AppLanguageOption option) async {
    if (_selected.code == option.code) return;

    _retryTimer?.cancel();
    _retryTimer = null;

    _retryScheduled = false;
    _retryAttempt = 0;
    _lastError = null;

    _selected = option;

    _translations.clear();
    _pendingTexts.clear();

    try {
      await _preferences.setString(
        'weathergpt_language_code',
        option.code,
      );

      await _preferences.setString(
        'weathergpt_language_name',
        option.name,
      );

      final cached = await _preferences.getString(
        'weathergpt_translations_${option.code}',
      );

      if (cached != null && cached.isNotEmpty) {
        final decoded = jsonDecode(cached);

        if (decoded is Map) {
          for (final entry in decoded.entries) {
            _translations[entry.key.toString()] =
                entry.value.toString();
          }
        }
      }
    } catch (error) {
      debugPrint('Could not load cached translations: $error');
    }

    notifyListeners();
  }

  // --------------------------------------------------
  // GET TRANSLATED TEXT
  // --------------------------------------------------

  String text(String englishText) {
    if (_selected.code == 'en' || englishText.trim().isEmpty) {
      return englishText;
    }

    final translated = _translations[englishText];

    if (translated != null && translated.trim().isNotEmpty) {
      return translated;
    }

    _pendingTexts.add(englishText);
    _scheduleTranslation();

    return englishText;
  }

  // --------------------------------------------------
  // SCHEDULE TRANSLATION
  // --------------------------------------------------

  void _scheduleTranslation() {
    if (_flushScheduled ||
        _isTranslating ||
        _retryScheduled ||
        _lastError != null ||
        _selected.code == 'en' ||
        _pendingTexts.isEmpty) {
      return;
    }

    _flushScheduled = true;

    scheduleMicrotask(() {
      _flushScheduled = false;
      unawaited(_flushPendingTranslations());
    });
  }

  // --------------------------------------------------
  // TRANSLATE PENDING TEXT
  // --------------------------------------------------

  Future<void> _flushPendingTranslations() async {
    if (_isTranslating ||
        _selected.code == 'en' ||
        _pendingTexts.isEmpty) {
      return;
    }

    final requestLanguage = _selected;

    final batch = _pendingTexts.take(70).toList();
    _pendingTexts.removeAll(batch);

    _isTranslating = true;
    notifyListeners();

    try {
      final cleanBaseUrl = baseUrl.replaceFirst(
        RegExp(r'/$'),
        '',
      );

      final response = await http
          .post(
            Uri.parse('$cleanBaseUrl/translate'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'language_code': requestLanguage.code,
              'language_name': requestLanguage.name,
              'texts': batch,
            }),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        throw Exception(
          'Translation service returned ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw const FormatException(
          'Invalid translation response.',
        );
      }

      final rawTranslations = decoded['translations'];

      if (rawTranslations is! Map) {
        throw const FormatException(
          'Translation response is missing translations.',
        );
      }

      final completedTranslations = <String, String>{};

      for (final source in batch) {
        final value = rawTranslations[source];

        if (value is String && value.trim().isNotEmpty) {
          completedTranslations[source] = value.trim();
        } else {
          throw FormatException(
            'Translation missing for: $source',
          );
        }
      }

      // Only apply the result if the selected language
      // is still the same language used for this request.

      if (_selected.code == requestLanguage.code) {
        _translations.addAll(completedTranslations);

        _lastError = null;
        _retryAttempt = 0;

        try {
          await _preferences.setString(
            'weathergpt_translations_${requestLanguage.code}',
            jsonEncode(_translations),
          );
        } catch (error) {
          debugPrint('Could not save translation cache: $error');
        }
      }
    } catch (error) {
      debugPrint('UI translation failed: $error');

      if (_selected.code == requestLanguage.code) {
        _lastError = error.toString();
        _pendingTexts.addAll(batch);

        _retryAttempt++;

        // Retry automatically only twice.
        // This prevents endless requests if Gemini is unavailable.

        if (_retryAttempt <= _maximumRetries) {
          _retryScheduled = true;

          final delaySeconds = _retryAttempt * 2;

          _retryTimer?.cancel();

          _retryTimer = Timer(
            Duration(seconds: delaySeconds),
            () {
              _retryScheduled = false;

              if (_selected.code == requestLanguage.code) {
                _lastError = null;
                _scheduleTranslation();
              }
            },
          );
        }
      } else if (_selected.code != 'en') {
        // The user changed language while the old request
        // was running. Keep the English source strings.
        // They can now be translated into the new language.

        _pendingTexts.addAll(batch);
      }
    } finally {
      _isTranslating = false;

      notifyListeners();

      if (_pendingTexts.isNotEmpty &&
          _selected.code != 'en' &&
          _lastError == null &&
          !_retryScheduled) {
        _scheduleTranslation();
      }
    }
  }

  // --------------------------------------------------
  // MANUAL RETRY
  // --------------------------------------------------

  void retryTranslations() {
    if (_selected.code == 'en' ||
        _pendingTexts.isEmpty ||
        _isTranslating) {
      return;
    }

    _retryTimer?.cancel();
    _retryTimer = null;

    _retryScheduled = false;
    _retryAttempt = 0;
    _lastError = null;

    _scheduleTranslation();
  }

  // --------------------------------------------------
  // DISPOSE
  // --------------------------------------------------

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}

// --------------------------------------------------
// LANGUAGE SCOPE
// --------------------------------------------------

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();

    assert(
      scope != null,
      'AppLanguageScope is missing above this context.',
    );

    return scope!.notifier!;
  }
}
