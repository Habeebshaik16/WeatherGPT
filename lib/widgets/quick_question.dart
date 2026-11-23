
import 'package:flutter/material.dart';

import '../services/app_language.dart';

class QuickQuestion extends StatelessWidget {
  final String question;
  final IconData icon;
  final VoidCallback? onTap;

  const QuickQuestion({
    super.key,
    required this.question,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final language = AppLanguageScope.of(context);

    return Directionality(
      textDirection: language.isRightToLeft
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(
                alpha: isDark ? 0.78 : 0.90,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(
                  alpha: isDark ? 0.25 : 0.15,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F7CFF).withValues(
                      alpha: isDark ? 0.22 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF3F7CFF),
                    size: 20,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    question,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),

                Icon(
                  language.isRightToLeft
                      ? Icons.arrow_back_ios_rounded
                      : Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: 0.55,
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
