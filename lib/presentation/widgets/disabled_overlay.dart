import 'package:flutter/material.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

class DisabledOverlay extends StatelessWidget {
  final bool disabled, isGlass;
  final String tooltip;
  final Widget child;
  const DisabledOverlay({
    super.key,
    required this.disabled,
    required this.tooltip,
    required this.isGlass,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!disabled) return child;
    return Tooltip(
      message: tooltip,
      child: IgnorePointer(
        child: Opacity(
          opacity: GlassTokens.disabledOpacity(isGlass: isGlass),
          child: child,
        ),
      ),
    );
  }
}
