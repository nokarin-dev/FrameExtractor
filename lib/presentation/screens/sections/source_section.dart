import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frameextractor/core/app_prefs.dart';
import 'package:frameextractor/data/models/video_metadata.dart';
import 'package:frameextractor/data/services/ffmpeg/ffmpeg_service_base.dart';
import 'package:frameextractor/data/services/youtube_service.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';
import 'package:frameextractor/presentation/widgets/app_card.dart';
import 'package:frameextractor/presentation/widgets/app_divider.dart';
import 'package:frameextractor/presentation/widgets/clear_row.dart';
import 'package:frameextractor/presentation/widgets/file_row.dart';
import 'package:frameextractor/presentation/widgets/gloss_chip.dart';
import 'package:frameextractor/presentation/widgets/small_btn.dart';
import 'package:frameextractor/presentation/widgets/video_metadata_card.dart';

enum SourceMode { local, youtube }

class SourceSection extends StatefulWidget {
  final SourceMode mode;
  final String? videoPath;
  final VideoMetadata? videoMetadata;
  final bool metadataLoading;
  final YouTubeVideoInfo? ytInfo;
  final bool ytInfoLoading;
  final YouTubeQuality ytQuality;
  final bool disabled;
  final List<String> recentVideos;
  final FFmpegService ffmpegService;
  final TextEditingController ytUrlCtrl;

  final ValueChanged<SourceMode> onModeChanged;
  final ValueChanged<String> onVideoSelected;
  final VoidCallback onVideoClear;
  final ValueChanged<YouTubeVideoInfo?> onYtInfoChanged;
  final ValueChanged<YouTubeQuality> onYtQualityChanged;

  const SourceSection({
    super.key,
    required this.mode,
    required this.videoPath,
    required this.videoMetadata,
    required this.metadataLoading,
    required this.ytInfo,
    required this.ytInfoLoading,
    required this.ytQuality,
    required this.disabled,
    required this.recentVideos,
    required this.ffmpegService,
    required this.ytUrlCtrl,
    required this.onModeChanged,
    required this.onVideoSelected,
    required this.onVideoClear,
    required this.onYtInfoChanged,
    required this.onYtQualityChanged,
  });

  @override
  State<SourceSection> createState() => _SourceSectionState();
}

class _SourceSectionState extends State<SourceSection> {
  Future<void> _pickVideo() async {
    final r = await FilePicker.pickFiles(type: FileType.video);
    if (r?.files.single.path != null) {
      final path = r!.files.single.path!;
      await AppPrefs.addRecentVideo(path);
      widget.onVideoSelected(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final c = theme.colors;
    final isGlass = theme.isGlass;

    return Column(
      children: [
        _SourceTabRow(
          theme: theme,
          mode: widget.mode,
          disabled: widget.disabled,
          onChanged: widget.onModeChanged,
        ),
        const SizedBox(height: 10),

        // Local source
        if (widget.mode == SourceMode.local) ...[
          AppCard(
            theme: theme,
            label: 'VIDEO SOURCE',
            child: Column(
              children: [
                FileRow(
                  c: c,
                  icon: Icons.movie_rounded,
                  label: 'Video File',
                  value: widget.videoPath,
                  placeholder: 'Select a video file…',
                  accent: c.accent,
                  disabled: widget.disabled,
                  onTap: widget.disabled ? null : _pickVideo,
                  isGlass: isGlass,
                  isDark: theme.isDark,
                ),
                if (widget.recentVideos.isNotEmpty &&
                    widget.videoPath == null &&
                    !widget.disabled) ...[
                  AppDivider(c: c, isGlass: isGlass, isDark: theme.isDark),
                  _RecentRow(
                    c: c,
                    recents: widget.recentVideos,
                    onSelect: widget.onVideoSelected,
                    onClear: () async {
                      await AppPrefs.clearRecentVideos();
                      widget.onVideoSelected('');
                    },
                  ),
                ],
                if (widget.videoPath != null) ...[
                  AppDivider(c: c, isGlass: isGlass, isDark: theme.isDark),
                  ClearRow(
                    c: c,
                    disabled: widget.disabled,
                    isGlass: isGlass,
                    onTap: widget.onVideoClear,
                  ),
                ],
              ],
            ),
          ),

          // Metadata card
          if (widget.videoPath != null) ...[
            const SizedBox(height: 8),
            VideoMetadataCard(
              metadata: widget.videoMetadata,
              loading: widget.metadataLoading,
              theme: theme,
              ffmpegService: widget.ffmpegService,
              videoPath: widget.videoPath!,
            ),
          ],
        ],

        // YouTube source
        if (widget.mode == SourceMode.youtube)
          AppCard(
            theme: theme,
            label: 'YOUTUBE SOURCE',
            child: Column(
              children: [
                _YouTubeInputRow(
                  theme: theme,
                  ctrl: widget.ytUrlCtrl,
                  loading: widget.ytInfoLoading,
                  disabled: widget.disabled,
                  onFetch: () => widget.onYtInfoChanged(null),
                ),
                if (widget.ytInfo != null) ...[
                  AppDivider(c: c, isGlass: isGlass, isDark: theme.isDark),
                  _YtInfoRow(
                    theme: theme,
                    info: widget.ytInfo!,
                    disabled: widget.disabled,
                    onClear: () => widget.onYtInfoChanged(null),
                  ),
                  AppDivider(c: c, isGlass: isGlass, isDark: theme.isDark),
                  _YtQualityRow(
                    theme: theme,
                    selected: widget.ytQuality,
                    disabled: widget.disabled,
                    onChanged: widget.onYtQualityChanged,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// Tab row
class _SourceTabRow extends StatelessWidget {
  final AppTheme theme;
  final SourceMode mode;
  final bool disabled;
  final ValueChanged<SourceMode> onChanged;
  const _SourceTabRow({
    required this.theme,
    required this.mode,
    required this.disabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
    return Row(
      children: [
        _Tab(
          c: c,
          label: 'Local File',
          icon: Icons.folder_rounded,
          selected: mode == SourceMode.local,
          isGlass: theme.isGlass,
          isDark: theme.isDark,
          onTap: disabled ? null : () => onChanged(SourceMode.local),
        ),
        const SizedBox(width: 8),
        _Tab(
          c: c,
          label: 'YouTube',
          icon: Icons.play_circle_filled_rounded,
          selected: mode == SourceMode.youtube,
          accentColor: c.ytRed,
          isGlass: theme.isGlass,
          isDark: theme.isDark,
          onTap: disabled ? null : () => onChanged(SourceMode.youtube),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  final AppColors c;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color? accentColor;
  final bool isGlass, isDark;
  const _Tab({
    required this.c,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.isGlass,
    required this.isDark,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final eff = onTap != null ? (accentColor ?? c.accent) : c.textMuted;
    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isGlass
                ? (selected
                      ? eff.withValues(alpha: 0.18)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : c.surface.withValues(alpha: 0.55)))
                : (selected ? eff.withValues(alpha: 0.15) : Colors.transparent),
            borderRadius: BorderRadius.circular(isGlass ? 12 : 9),
            border: Border.all(
              color: selected
                  ? eff.withValues(alpha: 0.50)
                  : (isGlass
                        ? (isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : c.borderHi.withValues(alpha: 0.60))
                        : c.border),
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected
                    ? eff
                    : (isGlass && isDark
                          ? Colors.white.withValues(alpha: 0.40)
                          : c.textSec),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? eff
                      : (isGlass && isDark
                            ? Colors.white.withValues(alpha: 0.50)
                            : c.textSec),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// YouTube widgets
class _YouTubeInputRow extends StatelessWidget {
  final AppTheme theme;
  final TextEditingController ctrl;
  final bool loading, disabled;
  final VoidCallback onFetch;
  const _YouTubeInputRow({
    required this.theme,
    required this.ctrl,
    required this.loading,
    required this.disabled,
    required this.onFetch,
  });

  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.ytRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.play_circle_filled_rounded,
              color: c.ytRed,
              size: 17,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: ctrl,
              enabled: !disabled,
              style: TextStyle(color: c.textPri, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://youtube.com/watch?v=…',
                hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => onFetch(),
            ),
          ),
          const SizedBox(width: 8),
          SmallBtn(
            c: c,
            label: loading ? '…' : 'Fetch',
            onTap: (disabled || loading) ? null : onFetch,
            color: c.accent,
            isGlass: theme.isGlass,
            isDark: theme.isDark,
          ),
        ],
      ),
    );
  }
}

class _YtInfoRow extends StatelessWidget {
  final AppTheme theme;
  final YouTubeVideoInfo info;
  final bool disabled;
  final VoidCallback onClear;
  const _YtInfoRow({
    required this.theme,
    required this.info,
    required this.disabled,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.greenDim,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.check_rounded, color: c.green, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPri,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${info.uploader}  ·  ${info.durationFormatted}',
                  style: TextStyle(color: c.textSec, fontSize: 11),
                ),
              ],
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: disabled ? null : onClear,
              child: Icon(Icons.close_rounded, size: 15, color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _YtQualityRow extends StatelessWidget {
  final AppTheme theme;
  final YouTubeQuality selected;
  final bool disabled;
  final ValueChanged<YouTubeQuality> onChanged;
  const _YtQualityRow({
    required this.theme,
    required this.selected,
    required this.disabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quality',
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
            children: YouTubeQuality.values
                .map(
                  (q) => GlossChip(
                    c: c,
                    label: q.label,
                    selected: selected == q,
                    disabled: disabled,
                    onTap: disabled ? null : () => onChanged(q),
                    color: q == YouTubeQuality.audioOnly ? c.purple : c.accent,
                    isGlass: theme.isGlass,
                    isDark: theme.isDark,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// Recent videos row
class _RecentRow extends StatelessWidget {
  final AppColors c;
  final List<String> recents;
  final ValueChanged<String> onSelect;
  final VoidCallback onClear;
  const _RecentRow({
    required this.c,
    required this.recents,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 12, color: c.textMuted),
              const SizedBox(width: 4),
              Text(
                'Recent',
                style: TextStyle(
                  color: c.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onClear,
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: recents.take(4).map((p) {
              final name = p.split('/').last.split('\\').last;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onSelect(p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceHi,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.movie_outlined,
                          size: 11,
                          color: c.textMuted,
                        ),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.textSec, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
