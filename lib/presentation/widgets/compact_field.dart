import 'package:flutter/material.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

class CompactField extends StatelessWidget {
  final AppColors c;
  final String initialValue, hint;
  final ValueChanged<String> onChanged;
  final bool isGlass, isDark;
  const CompactField({
    super.key,
    required this.c,
    required this.initialValue,
    required this.hint,
    required this.onChanged,
    this.isGlass = false,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = isGlass
        ? (isDark
              ? Colors.white.withValues(alpha: 0.07)
              : c.surface.withValues(alpha: 0.60))
        : c.surfaceHi;
    final borderColor = isGlass
        ? (isDark
              ? Colors.white.withValues(alpha: 0.18)
              : c.border.withValues(alpha: 0.70))
        : c.border;

    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      style: TextStyle(color: c.textPri, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isGlass
              ? (isDark ? Colors.white.withValues(alpha: 0.28) : c.textMuted)
              : c.textMuted,
          fontSize: 13,
        ),
        filled: true,
        fillColor: fillColor,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
      ),
    );
  }
}
