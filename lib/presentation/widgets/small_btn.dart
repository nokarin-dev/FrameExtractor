import 'package:flutter/material.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

class SmallBtn extends StatelessWidget {
  final AppColors c;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool isGlass, isDark;
  const SmallBtn({
    super.key,
    required this.c,
    required this.label,
    required this.onTap,
    required this.color,
    required this.isGlass,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: onTap == null
              ? (isGlass
                    ? Colors.white.withValues(alpha: 0.05)
                    : color.withValues(alpha: 0.05))
              : color.withValues(alpha: isGlass ? 0.20 : 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: onTap == null
                ? (isGlass
                      ? (isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : c.border)
                      : color.withValues(alpha: 0.2))
                : color.withValues(alpha: 0.50),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onTap == null ? c.textMuted : color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}
