import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

class AppCard extends StatelessWidget {
  final AppTheme theme;
  final String label;
  final Widget child;
  const AppCard({
    super.key,
    required this.theme,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              color: theme.isGlass
                  ? GlassTokens.cardLabelColor(c, isDark: theme.isDark)
                  : c.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ),
        theme.isGlass
            ? GlassContainer(
                useOwnLayer: true,
                settings: GlassTokens.cardSettings(isDark: theme.isDark),
                shape: LiquidRoundedRectangle(borderRadius: 18),
                child: child,
              )
            : Container(
                decoration: theme.classicCard(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: child,
                ),
              ),
      ],
    );
  }
}
