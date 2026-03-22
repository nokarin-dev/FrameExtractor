import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:window_manager/window_manager.dart';

import 'package:frameextractor/data/models/extraction_params.dart';
import 'package:frameextractor/data/services/youtube_service.dart';
import 'package:frameextractor/presentation/bloc/extraction_bloc.dart';
import 'package:frameextractor/presentation/bloc/extraction_event.dart';
import 'package:frameextractor/presentation/bloc/extraction_state.dart';

// Color palette
class _C {
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

enum _SourceMode { local, youtube }

// Main screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _ytUrlCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController(text: '00:00:00');
  final _endTimeCtrl = TextEditingController(text: '00:00:05');
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  _SourceMode _sourceMode = _SourceMode.local;
  String? _videoPath;
  String? _outputDirectory;
  int _fps = 30;
  String _format = 'jpg';
  int _quality = 90;
  double _scale = 1.0;
  YouTubeQuality _ytQuality = YouTubeQuality.p1080;
  bool _ytInfoLoading = false;
  YouTubeVideoInfo? _ytInfo;
  bool _showAdvanced = false;
  bool _openFolderOnDone = true;
  String _framePrefix = 'frame_';

  bool get _settingsEnabled {
    final bloc = context.read<ExtractionBloc>();
    if (bloc.state is ExtractionInProgress) return false;
    if (_outputDirectory == null) return false;
    if (_sourceMode == _SourceMode.local) return _videoPath != null;
    return _ytInfo != null;
  }

  bool get _canExtract {
    if (_outputDirectory == null) return false;
    if (_sourceMode == _SourceMode.local) return _videoPath != null;
    return _ytInfo != null && _ytUrlCtrl.text.trim().isNotEmpty;
  }

  String get _settingsHint {
    if (_sourceMode == _SourceMode.local && _videoPath == null) {
      return 'Select a video file first';
    }
    if (_outputDirectory == null) return 'Select an output folder first';
    if (_sourceMode == _SourceMode.youtube && _ytInfo == null) {
      return 'Fetch a YouTube video first';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _ytUrlCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: BlocListener<ExtractionBloc, ExtractionState>(
          listener: _onStateChange,
          child: BlocBuilder<ExtractionBloc, ExtractionState>(
            builder: (context, state) {
              final extracting = state is ExtractionInProgress;
              return Column(
                children: [
                  _buildTitleBar(),
                  _buildSourceTabs(disabled: extracting),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      child: Column(
                        children: [
                          if (_sourceMode == _SourceMode.local)
                            _buildLocalSourceCard(disabled: extracting)
                          else
                            _buildYouTubeCard(disabled: extracting),
                          const SizedBox(height: 10),
                          _buildOutputCard(disabled: extracting),
                          const SizedBox(height: 10),
                          _buildSettingsCard(disabled: !_settingsEnabled),
                          const SizedBox(height: 4),
                          _buildAdvancedToggle(disabled: !_settingsEnabled),
                          if (_showAdvanced && _settingsEnabled) ...[
                            const SizedBox(height: 10),
                            _buildAdvancedCard(),
                          ],
                          const SizedBox(height: 10),
                          if (extracting) _buildProgressCard(state),
                          const SizedBox(height: 10),
                          _buildActionButtons(extracting: extracting),
                          if (!_canExtract && !extracting) ...[
                            const SizedBox(height: 8),
                            _buildHint(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Title bar
  Widget _buildTitleBar() {
    final isDesktop = !Platform.isAndroid && !Platform.isIOS;
    return GestureDetector(
      onPanStart: isDesktop ? (_) => windowManager.startDragging() : null,
      child: Container(
        color: _C.surface,
        padding: EdgeInsets.only(
          top: isDesktop ? 12 : MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 10,
          bottom: 10,
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _C.accentDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.video_library_rounded,
                color: _C.accent,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Frame Extractor',
                    style: TextStyle(
                      color: _C.textPri,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    'ffmpeg · yt-dlp',
                    style: TextStyle(color: _C.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            _TitleBarBtn(
              icon: Icons.terminal_rounded,
              tooltip: 'View logs',
              onTap: _showLogPanel,
            ),
            if (isDesktop) ...[
              const SizedBox(width: 4),
              _TitleBarBtn(
                icon: Icons.remove_rounded,
                tooltip: 'Minimize',
                onTap: () => windowManager.minimize(),
              ),
              const SizedBox(width: 4),
              _TitleBarBtn(
                icon: Icons.close_rounded,
                tooltip: 'Close',
                onTap: () => windowManager.close(),
                hoverColor: _C.red,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Source tabs
  Widget _buildSourceTabs({required bool disabled}) {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _SourceTab(
            label: 'Local File',
            icon: Icons.folder_rounded,
            selected: _sourceMode == _SourceMode.local,
            onTap: disabled
                ? null
                : () => setState(() {
                    _sourceMode = _SourceMode.local;
                    _ytInfo = null;
                  }),
          ),
          const SizedBox(width: 8),
          _SourceTab(
            label: 'YouTube',
            icon: Icons.play_circle_filled_rounded,
            selected: _sourceMode == _SourceMode.youtube,
            accentColor: _C.ytRed,
            onTap: disabled
                ? null
                : () => setState(() => _sourceMode = _SourceMode.youtube),
          ),
        ],
      ),
    );
  }

  // Local source card
  Widget _buildLocalSourceCard({required bool disabled}) {
    return _Card(
      label: 'VIDEO SOURCE',
      child: Column(
        children: [
          _FileRow(
            icon: Icons.movie_rounded,
            label: 'Video File',
            value: _videoPath,
            placeholder: 'Select a video file…',
            accent: _C.accent,
            disabled: disabled,
            onTap: disabled ? null : _pickVideoFile,
          ),
          if (_videoPath != null) ...[
            Divider(color: _C.border, height: 1),
            _ClearRow(
              disabled: disabled,
              onTap: () => setState(() => _videoPath = null),
            ),
          ],
        ],
      ),
    );
  }

  // YouTube card
  Widget _buildYouTubeCard({required bool disabled}) {
    return _Card(
      label: 'YOUTUBE SOURCE',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _C.ytRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.play_circle_filled_rounded,
                    color: _C.ytRed,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ytUrlCtrl,
                    enabled: !disabled,
                    style: const TextStyle(color: _C.textPri, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'https://youtube.com/watch?v=…',
                      hintStyle: TextStyle(color: _C.textMuted, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _fetchYtInfo(),
                  ),
                ),
                const SizedBox(width: 8),
                _SmallBtn(
                  label: _ytInfoLoading ? '…' : 'Fetch',
                  onTap: (disabled || _ytInfoLoading) ? null : _fetchYtInfo,
                  color: _C.accent,
                ),
              ],
            ),
          ),
          if (_ytInfo != null) ...[
            Divider(color: _C.border, height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _C.greenDim,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: _C.green,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _ytInfo!.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.textPri,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_ytInfo!.uploader}  ·  ${_ytInfo!.durationFormatted}',
                          style: TextStyle(color: _C.textSec, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: disabled
                          ? null
                          : () => setState(() => _ytInfo = null),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: _C.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: _C.border, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quality',
                    style: TextStyle(
                      color: _C.textSec,
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
                          (q) => _Chip(
                            label: q.label,
                            selected: _ytQuality == q,
                            disabled: disabled,
                            onTap: disabled
                                ? null
                                : () => setState(() => _ytQuality = q),
                            color: q == YouTubeQuality.audioOnly
                                ? _C.purple
                                : _C.accent,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Output card
  Widget _buildOutputCard({required bool disabled}) {
    return _Card(
      label: 'OUTPUT',
      child: Column(
        children: [
          _FileRow(
            icon: Icons.folder_rounded,
            label: 'Output Folder',
            value: _outputDirectory,
            placeholder: 'Select output directory…',
            accent: _C.purple,
            disabled: disabled,
            onTap: disabled ? null : _pickOutputDirectory,
          ),
          if (_outputDirectory != null) ...[
            Divider(color: _C.border, height: 1),
            _ClearRow(
              disabled: disabled,
              onTap: () => setState(() => _outputDirectory = null),
            ),
          ],
        ],
      ),
    );
  }

  // Extraction settings card
  Widget _buildSettingsCard({required bool disabled}) {
    return _DisabledOverlay(
      disabled: disabled,
      tooltip: _settingsHint,
      child: _Card(
        label: 'EXTRACTION SETTINGS',
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      controller: _startTimeCtrl,
                      label: 'Start',
                      icon: Icons.play_circle_outline_rounded,
                      disabled: disabled,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: _C.textMuted,
                      size: 14,
                    ),
                  ),
                  Expanded(
                    child: _TimeField(
                      controller: _endTimeCtrl,
                      label: 'End',
                      icon: Icons.stop_circle_outlined,
                      disabled: disabled,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: _C.border, height: 1),
            _SliderRow(
              label: 'FPS',
              value: _fps.toDouble(),
              display: '$_fps fps',
              min: 1,
              max: 60,
              divisions: 59,
              color: _C.accent,
              disabled: disabled,
              onChanged: (v) => setState(() => _fps = v.toInt()),
            ),
            Divider(color: _C.border, height: 1),
            _SliderRow(
              label: 'Quality',
              value: _quality.toDouble(),
              display: '$_quality%',
              min: 1,
              max: 100,
              divisions: 99,
              color: _C.green,
              disabled: disabled,
              onChanged: (v) => setState(() => _quality = v.toInt()),
            ),
            Divider(color: _C.border, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Format',
                    style: TextStyle(
                      color: _C.textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final fmt in ['png', 'jpg', 'webp', 'bmp'])
                        _Chip(
                          label: fmt.toUpperCase(),
                          selected: _format == fmt,
                          disabled: disabled,
                          onTap: disabled
                              ? null
                              : () => setState(() => _format = fmt),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Advanced card
  Widget _buildAdvancedCard() {
    return _Card(
      label: 'ADVANCED',
      child: Column(
        children: [
          _SliderRow(
            label: 'Scale',
            value: _scale,
            display: '${(_scale * 100).toInt()}%',
            min: 0.1,
            max: 2.0,
            divisions: 19,
            color: _C.orange,
            onChanged: (v) => setState(() => _scale = v),
          ),
          Divider(color: _C.border, height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Frame prefix',
                  style: TextStyle(
                    color: _C.textSec,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _CompactField(
                  initialValue: _framePrefix,
                  hint: 'frame_',
                  onChanged: (v) => _framePrefix = v,
                ),
              ],
            ),
          ),
          Divider(color: _C.border, height: 1),
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
                          color: _C.textSec,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Auto-open output directory after extraction',
                        style: TextStyle(color: _C.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _openFolderOnDone,
                  onChanged: (v) => setState(() => _openFolderOnDone = v),
                  activeThumbColor: _C.accent,
                  trackColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected)
                        ? _C.accentDim
                        : _C.surfaceHi,
                  ),
                  thumbColor: WidgetStateProperty.all(Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedToggle({required bool disabled}) {
    return Opacity(
      opacity: disabled ? 0.35 : 1.0,
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: disabled
              ? null
              : () => setState(() => _showAdvanced = !_showAdvanced),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _showAdvanced
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _C.textMuted,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _showAdvanced ? 'Hide advanced' : 'Advanced options',
                  style: const TextStyle(
                    color: _C.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Progress card
  Widget _buildProgressCard(ExtractionInProgress state) {
    final p = state.progress;
    final isDownloading = state.phase == 'downloading';
    final color = isDownloading ? _C.ytRed : _C.accent;
    final bgTint = isDownloading
        ? _C.redDim.withValues(alpha: 0.5)
        : _C.accentDim.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            isDownloading ? 'DOWNLOADING' : 'EXTRACTING',
            style: const TextStyle(
              color: _C.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: bgTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, _) => Opacity(
                        opacity: _pulseAnim.value,
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
                        style: const TextStyle(
                          color: _C.textPri,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: color.withValues(alpha: 0.35),
                        ),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: p.percentage / 100,
                    minHeight: 3,
                    backgroundColor: _C.surfaceHi,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                if (p.estimatedFrames > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.image_outlined, size: 11, color: _C.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${p.framesProcessed} / ${p.estimatedFrames} frames',
                        style: TextStyle(color: _C.textSec, fontSize: 11),
                      ),
                      const Spacer(),
                      if (p.timeRemaining != null) ...[
                        Icon(
                          Icons.timer_outlined,
                          size: 11,
                          color: _C.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ETA ${_fmtDuration(p.timeRemaining!)}',
                          style: TextStyle(color: _C.textMuted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Action buttons
  Widget _buildActionButtons({required bool extracting}) {
    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            label: extracting ? 'Working…' : 'Extract Frames',
            icon: extracting
                ? Icons.hourglass_top_rounded
                : Icons.play_arrow_rounded,
            color: _C.accent,
            onPressed: (extracting || !_canExtract) ? null : _startExtraction,
          ),
        ),
        if (extracting) ...[
          const SizedBox(width: 10),
          _ActionBtn(
            label: 'Cancel',
            icon: Icons.stop_rounded,
            color: _C.red,
            onPressed: _cancelExtraction,
            compact: true,
          ),
        ],
      ],
    );
  }

  // Hint bar
  Widget _buildHint() {
    final String msg;
    if (_sourceMode == _SourceMode.local && _videoPath == null) {
      msg = 'Select a video file to continue';
    } else if (_outputDirectory == null) {
      msg = 'Select an output folder to continue';
    } else if (_sourceMode == _SourceMode.youtube && _ytInfo == null) {
      msg = 'Fetch a YouTube video to continue';
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.accentDim,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: _C.accent.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          Text(
            msg,
            style: TextStyle(
              color: _C.accent.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showLogPanel() {
    final bloc = context.read<ExtractionBloc>();
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => _LogPanel(logs: bloc.logs),
    );
  }

  void _onStateChange(BuildContext context, ExtractionState state) {
    if (state is ExtractionSuccess) {
      _toast(state.message, _C.green, _C.greenDim, Icons.check_circle_rounded);
      if (_openFolderOnDone && state.outputDirectory.isNotEmpty) {
        _openFolder(state.outputDirectory);
      }
    } else if (state is ExtractionFailure) {
      _toast(state.error, _C.red, _C.redDim, Icons.error_rounded);
    } else if (state is ExtractionCancelled) {
      _toast(
        'Extraction cancelled',
        _C.orange,
        _C.orange.withValues(alpha: 0.15),
        Icons.cancel_rounded,
      );
    }
  }

  void _toast(String msg, Color fg, Color bg, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: fg, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: fg.withValues(alpha: 0.3)),
        ),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _pickVideoFile() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.video);
    if (r?.files.single.path != null) {
      setState(() => _videoPath = r!.files.single.path);
    }
  }

  Future<void> _pickOutputDirectory() async {
    final r = await FilePicker.platform.getDirectoryPath();
    if (r != null) setState(() => _outputDirectory = r);
  }

  Future<void> _fetchYtInfo() async {
    final url = _ytUrlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _ytInfoLoading = true;
      _ytInfo = null;
    });
    final svc = YouTubeService();
    final info = await svc.getVideoInfo(url);
    setState(() {
      _ytInfo = info;
      _ytInfoLoading = false;
    });
    if (info == null) {
      _toast(
        'Could not fetch video info. Check the URL or yt-dlp.',
        _C.red,
        _C.redDim,
        Icons.error_rounded,
      );
    }
  }

  void _startExtraction() {
    final baseParams = ExtractionParams(
      videoPath: _videoPath ?? '',
      outputDirectory: _outputDirectory!,
      startTime: _startTimeCtrl.text,
      endTime: _endTimeCtrl.text,
      fps: _fps,
      format: _format,
      imageQuality: _quality,
      resolutionScale: _scale,
      frameNamePrefix: _framePrefix,
    );
    if (_sourceMode == _SourceMode.youtube) {
      context.read<ExtractionBloc>().add(
        StartYouTubeExtraction(
          url: _ytUrlCtrl.text.trim(),
          quality: _ytQuality,
          params: baseParams,
        ),
      );
    } else {
      context.read<ExtractionBloc>().add(StartExtraction(baseParams));
    }
  }

  void _cancelExtraction() =>
      context.read<ExtractionBloc>().add(CancelExtraction());

  void _openFolder(String path) {
    if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      Process.run('open', [path]);
    } else {
      Process.run('xdg-open', [path]);
    }
  }

  String _fmtDuration(Duration d) {
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }
}

// Disabled overlay
class _DisabledOverlay extends StatelessWidget {
  final bool disabled;
  final String tooltip;
  final Widget child;
  const _DisabledOverlay({
    required this.disabled,
    required this.tooltip,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    if (!disabled) return child;
    return Tooltip(
      message: tooltip,
      child: IgnorePointer(child: Opacity(opacity: 0.38, child: child)),
    );
  }
}

// Card container
class _Card extends StatelessWidget {
  final String label;
  final Widget child;
  const _Card({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: _C.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(14), child: child),
      ),
    ],
  );
}

// Clear button
class _ClearRow extends StatelessWidget {
  final bool disabled;
  final VoidCallback onTap;
  const _ClearRow({required this.disabled, required this.onTap});
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
    child: InkWell(
      onTap: disabled ? null : onTap,
      mouseCursor: disabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              size: 14,
              color: disabled ? _C.textMuted : _C.red.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              'Clear',
              style: TextStyle(
                color: disabled ? _C.textMuted : _C.red.withValues(alpha: 0.7),
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

// Title bar button
class _TitleBarBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color hoverColor;
  const _TitleBarBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.hoverColor = _C.borderHi,
  });
  @override
  State<_TitleBarBtn> createState() => _TitleBarBtnState();
}

class _TitleBarBtnState extends State<_TitleBarBtn> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _hov ? widget.hoverColor : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            widget.icon,
            color: _hov ? Colors.white : _C.textSec,
            size: 16,
          ),
        ),
      ),
    ),
  );
}

// Source tab
class _SourceTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color accentColor;
  const _SourceTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.accentColor = _C.accent,
  });
  @override
  Widget build(BuildContext context) {
    final eff = onTap != null ? accentColor : _C.textMuted;
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
            color: selected ? eff.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? eff.withValues(alpha: 0.5) : _C.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? eff : _C.textMuted, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? eff : _C.textMuted,
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

// File row
class _FileRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final Color accent;
  final bool disabled;
  final VoidCallback? onTap;
  const _FileRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.accent,
    this.disabled = false,
    this.onTap,
  });
  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value != null;
    final name = hasValue
        ? widget.value!.split('/').last.split('\\').last
        : widget.placeholder;
    final eff = widget.disabled ? _C.textMuted : widget.accent;

    return MouseRegion(
      cursor: widget.disabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: InkWell(
        onTap: widget.onTap,
        mouseCursor: widget.disabled
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        borderRadius: hasValue
            ? const BorderRadius.vertical(top: Radius.circular(14))
            : BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: (!widget.disabled && _hov)
                ? _C.borderHi.withValues(alpha: 0.5)
                : Colors.transparent,
            borderRadius: hasValue
                ? const BorderRadius.vertical(top: Radius.circular(14))
                : BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: eff.withValues(alpha: widget.disabled ? 0.05 : 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(widget.icon, color: eff, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: _C.textSec,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasValue ? _C.textPri : _C.textMuted,
                          fontSize: 13,
                          fontWeight: hasValue
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  hasValue
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: hasValue ? eff : _C.textMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Slider row
class _SliderRow extends StatelessWidget {
  final String label, display;
  final double value, min, max;
  final int divisions;
  final Color color;
  final bool disabled;
  final ValueChanged<double> onChanged;
  const _SliderRow({
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
    final eff = disabled ? _C.textMuted : color;
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
                      color: _C.textSec,
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
            child: MouseRegion(
              cursor: disabled
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: eff,
                  inactiveTrackColor: _C.surfaceHi,
                  thumbColor: eff,
                  overlayColor: eff.withValues(alpha: 0.15),
                  disabledActiveTrackColor: _C.surfaceHi,
                  disabledInactiveTrackColor: _C.surfaceHi,
                  disabledThumbColor: _C.textMuted,
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
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
          ),
        ],
      ),
    );
  }
}

// Chip
class _Chip extends StatelessWidget {
  final String label;
  final bool selected, disabled;
  final VoidCallback? onTap;
  final Color color;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabled = false,
    this.color = _C.accent,
  });
  @override
  Widget build(BuildContext context) {
    final eff = disabled ? _C.textMuted : color;
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? eff : _C.surfaceHi,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: selected ? eff : _C.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (disabled ? _C.textMuted : _C.textSec),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// Time field
class _TimeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool disabled;
  const _TimeField({
    required this.controller,
    required this.label,
    required this.icon,
    this.disabled = false,
  });
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.text,
    child: TextField(
      controller: controller,
      enabled: !disabled,
      style: TextStyle(
        color: disabled ? _C.textMuted : _C.textPri,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: _C.textSec,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, color: _C.textMuted, size: 14),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 30,
          minHeight: 30,
        ),
        filled: true,
        fillColor: disabled ? _C.disabled : _C.surfaceHi,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: _C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: _C.border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: _C.border.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _C.accent, width: 1.5),
        ),
      ),
    ),
  );
}

// Compact text field
class _CompactField extends StatelessWidget {
  final String initialValue, hint;
  final ValueChanged<String> onChanged;
  const _CompactField({
    required this.initialValue,
    required this.hint,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.text,
    child: TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      style: const TextStyle(color: _C.textPri, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _C.textMuted, fontSize: 13),
        filled: true,
        fillColor: _C.surfaceHi,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: _C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: _C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _C.accent, width: 1.5),
        ),
      ),
    ),
  );
}

// Small button
class _SmallBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  const _SmallBtn({
    required this.label,
    required this.onTap,
    this.color = _C.accent,
  });
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: onTap == null ? 0.05 : 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: onTap == null ? 0.2 : 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onTap == null ? _C.textMuted : color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

// Action button
class _ActionBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool compact;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
    this.compact = false,
  });
  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    final off = widget.onPressed == null;
    final col = off ? _C.textMuted : widget.color;
    return MouseRegion(
      cursor: off ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 20 : 0,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: off
                ? _C.surfaceHi
                : _hov
                ? widget.color.withValues(alpha: 0.22)
                : widget.color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: off
                  ? _C.border
                  : widget.color.withValues(alpha: _hov ? 0.7 : 0.45),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: col, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: col,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Log panel bottom sheet
class _LogPanel extends StatelessWidget {
  final List<String> logs;
  const _LogPanel({required this.logs});
  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.55,
    maxChildSize: 0.9,
    minChildSize: 0.3,
    builder: (_, ctrl) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _C.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.terminal_rounded, color: _C.accent, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Process Log',
                style: TextStyle(
                  color: _C.textPri,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.surfaceHi,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${logs.length} lines',
                  style: TextStyle(
                    color: _C.textSec,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(color: _C.border, height: 1),
        Expanded(
          child: logs.isEmpty
              ? Center(
                  child: Text(
                    'No logs yet.',
                    style: TextStyle(color: _C.textMuted, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: logs.length,
                  itemBuilder: (_, i) {
                    final line = logs[i];
                    final isErr = line.startsWith('[ERR]');
                    final isWarn = line.startsWith('[WARN]');
                    final isInfo =
                        line.startsWith('[INFO]') ||
                        line.startsWith('[Android]') ||
                        line.startsWith('[Copy]');
                    final color = isErr
                        ? _C.red
                        : isWarn
                        ? _C.orange
                        : isInfo
                        ? _C.accent
                        : _C.textSec;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        line,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: logs.join('\n')));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logs copied to clipboard'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _C.surfaceHi,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.border),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.copy_rounded, color: _C.textSec, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Copy all logs',
                      style: TextStyle(
                        color: _C.textSec,
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
