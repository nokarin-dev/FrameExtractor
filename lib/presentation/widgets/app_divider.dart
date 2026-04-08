import 'package:flutter/material.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

class AppDivider extends StatelessWidget {
  final AppColors c;
  final bool isGlass, isDark;
  const AppDivider({
    super.key,
    required this.c,
    required this.isGlass,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    color: isGlass
        ? (isDark
              ? Colors.white.withValues(alpha: 0.07)
              : c.border.withValues(alpha: 0.50))
        : c.border,
  );
}
