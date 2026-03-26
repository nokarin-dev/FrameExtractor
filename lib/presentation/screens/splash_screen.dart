import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frameextractor/core/app_prefs.dart';

class SplashScreen extends StatefulWidget {
  final String status;
  final bool hasError;
  final VoidCallback? onRetry;

  const SplashScreen({
    super.key,
    required this.status,
    this.hasError = false,
    this.onRetry,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  late final bool _isDark;
  late final bool _isGlass;

  @override
  void initState() {
    super.initState();
    _isDark = AppPrefs.themeMode != 'light';
    _isGlass = AppPrefs.uiStyle == 'glass';

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _bg => _isDark ? const Color(0xFF07090D) : const Color(0xFFECEEF6);
  Color get _accent =>
      _isDark ? const Color(0xFF4F8EF7) : const Color(0xFF2E6EE6);
  Color get _accentDim =>
      _isDark ? const Color(0xFF1A2E5A) : const Color(0xFFD6E4FF);
  Color get _textPri =>
      _isDark ? const Color(0xFFEDF0F7) : const Color(0xFF111827);
  Color get _textMuted =>
      _isDark ? const Color(0xFF2E3547) : const Color(0xFF9AA3BB);
  Color get _textSec =>
      _isDark ? const Color(0xFF6B7594) : const Color(0xFF4B5B7A);
  Color get _border =>
      _isDark ? const Color(0xFF1E2535) : const Color(0xFFDDE1EF);
  Color get _red => _isDark ? const Color(0xFFE74C3C) : const Color(0xFFCC2B1D);
  Color get _redDim =>
      _isDark ? const Color(0xFF3A1010) : const Color(0xFFFFE5E3);
  Color get _surfaceHi =>
      _isDark ? const Color(0xFF161B27) : const Color(0xFFF5F7FD);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isGlass ? Colors.transparent : _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isGlass)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isDark
                      ? const [
                          Color(0xFF0A0C12),
                          Color(0xFF080A0F),
                          Color(0xFF0C0E14),
                        ]
                      : const [
                          Color(0xFFEDF0FA),
                          Color(0xFFEAECF5),
                          Color(0xFFEFF1FA),
                        ],
                ),
              ),
            ),

          if (_isGlass)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: const SizedBox.expand(),
              ),
            ),

          FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SplashIcon(
                      isDark: _isDark,
                      isGlass: _isGlass,
                      accent: _accent,
                      accentDim: _accentDim,
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Frame Extractor',
                      style: TextStyle(
                        color: _textPri,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Effortless video frame extraction',
                      style: TextStyle(color: _textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 48),

                    // Status / error
                    if (!widget.hasError) ...[
                      _ProgressBar(
                        isDark: _isDark,
                        isGlass: _isGlass,
                        accent: _accent,
                        surfaceHi: _surfaceHi,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.status,
                        style: TextStyle(color: _textSec, fontSize: 12),
                      ),
                    ] else ...[
                      _ErrorBox(
                        status: widget.status,
                        isDark: _isDark,
                        isGlass: _isGlass,
                        red: _red,
                        redDim: _redDim,
                        border: _border,
                      ),
                      if (widget.onRetry != null) ...[
                        const SizedBox(height: 20),
                        _RetryButton(
                          onRetry: widget.onRetry!,
                          isDark: _isDark,
                          isGlass: _isGlass,
                          accent: _accent,
                          accentDim: _accentDim,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Splash icon
class _SplashIcon extends StatelessWidget {
  final bool isDark;
  final bool isGlass;
  final Color accent;
  final Color accentDim;

  const _SplashIcon({
    required this.isDark,
    required this.isGlass,
    required this.accent,
    required this.accentDim,
  });

  @override
  Widget build(BuildContext context) {
    if (isGlass) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: accent.withValues(alpha: isDark ? 0.35 : 0.40),
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.20),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.video_library_rounded, color: accent, size: 32),
          ),
        ),
      );
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: accentDim,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 28,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Icon(Icons.video_library_rounded, color: accent, size: 32),
    );
  }
}

// Progress bar
class _ProgressBar extends StatelessWidget {
  final bool isDark;
  final bool isGlass;
  final Color accent;
  final Color surfaceHi;

  const _ProgressBar({
    required this.isDark,
    required this.isGlass,
    required this.accent,
    required this.surfaceHi,
  });

  @override
  Widget build(BuildContext context) {
    final trackColor = isGlass
        ? Colors.white.withValues(alpha: isDark ? 0.10 : 0.35)
        : surfaceHi;

    return SizedBox(
      width: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          minHeight: 3,
          backgroundColor: trackColor,
          valueColor: AlwaysStoppedAnimation(accent),
        ),
      ),
    );
  }
}

// Error box
class _ErrorBox extends StatelessWidget {
  final String status;
  final bool isDark;
  final bool isGlass;
  final Color red;
  final Color redDim;
  final Color border;

  const _ErrorBox({
    required this.status,
    required this.isDark,
    required this.isGlass,
    required this.red,
    required this.redDim,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    if (isGlass) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: red.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: red.withValues(alpha: 0.40)),
            ),
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: TextStyle(color: red, fontSize: 12, height: 1.6),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: redDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: red.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: TextStyle(color: red, fontSize: 12, height: 1.6),
      ),
    );
  }
}

// Retry button
class _RetryButton extends StatelessWidget {
  final VoidCallback onRetry;
  final bool isDark;
  final bool isGlass;
  final Color accent;
  final Color accentDim;

  const _RetryButton({
    required this.onRetry,
    required this.isDark,
    required this.isGlass,
    required this.accent,
    required this.accentDim,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRetry,
      child: isGlass
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.18 : 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
              decoration: BoxDecoration(
                color: accentDim,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }
}
