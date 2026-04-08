import 'package:flutter/material.dart';
import 'package:frameextractor/core/app_constants.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';
import 'package:frameextractor/presentation/widgets/app_card.dart';
import 'package:frameextractor/presentation/widgets/app_divider.dart';
import 'package:frameextractor/presentation/widgets/disabled_overlay.dart';
import 'package:frameextractor/presentation/widgets/gloss_chip.dart';
import 'package:frameextractor/presentation/widgets/slider_row.dart';
import 'package:frameextractor/presentation/widgets/time_field.dart';

class SettingsSection extends StatelessWidget {
  final int fps;
  final int quality;
  final String format;
  final TextEditingController startTimeCtrl;
  final TextEditingController endTimeCtrl;
  final String? startTimeError;
  final String? endTimeError;
  final bool disabled;
  final String disabledHint;

  final ValueChanged<int> onFpsChanged;
  final ValueChanged<int> onQualityChanged;
  final ValueChanged<String> onFormatChanged;

  const SettingsSection({
    super.key,
    required this.fps,
    required this.quality,
    required this.format,
    required this.startTimeCtrl,
    required this.endTimeCtrl,
    required this.startTimeError,
    required this.endTimeError,
    required this.disabled,
    required this.disabledHint,
    required this.onFpsChanged,
    required this.onQualityChanged,
    required this.onFormatChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final c = theme.colors;
    final isGlass = theme.isGlass;

    return DisabledOverlay(
      disabled: disabled,
      tooltip: disabledHint,
      isGlass: isGlass,
      child: AppCard(
        theme: theme,
        label: 'EXTRACTION SETTINGS',
        child: Column(
          children: [
            // Time range
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: TimeField(
                      c: c,
                      controller: startTimeCtrl,
                      label: 'Start',
                      icon: Icons.play_circle_outline_rounded,
                      errorText: startTimeError,
                      disabled: disabled,
                      isGlass: isGlass,
                      isDark: theme.isDark,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: c.textMuted,
                      size: 14,
                    ),
                  ),
                  Expanded(
                    child: TimeField(
                      c: c,
                      controller: endTimeCtrl,
                      label: 'End',
                      icon: Icons.stop_circle_outlined,
                      errorText: endTimeError,
                      disabled: disabled,
                      isGlass: isGlass,
                      isDark: theme.isDark,
                    ),
                  ),
                ],
              ),
            ),
            AppDivider(c: c, isGlass: isGlass, isDark: theme.isDark),

            // FPS slider
            SliderRow(
              c: c,
              label: 'FPS',
              value: fps.toDouble(),
              display: '$fps fps',
              min: AppConstants.minFps.toDouble(),
              max: AppConstants.maxFps.toDouble(),
              divisions: AppConstants.maxFps - AppConstants.minFps,
              color: c.accent,
              disabled: disabled,
              onChanged: (v) => onFpsChanged(v.toInt()),
            ),
            AppDivider(c: c, isGlass: isGlass, isDark: theme.isDark),

            // Quality slider
            SliderRow(
              c: c,
              label: 'Quality',
              value: quality.toDouble(),
              display: '$quality%',
              min: 1,
              max: 100,
              divisions: 99,
              color: c.green,
              disabled: disabled,
              onChanged: (v) => onQualityChanged(v.toInt()),
            ),
            AppDivider(c: c, isGlass: isGlass, isDark: theme.isDark),

            // Format chips
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Format',
                    style: TextStyle(
                      color: c.textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: AppConstants.supportedFormats
                        .map(
                          (fmt) => GlossChip(
                            c: c,
                            label: fmt.toUpperCase(),
                            selected: format == fmt,
                            disabled: disabled,
                            onTap: disabled ? null : () => onFormatChanged(fmt),
                            isGlass: isGlass,
                            isDark: theme.isDark,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
