import 'package:flutter/material.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

class SliderRow extends StatelessWidget {
  final AppColors c;
  final String label, display;
  final double value, min, max;
  final int divisions;
  final Color color;
  final bool disabled;
  final ValueChanged<double> onChanged;
  const SliderRow({
    super.key,
    required this.c,
    required this.label,
    required this.display,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.color,
    required this.onChanged,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final eff = disabled ? c.textMuted : color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
      child: Row(
        children: [
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64, maxWidth: 88),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: c.textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    display,
                    style: TextStyle(
                      color: eff,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: eff,
                inactiveTrackColor: c.surfaceHi,
                thumbColor: eff,
                overlayColor: eff.withValues(alpha: 0.15),
                disabledActiveTrackColor: c.surfaceHi,
                disabledInactiveTrackColor: c.surfaceHi,
                disabledThumbColor: c.textMuted,
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: disabled ? null : onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
