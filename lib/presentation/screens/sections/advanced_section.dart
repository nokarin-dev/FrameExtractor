import 'package:flutter/material.dart';
import 'package:frameextractor/core/app_constants.dart';
import 'package:frameextractor/data/models/extraction_params.dart';
import 'package:frameextractor/data/models/extraction_present.dart';
import 'package:frameextractor/core/app_prefs.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';
import 'package:frameextractor/presentation/widgets/app_card.dart';
import 'package:frameextractor/presentation/widgets/app_divider.dart';
import 'package:frameextractor/presentation/widgets/compact_field.dart';
import 'package:frameextractor/presentation/widgets/slider_row.dart';

class AdvancedSection extends StatelessWidget {
  final double scale;
  final String framePrefix;
  final bool openFolderOnDone;
  final ExtractionParams? currentParams;

  final ValueChanged<double> onScaleChanged;
  final ValueChanged<String> onPrefixChanged;
  final ValueChanged<bool> onOpenFolderChanged;
  final VoidCallback onToast;

  const AdvancedSection({
    super.key,
    required this.scale,
    required this.framePrefix,
    required this.openFolderOnDone,
    required this.currentParams,
    required this.onScaleChanged,
    required this.onPrefixChanged,
    required this.onOpenFolderChanged,
    required this.onToast,
  });

  void _showSavePresetDialog(BuildContext context) {
    final theme = AppTheme.of(context);
    final c = theme.colors;
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: theme.isDark ? 0.55 : 0.30),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.isGlass
                ? c.surface.withValues(alpha: theme.isDark ? 0.30 : 0.82)
                : c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.isGlass
                  ? (theme.isDark
                        ? Colors.white.withValues(alpha: 0.20)
                        : c.borderHi)
                  : c.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.isDark ? 0.45 : 0.12,
                ),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Save Preset',
                style: TextStyle(
                  color: c.textPri,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Saves current FPS, format, quality, scale, time range, and prefix.',
                style: TextStyle(color: c.textSec, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: TextStyle(color: c.textPri, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Preset name…',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: theme.isGlass
                      ? (theme.isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : c.surfaceHi)
                      : c.surfaceHi,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: c.surfaceHi,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: c.border),
                          ),
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: c.textSec,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty || currentParams == null) return;
                        final preset = ExtractionPreset(
                          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                          name: name,
                          fps: currentParams!.fps,
                          format: currentParams!.format,
                          imageQuality: currentParams!.imageQuality,
                          resolutionScale: currentParams!.resolutionScale,
                          startTime: currentParams!.startTime,
                          endTime: currentParams!.endTime,
                          frameNamePrefix: currentParams!.frameNamePrefix,
                          createdAt: DateTime.now(),
                        );
                        await AppPrefs.savePreset(preset);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        onToast();
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: c.purple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: c.purple.withValues(alpha: 0.50),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Save',
                              style: TextStyle(
                                color: c.purple,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final c = theme.colors;
    final isGlass = theme.isGlass;

    return AppCard(
      theme: theme,
      label: 'ADVANCED',
      child: Column(
        children: [
          SliderRow(
            c: c,
            label: 'Scale',
            value: scale,
            display: '${(scale * 100).toInt()}%',
            min: AppConstants.minScale,
            max: AppConstants.maxScale,
            divisions: 19,
            color: c.orange,
            onChanged: onScaleChanged,
          ),
          AppDivider(c: c, isGlass: isGlass, isDark: theme.isDark),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Frame prefix',
                  style: TextStyle(
                    color: c.textSec,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                CompactField(
                  c: c,
                  initialValue: framePrefix,
                  hint: 'frame_',
                  onChanged: onPrefixChanged,
                  isGlass: isGlass,
                  isDark: theme.isDark,
                ),
              ],
            ),
          ),
          AppDivider(c: c, isGlass: isGlass, isDark: theme.isDark),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Open folder when done',
                        style: TextStyle(
                          color: c.textSec,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Auto-open output directory after extraction',
                        style: TextStyle(color: c.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: openFolderOnDone,
                  onChanged: onOpenFolderChanged,
                  activeThumbColor: c.accent,
                  trackColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected)
                        ? c.accentDim
                        : c.surfaceHi,
                  ),
                  thumbColor: WidgetStateProperty.all(Colors.white),
                ),
              ],
            ),
          ),
          AppDivider(c: c, isGlass: isGlass, isDark: theme.isDark),
          Padding(
            padding: const EdgeInsets.all(14),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _showSavePresetDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isGlass
                        ? c.purple.withValues(alpha: 0.12)
                        : c.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isGlass
                          ? c.purple.withValues(alpha: 0.35)
                          : c.border,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_add_rounded,
                        color: c.purple,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Save as Preset',
                        style: TextStyle(
                          color: c.purple,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
