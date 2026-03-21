import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C10),
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3366),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F8EF7).withValues(alpha: 0.3),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.video_library_rounded,
                  color: Color(0xFF4F8EF7),
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Frame Extractor',
                style: TextStyle(
                  color: Color(0xFFEDF0F7),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Effortless video frame extraction',
                style: TextStyle(color: Color(0xFF353C55), fontSize: 12),
              ),
              const SizedBox(height: 48),

              // Status / error
              if (!widget.hasError) ...[
                SizedBox(
                  width: 180,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: const Color(0xFF1A1E2A),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF4F8EF7)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.status,
                  style: const TextStyle(
                    color: Color(0xFF6B7594),
                    fontSize: 12,
                  ),
                ),
              ] else ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0E0E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE74C3C).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    widget.status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFE74C3C),
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ),
                if (widget.onRetry != null) ...[
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: widget.onRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F8EF7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF4F8EF7).withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          color: Color(0xFF4F8EF7),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
