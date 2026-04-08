import 'package:flutter/material.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

class TimeField extends StatelessWidget {
  final AppColors c;
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool disabled, isGlass, isDark;
  final String? errorText;
  const TimeField({
    super.key,
    required this.c,
    required this.controller,
    required this.label,
    required this.icon,
    this.disabled = false,
    this.isGlass = false,
    this.isDark = true,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final fillColor = isGlass
        ? (isDark
              ? Colors.white.withValues(alpha: disabled ? 0.04 : 0.08)
              : c.surface.withValues(alpha: disabled ? 0.40 : 0.65))
        : (disabled ? c.disabled : c.surfaceHi);
    final borderColor = hasError
        ? c.red
        : isGlass
        ? (isDark
              ? Colors.white.withValues(alpha: disabled ? 0.08 : 0.18)
              : c.border.withValues(alpha: disabled ? 0.40 : 0.70))
        : c.border;

    return TextField(
      controller: controller,
      enabled: !disabled,
      style: TextStyle(
        color: hasError ? c.red : (disabled ? c.textMuted : c.textPri),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: hasError
              ? c.red
              : (isGlass
                    ? (isDark
                          ? Colors.white.withValues(
                              alpha: disabled ? 0.20 : 0.50,
                            )
                          : (disabled ? c.textMuted : c.textSec))
                    : c.textSec),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        errorText: errorText,
        errorStyle: TextStyle(color: c.red, fontSize: 9, height: 0.9),
        prefixIcon: Icon(
          icon,
          color: hasError
              ? c.red
              : (isGlass
                    ? (isDark
                          ? Colors.white.withValues(alpha: 0.35)
                          : c.textMuted)
                    : c.textMuted),
          size: 14,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 30,
          minHeight: 30,
        ),
        filled: true,
        fillColor: hasError
            ? (isGlass
                  ? c.red.withValues(alpha: 0.06)
                  : c.redDim.withValues(alpha: 0.5))
            : fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: borderColor,
            width: hasError ? 1.5 : 1.0,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: hasError ? c.red : c.accent,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.red, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.red, width: 1.5),
        ),
      ),
    );
  }
}
