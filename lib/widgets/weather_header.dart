
import 'package:flutter/material.dart';

import '../services/app_language.dart';

class WeatherHeader extends StatelessWidget {
  final String location;
  final VoidCallback? onLocationTap;
  final VoidCallback? onSettingsTap;

  const WeatherHeader({
    super.key,
    required this.location,
    this.onLocationTap,
    this.onSettingsTap,
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
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF3F7CFF),
                  Color(0xFF6C63FF),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.cloud_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WeatherGPT',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 3),

                InkWell(
                  onTap: onLocationTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: Color(0xFF3F7CFF),
                      ),

                      const SizedBox(width: 4),

                      Flexible(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.70),
                          ),
                        ),
                      ),

                      const SizedBox(width: 3),

                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 17,
                        color: Color(0xFF3F7CFF),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: onLocationTap,
            tooltip: t('Change location'),
            icon: const Icon(
              Icons.location_searching_rounded,
              color: Color(0xFF3F7CFF),
            ),
          ),

          IconButton(
            onPressed: onSettingsTap,
            tooltip: t('Settings'),
            icon: Icon(
              Icons.settings_outlined,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
