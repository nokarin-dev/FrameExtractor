import 'package:flutter/material.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

class GlossChip extends StatelessWidget {
  final AppColors c;
  final String label;
  final bool selected, disabled, isGlass, isDark;
  final VoidCallback? onTap;
  final Color color;
  const GlossChip({
    super.key,
    required this.c,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isGlass,
    required this.isDark,
    this.disabled = false,
    this.color = const Color(0xFF4F8EF7),
  });

  @override
  Widget build(BuildContext context) {
    if (!isGlass) {
      final eff = disabled ? c.textMuted : color;
      return MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? eff : c.surfaceHi,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: selected ? eff : c.border),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : (disabled ? c.textMuted : c.textSec),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: GlassTokens.pillDecoration(
            c,
            selected: selected,
            accent: disabled ? c.textMuted : color,
            isDark: isDark,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? (disabled ? c.textMuted : color)
                  : (isDark ? Colors.white.withValues(alpha: 0.65) : c.textSec),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
