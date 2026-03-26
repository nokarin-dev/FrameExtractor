import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

// UI style variants
enum UIStyle { classic, glass }

// Color tokens
class _DarkTokens {
  static const bg = Color(0xFF080A0F);
  static const surface = Color(0xFF0F1219);
  static const surfaceHi = Color(0xFF161B27);
  static const border = Color(0xFF1E2535);
  static const borderHi = Color(0xFF2A3347);
  static const accent = Color(0xFF4F8EF7);
  static const accentDim = Color(0xFF1A2E5A);
  static const green = Color(0xFF2ECC71);
  static const greenDim = Color(0xFF0D3320);
  static const red = Color(0xFFE74C3C);
  static const redDim = Color(0xFF3A1010);
  static const orange = Color(0xFFF39C12);
  static const purple = Color(0xFF9B6EF7);
  static const textPri = Color(0xFFEDF0F7);
  static const textSec = Color(0xFF6B7594);
  static const textMuted = Color(0xFF2E3547);
  static const ytRed = Color(0xFFFF3B30);
  static const disabled = Color(0xFF1A1F2E);
}

class _LightTokens {
  static const bg = Color(0xFFF0F2F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHi = Color(0xFFF5F7FD);
  static const border = Color(0xFFDDE1EF);
  static const borderHi = Color(0xFFC3CAE0);
  static const accent = Color(0xFF2E6EE6);
  static const accentDim = Color(0xFFD6E4FF);
  static const green = Color(0xFF1B9E52);
  static const greenDim = Color(0xFFD4F5E3);
  static const red = Color(0xFFCC2B1D);
  static const redDim = Color(0xFFFFE5E3);
  static const orange = Color(0xFFB86A00);
  static const purple = Color(0xFF6A3FD9);
  static const textPri = Color(0xFF111827);
  static const textSec = Color(0xFF4B5B7A);
  static const textMuted = Color(0xFF9AA3BB);
  static const ytRed = Color(0xFFCC0000);
  static const disabled = Color(0xFFA8B0C8);
}

// AppColors
class AppColors {
  final Color bg, surface, surfaceHi, border, borderHi;
  final Color accent, accentDim;
  final Color green, greenDim, red, redDim, orange, purple;
  final Color textPri, textSec, textMuted, ytRed, disabled;

  const AppColors._({
    required this.bg,
    required this.surface,
    required this.surfaceHi,
    required this.border,
    required this.borderHi,
    required this.accent,
    required this.accentDim,
    required this.green,
    required this.greenDim,
    required this.red,
    required this.redDim,
    required this.orange,
    required this.purple,
    required this.textPri,
    required this.textSec,
    required this.textMuted,
    required this.ytRed,
    required this.disabled,
  });

  static const dark = AppColors._(
    bg: _DarkTokens.bg,
    surface: _DarkTokens.surface,
    surfaceHi: _DarkTokens.surfaceHi,
    border: _DarkTokens.border,
    borderHi: _DarkTokens.borderHi,
    accent: _DarkTokens.accent,
    accentDim: _DarkTokens.accentDim,
    green: _DarkTokens.green,
    greenDim: _DarkTokens.greenDim,
    red: _DarkTokens.red,
    redDim: _DarkTokens.redDim,
    orange: _DarkTokens.orange,
    purple: _DarkTokens.purple,
    textPri: _DarkTokens.textPri,
    textSec: _DarkTokens.textSec,
    textMuted: _DarkTokens.textMuted,
    ytRed: _DarkTokens.ytRed,
    disabled: _DarkTokens.disabled,
  );

  static const light = AppColors._(
    bg: _LightTokens.bg,
    surface: _LightTokens.surface,
    surfaceHi: _LightTokens.surfaceHi,
    border: _LightTokens.border,
    borderHi: _LightTokens.borderHi,
    accent: _LightTokens.accent,
    accentDim: _LightTokens.accentDim,
    green: _LightTokens.green,
    greenDim: _LightTokens.greenDim,
    red: _LightTokens.red,
    redDim: _LightTokens.redDim,
    orange: _LightTokens.orange,
    purple: _LightTokens.purple,
    textPri: _LightTokens.textPri,
    textSec: _LightTokens.textSec,
    textMuted: _LightTokens.textMuted,
    ytRed: _LightTokens.ytRed,
    disabled: _LightTokens.disabled,
  );
}

// GlassTokens
class GlassTokens {
  static const double blurCard = 32.0;
  static const double blurTitBar = 40.0;
  static const double blurModal = 48.0;

  // LiquidGlassSettings
  static LiquidGlassSettings cardSettings({bool isDark = true}) =>
      LiquidGlassSettings(
        thickness: isDark ? 0.55 : 0.65,
        blur: 5,
        glassColor: isDark ? const Color(0x20FFFFFF) : const Color(0x30FFFFFF),
      );

  static LiquidGlassSettings modalSettings({bool isDark = true}) =>
      LiquidGlassSettings(
        thickness: isDark ? 0.70 : 0.82,
        blur: 10,
        glassColor: isDark ? const Color(0x28FFFFFF) : const Color(0x40FFFFFF),
      );

  static LiquidGlassSettings titleBarSettings({bool isDark = true}) =>
      LiquidGlassSettings(
        thickness: isDark ? 0.38 : 0.50,
        blur: 10,
        glassColor: isDark ? const Color(0x18FFFFFF) : const Color(0x28FFFFFF),
      );

  static LiquidGlassSettings pillSettings({
    bool isDark = true,
    bool selected = false,
    Color? accent,
  }) => LiquidGlassSettings(
    thickness: selected ? 0.50 : 0.35,
    blur: 6,
    glassColor: selected && accent != null
        ? accent.withValues(alpha: isDark ? 0.25 : 0.18)
        : (isDark ? const Color(0x16FFFFFF) : const Color(0x28FFFFFF)),
  );

  // Fallback card
  static BoxDecoration fallbackCard(
    AppColors c, {
    bool isDark = true,
    double radius = 18,
    bool selected = false,
  }) => BoxDecoration(
    color: isDark
        ? c.surface.withValues(alpha: 0.18)
        : c.surface.withValues(alpha: 0.82),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: selected
          ? c.accent.withValues(alpha: 0.55)
          : isDark
          ? Colors.white.withValues(alpha: 0.13)
          : c.borderHi.withValues(alpha: 0.80),
      width: selected ? 1.5 : 1.0,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
        blurRadius: isDark ? 32 : 16,
        spreadRadius: isDark ? -4 : -2,
        offset: Offset(0, isDark ? 10 : 4),
      ),
    ],
  );

  static BoxDecoration fallbackModal(AppColors c, {bool isDark = true}) =>
      BoxDecoration(
        color: isDark
            ? c.surface.withValues(alpha: 0.28)
            : c.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.18)
              : c.borderHi.withValues(alpha: 0.90),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.12),
            blurRadius: isDark ? 60 : 24,
            spreadRadius: isDark ? -6 : -2,
            offset: Offset(0, isDark ? 20 : 8),
          ),
        ],
      );

  static BoxDecoration fallbackTitleBar(AppColors c, {bool isDark = true}) =>
      BoxDecoration(
        color: isDark
            ? c.surface.withValues(alpha: 0.22)
            : c.surface.withValues(alpha: 0.78),
      );

  static BoxDecoration pillDecoration(
    AppColors c, {
    required bool selected,
    required Color accent,
    bool isDark = true,
  }) => BoxDecoration(
    color: selected
        ? accent.withValues(alpha: isDark ? 0.25 : 0.16)
        : isDark
        ? Colors.white.withValues(alpha: 0.07)
        : c.surface.withValues(alpha: 0.72),
    borderRadius: BorderRadius.circular(100),
    border: Border.all(
      color: selected
          ? accent.withValues(alpha: 0.60)
          : isDark
          ? Colors.white.withValues(alpha: 0.18)
          : c.borderHi.withValues(alpha: 0.75),
      width: selected ? 1.5 : 1.0,
    ),
    boxShadow: selected
        ? [
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 10,
              spreadRadius: -1,
            ),
          ]
        : null,
  );

  static Decoration glossOverlay({bool isDark = true, double radius = 18}) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: const Alignment(-0.8, -1.0),
          end: const Alignment(0.6, 0.4),
          stops: const [0.0, 0.28, 0.55, 1.0],
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.12 : 0.20),
            Colors.white.withValues(alpha: isDark ? 0.03 : 0.06),
            Colors.transparent,
            Colors.white.withValues(alpha: isDark ? 0.02 : 0.04),
          ],
        ),
      );

  // Glass-aware label color
  static Color cardLabelColor(AppColors c, {required bool isDark}) =>
      isDark ? Colors.white.withValues(alpha: 0.30) : c.textSec;

  static double disabledOpacity({required bool isGlass}) =>
      isGlass ? 0.60 : 0.38;
}

// LiquidGlassCard
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final AppColors colors;
  final bool selected;
  final double radius;

  const LiquidGlassCard({
    super.key,
    required this.child,
    required this.isDark,
    required this.colors,
    this.selected = false,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      useOwnLayer: true,
      settings: GlassTokens.cardSettings(isDark: isDark),
      shape: LiquidRoundedRectangle(borderRadius: radius),
      child: child,
    );
  }
}

// AppTheme
class AppTheme {
  final AppColors colors;
  final UIStyle style;
  final bool isDark;

  const AppTheme({
    required this.colors,
    required this.style,
    required this.isDark,
  });

  static AppTheme of(BuildContext context) =>
      _AppThemeScope.of(context)?.theme ??
      const AppTheme(
        colors: AppColors.dark,
        style: UIStyle.classic,
        isDark: true,
      );

  bool get isGlass => style == UIStyle.glass;

  BoxDecoration classicCard({Color? borderColor}) => BoxDecoration(
    color: colors.surface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: borderColor ?? colors.border),
  );

  Color get titleBarBg => isGlass
      ? colors.surface.withValues(alpha: isDark ? 0.22 : 0.52)
      : colors.surface;

  ThemeData toMaterialTheme() => ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: colors.accent,
      onPrimary: Colors.white,
      secondary: colors.purple,
      onSecondary: Colors.white,
      error: colors.red,
      onError: Colors.white,
      surface: colors.surface,
      onSurface: colors.textPri,
    ),
    scaffoldBackgroundColor: colors.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dialogTheme: const DialogThemeData(backgroundColor: Colors.transparent),
  );
}

class _AppThemeScope extends InheritedWidget {
  final AppTheme theme;
  const _AppThemeScope({required this.theme, required super.child});

  static _AppThemeScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AppThemeScope>();

  @override
  bool updateShouldNotify(_AppThemeScope old) =>
      theme.isDark != old.theme.isDark ||
      theme.style != old.theme.style ||
      theme.colors != old.theme.colors;
}

// AppThemeProvider
class AppThemeProvider extends StatefulWidget {
  final String initialThemeMode;
  final String initialUIStyle;
  final Widget child;

  const AppThemeProvider({
    super.key,
    required this.initialThemeMode,
    required this.initialUIStyle,
    required this.child,
  });

  static AppThemeProviderState of(BuildContext context) =>
      context.findAncestorStateOfType<AppThemeProviderState>()!;

  @override
  State<AppThemeProvider> createState() => AppThemeProviderState();
}

class AppThemeProviderState extends State<AppThemeProvider> {
  late bool _isDark;
  late UIStyle _style;

  @override
  void initState() {
    super.initState();
    _isDark = widget.initialThemeMode != 'light';
    _style = widget.initialUIStyle == 'glass' ? UIStyle.glass : UIStyle.classic;
  }

  AppTheme get currentTheme => AppTheme(
    colors: _isDark ? AppColors.dark : AppColors.light,
    style: _style,
    isDark: _isDark,
  );

  bool get isDark => _isDark;
  UIStyle get style => _style;

  void setDark(bool v) => setState(() => _isDark = v);
  void setStyle(UIStyle v) => setState(() => _style = v);
  void toggleTheme() => setState(() => _isDark = !_isDark);
  void toggleStyle() => setState(
    () => _style = _style == UIStyle.classic ? UIStyle.glass : UIStyle.classic,
  );

  @override
  Widget build(BuildContext context) =>
      _AppThemeScope(theme: currentTheme, child: widget.child);
}
