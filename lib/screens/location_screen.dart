
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/location_model.dart';
import '../services/weather_service.dart';
import '../services/app_language.dart';
import '../widgets/weather_background.dart';

class LocationScreen extends StatefulWidget {
  final String selectedLocation;
  final ValueChanged<LocationModel> onLocationSelected;

  const LocationScreen({
    super.key,
    required this.selectedLocation,
    required this.onLocationSelected,
  });

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final TextEditingController _controller = TextEditingController();
  final WeatherService _weatherService = WeatherService();

  Timer? _debounce;

  List<LocationModel> _locations = [];

  bool _isSearching = false;
  String? _searchError;
  String _searchText = '';

  int _searchRequest = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchText = value.trim();

    _debounce?.cancel();

    if (_searchText.length < 2) {
      setState(() {
        _locations = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    _debounce = Timer(
      const Duration(milliseconds: 500),
      _searchLocations,
    );
  }

  Future<void> _searchLocations() async {
    final requestId = ++_searchRequest;
    final query = _searchText;

    try {
      final results = await _weatherService.searchLocations(query);

      if (!mounted || requestId != _searchRequest) return;

      setState(() {
        _locations = results;
        _isSearching = false;
        _searchError = null;
      });
    } catch (e) {
      if (!mounted || requestId != _searchRequest) return;

      setState(() {
        _locations = [];
        _isSearching = false;
        _searchError =
            e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _selectLocation(LocationModel place) {
    FocusScope.of(context).unfocus();

    widget.onLocationSelected(place);

    final language = AppLanguageScope.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${language.text('Location changed to')} ${place.displayName}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
        backgroundColor: Colors.transparent,
        body: WeatherBackground(
          condition: 'clear',
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  t('Locations'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  t('Search for any city or place worldwide'),
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: 0.65,
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(
                      alpha: isDark ? 0.75 : 0.85,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    textAlign: language.isRightToLeft
                        ? TextAlign.right
                        : TextAlign.left,
                    decoration: InputDecoration(
                      hintText: t('Search city, town or place'),
                      icon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF3F7CFF),
                      ),
                      border: InputBorder.none,
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _controller.clear();
                                _onSearchChanged('');
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                Text(
                  t('Currently Selected'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 12),

                _LocationTile(
                  city: widget.selectedLocation,
                  subtitle: t('Your selected weather location'),
                  icon: Icons.my_location_rounded,
                  selected: true,
                  onTap: null,
                ),

                const SizedBox(height: 25),

                if (_searchText.isEmpty)
                  Text(
                    t('Start typing to search worldwide locations.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  )
                else if (_searchText.length < 2)
                  Text(
                    t('Enter at least 2 characters.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  )
                else ...[
                  Text(
                    t('Search Results'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.all(25),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_searchError != null)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        t(_searchError!),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (_locations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        t('No matching locations found. Try another spelling.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._locations.map(
                      (place) => _LocationTile(
                        city: place.displayName,
                        subtitle: place.details.isEmpty
                            ? t('Tap to view weather')
                            : place.details,
                        icon: Icons.location_on_outlined,
                        selected: false,
                        onTap: () => _selectLocation(place),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------
// LOCATION RESULT TILE
// --------------------------------------------------

class _LocationTile extends StatelessWidget {
  final String city;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _LocationTile({
    required this.city,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = AppLanguageScope.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? const Color(0xFF3F7CFF).withValues(alpha: 0.12)
            : theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F7CFF).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF3F7CFF),
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: language.isRightToLeft
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        city,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF3F7CFF),
                  )
                else
                  Icon(
                    language.isRightToLeft
                        ? Icons.arrow_back_ios_rounded
                        : Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: 0.5,
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
