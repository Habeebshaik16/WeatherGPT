
import 'package:flutter/material.dart';
import '../services/app_language.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final String temperatureUnit;
  final ValueChanged<String> onTemperatureUnitChanged;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
    required this.temperatureUnit,
    required this.onTemperatureUnitChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool voiceEnabled = true;
  bool weatherAlerts = true;

  final TextEditingController _valueController =
      TextEditingController();

  final TextEditingController _languageSearchController =
      TextEditingController();

  String _languageQuery = '';
  String _from = '°C';
  String _to = '°F';

  @override
  void dispose() {
    _valueController.dispose();
    _languageSearchController.dispose();
    super.dispose();
  }

  double? get _result {
    final value = double.tryParse(
      _valueController.text.trim().replaceAll(',', '.'),
    );

    if (value == null) return null;
    if (_from == _to) return value;

    return _from == '°C'
        ? (value * 9 / 5) + 32
        : (value - 32) * 5 / 9;
  }

  void _chooseTemperatureUnit() {
    final controller = AppLanguageScope.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(controller.text('Temperature Unit')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _unitChoice(
              dialogContext,
              controller,
              '°C',
              'Celsius',
            ),
            _unitChoice(
              dialogContext,
              controller,
              '°F',
              'Fahrenheit',
            ),
          ],
        ),
      ),
    );
  }

  Widget _unitChoice(
    BuildContext dialogContext,
    AppLanguageController controller,
    String unit,
    String name,
  ) {
    return ListTile(
      title: Text('${controller.text(name)} ($unit)'),
      trailing: widget.temperatureUnit == unit
          ? const Icon(
              Icons.check_rounded,
              color: Color(0xFF3F7CFF),
            )
          : null,
      onTap: () {
        widget.onTemperatureUnitChanged(unit);
        Navigator.pop(dialogContext);
      },
    );
  }

  void _chooseLanguage() {
    final controller = AppLanguageScope.of(context);

    _languageSearchController.clear();
    _languageQuery = '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = _languageQuery.trim().toLowerCase();

            final filteredLanguages =
                AppLanguageController.languages.where((item) {
              return item.name.toLowerCase().contains(query) ||
                  item.nativeName.toLowerCase().contains(query) ||
                  item.code.toLowerCase().contains(query);
            }).toList();

            return AlertDialog(
              title: Text(controller.text('Choose Language')),
              content: SizedBox(
                width: double.maxFinite,
                height: 450,
                child: Column(
                  children: [
                    TextField(
                      controller: _languageSearchController,
                      decoration: InputDecoration(
                        hintText:
                            controller.text('Search language...'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _languageQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _languageSearchController.clear();
                                  setDialogState(() {
                                    _languageQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          _languageQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredLanguages.isEmpty
                          ? Center(
                              child: Text(
                                controller.text('No languages found'),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredLanguages.length,
                              itemBuilder: (context, index) {
                                final item = filteredLanguages[index];

                                final isSelected =
                                    controller.selected.code == item.code;

                                return ListTile(
                                  title: Text(item.name),
                                  subtitle: Text(item.nativeName),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF3F7CFF),
                                        )
                                      : null,
                                  onTap: () async {
                                    await controller.selectLanguage(item);

                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _heading(String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3F7CFF),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final languageController = AppLanguageScope.of(context);

    String t(String value) => languageController.text(value);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('Settings'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          _heading(t('Weather')),

          _SettingsButton(
            icon: Icons.language_rounded,
            title: t('Language'),
            subtitle: languageController.selected.displayName,
            onTap: _chooseLanguage,
          ),

          _SettingsButton(
            icon: Icons.thermostat_rounded,
            title: t('Temperature Unit'),
            subtitle:
                '${t('Currently selected')}: ${widget.temperatureUnit}',
            onTap: _chooseTemperatureUnit,
          ),

          const SizedBox(height: 20),

          _heading(t('Unit Converter')),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Temperature Conversion'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _valueController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: t('Enter temperature'),
                    suffixText: _from,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _from,
                        decoration: InputDecoration(
                          labelText: t('From'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: '°C',
                            child: Text(t('Celsius °C')),
                          ),
                          DropdownMenuItem(
                            value: '°F',
                            child: Text(t('Fahrenheit °F')),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _from = value;
                            });
                          }
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded),
                    ),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _to,
                        decoration: InputDecoration(
                          labelText: t('To'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: '°C',
                            child: Text(t('Celsius °C')),
                          ),
                          DropdownMenuItem(
                            value: '°F',
                            child: Text(t('Fahrenheit °F')),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _to = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F7CFF)
                        .withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('Converted Result'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        result == null
                            ? '--'
                            : '${result.toStringAsFixed(2)} $_to',
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3F7CFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          _heading(t('WeatherGPT AI')),

          _SettingsSwitch(
            icon: Icons.mic_rounded,
            title: t('Voice Assistant'),
            subtitle: t('Talk to WeatherGPT using your voice'),
            value: voiceEnabled,
            onChanged: (value) {
              setState(() {
                voiceEnabled = value;
              });
            },
          ),

          _SettingsButton(
            icon: Icons.record_voice_over_rounded,
            title: t('AI Voice'),
            subtitle: t('Natural'),
            onTap: () {},
          ),

          const SizedBox(height: 25),

          _heading(t('Notifications')),

          _SettingsSwitch(
            icon: Icons.warning_amber_rounded,
            title: t('Weather Alerts'),
            subtitle: t('Receive important weather warnings'),
            value: weatherAlerts,
            onChanged: (value) {
              setState(() {
                weatherAlerts = value;
              });
            },
          ),

          const SizedBox(height: 25),

          _heading(t('Appearance')),

          _SettingsSwitch(
            icon: Icons.dark_mode_rounded,
            title: t('Dark Mode'),
            subtitle: widget.isDarkMode
                ? t('Dark appearance enabled')
                : t('Use a darker appearance'),
            value: widget.isDarkMode,
            onChanged: widget.onDarkModeChanged,
          ),

          const SizedBox(height: 30),

          Center(
            child: Text(
              'WeatherGPT',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
              ),
            ),
          ),

          const SizedBox(height: 5),

          Center(
            child: Text(
              t('Smart weather. Simple answers.'),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _SettingsIcon(icon: icon),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          child: Row(
            children: [
              _SettingsIcon(icon: icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  final IconData icon;

  const _SettingsIcon({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF3F7CFF)
            .withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        color: const Color(0xFF3F7CFF),
      ),
    );
  }
}
