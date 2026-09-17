import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/myna.dart';

/// Карточка раздела: заголовок, подпись под ним и действие справа. Глубина
/// берётся тональной поверхностью, а не тенью, — так во всех наших
/// приложениях.
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget child;
  final EdgeInsets padding;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: AppTheme.displayFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              letterSpacing: -0.3,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontFamily: AppTheme.bodyFont,
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) trailing!,
                    if (trailing == null && onTap != null)
                      Icon(Myna.chevronRight,
                          color: scheme.onSurfaceVariant, size: 24),
                  ],
                ),
                const SizedBox(height: 14),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Строка «нечего показать» внутри карточки: занимает мало места и не тянет на
/// себя внимание, в отличие от полноэкранной заглушки.
class CardEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  const CardEmpty({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
