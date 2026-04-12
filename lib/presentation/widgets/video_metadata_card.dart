import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frameextractor/data/models/video_metadata.dart';
import 'package:frameextractor/data/services/ffmpeg/ffmpeg_service_base.dart';
import 'package:frameextractor/presentation/screens/frame_preview_screen.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

class VideoMetadataCard extends StatelessWidget {
  final VideoMetadata? metadata;
  final bool loading;
  final AppTheme theme;
  final FFmpegService ffmpegService;
  final String videoPath;
  final void Function(FramePreviewResult)? onTimeSelected;

  const VideoMetadataCard({
    super.key,
    required this.metadata,
    required this.loading,
    required this.theme,
    required this.ffmpegService,
    required this.videoPath,
    this.onTimeSelected,
  });

  void _openPreview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FramePreviewScreen(
          videoPath: videoPath,
          ffmpegService: ffmpegService,
          videoDuration: metadata?.duration,
          onTimeSelected: onTimeSelected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = theme.colors;

    if (loading) {
      return Container(
        height: 64,
        decoration: BoxDecoration(
          color: c.surfaceHi,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation(c.accent),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Reading video info…',
                style: TextStyle(color: c.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (metadata == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceHi,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          // Thumbnail
          GestureDetector(
            onTap: () => _openPreview(context),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                bottomLeft: Radius.circular(11),
              ),
              child: metadata!.thumbnailPath != null
                  ? Image.file(
                      File(metadata!.thumbnailPath!),
                      width: 90,
                      height: 64,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 90,
                      height: 64,
                      color: c.surface,
                      child: Icon(
                        Icons.movie_rounded,
                        color: c.textMuted,
                        size: 24,
                      ),
                    ),
            ),
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _InfoChip(
                        c: c,
                        icon: Icons.timer_outlined,
                        label: metadata!.durationFormatted,
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        c: c,
                        icon: Icons.aspect_ratio_rounded,
                        label: metadata!.resolutionLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _InfoChip(
                        c: c,
                        icon: Icons.speed_rounded,
                        label:
                            '${metadata!.fps.toStringAsFixed(metadata!.fps == metadata!.fps.roundToDouble() ? 0 : 2)} fps',
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        c: c,
                        icon: Icons.videocam_rounded,
                        label: metadata!.codec.toUpperCase(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Preview button
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Tooltip(
              message: 'Preview frames',
              child: GestureDetector(
                onTap: () => _openPreview(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.accent.withValues(alpha: 0.30)),
                  ),
                  child: Icon(Icons.preview_rounded, color: c.accent, size: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final AppColors c;
  final IconData icon;
  final String label;
  const _InfoChip({required this.c, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: c.textMuted),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(color: c.textSec, fontSize: 11)),
    ],
  );
}
