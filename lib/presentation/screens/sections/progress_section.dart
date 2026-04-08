import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:frameextractor/presentation/bloc/extraction_state.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

class ProgressSection extends StatelessWidget {
  final ExtractionInProgress state;
  final Animation<double> pulseAnim;

  const ProgressSection({
    super.key,
    required this.state,
    required this.pulseAnim,
  });

  String _fmtDuration(Duration d) {
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final c = theme.colors;
    final p = state.progress;

    final isDownloading = state.phase == 'downloading';
    final isBatch = state.isBatch;

    final color = isDownloading ? c.ytRed : c.accent;
    final bgTint = isDownloading
        ? c.redDim.withValues(alpha: 0.5)
        : c.accentDim.withValues(alpha: 0.5);

    Widget content = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Batch indicator
          if (isBatch) ...[
            Row(
              children: [
                Icon(Icons.queue_rounded, size: 11, color: c.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Job ${state.batchIndex + 1} of ${state.batchTotal}',
                  style: TextStyle(color: c.textMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          // Main status row
          Row(
            children: [
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, _) => Opacity(
                  opacity: pulseAnim.value,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.message,
                  style: TextStyle(
                    color: c.textPri,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${p.percentage}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.percentage / 100,
              minHeight: 3,
              backgroundColor: c.surfaceHi,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),

          // Frame count & ETA
          if (p.estimatedFrames > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.image_outlined, size: 11, color: c.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${p.framesProcessed} / ${p.estimatedFrames} frames',
                  style: TextStyle(color: c.textSec, fontSize: 11),
                ),
                const Spacer(),
                if (p.timeRemaining != null) ...[
                  Icon(Icons.timer_outlined, size: 11, color: c.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'ETA ${_fmtDuration(p.timeRemaining!)}',
                    style: TextStyle(color: c.textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );

    final card = theme.isGlass
        ? GlassContainer(
            useOwnLayer: true,
            settings: LiquidGlassSettings(
              thickness: 0.55,
              blur: 8,
              glassColor: color.withValues(alpha: 0.15),
            ),
            shape: LiquidRoundedRectangle(borderRadius: 16),
            child: content,
          )
        : Container(
            decoration: BoxDecoration(
              color: bgTint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: content,
          );

    final label = switch (state.phase) {
      'downloading' => 'DOWNLOADING',
      'copying' => 'COPYING',
      'batch' => 'BATCH',
      _ => 'EXTRACTING',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              color: c.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        card,
      ],
    );
  }
}
