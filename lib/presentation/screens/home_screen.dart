import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:window_manager/window_manager.dart'; // add to pubspec: window_manager: ^0.3.8

import 'package:frameextractor/data/models/extraction_params.dart';
import 'package:frameextractor/data/services/youtube_service.dart';
import 'package:frameextractor/presentation/bloc/extraction_bloc.dart';
import 'package:frameextractor/presentation/bloc/extraction_event.dart';
import 'package:frameextractor/presentation/bloc/extraction_state.dart';

class _C {
  static const bg = Color(0xFF0A0C10);
  static const surface = Color(0xFF13161E);
  static const surfaceHi = Color(0xFF1A1E2A);
  static const border = Color(0xFF222636);
  static const accent = Color(0xFF4F8EF7);
  static const accentDim = Color(0xFF1E3366);
  static const green = Color(0xFF2ECC71);
  static const red = Color(0xFFE74C3C);
  static const orange = Color(0xFFF39C12);
  static const purple = Color(0xFF9B6EF7);
  static const textPri = Color(0xFFEDF0F7);
  static const textSec = Color(0xFF6B7594);
  static const textMuted = Color(0xFF353C55);
  static const ytRed = Color(0xFFFF0000);
}

// Source Mode
enum _SourceMode { local, youtube }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _ytUrlCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController(text: '00:00:00');
  final _endTimeCtrl = TextEditingController(text: '00:00:05');
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // State
  _SourceMode _sourceMode = _SourceMode.local;
  String? _videoPath;
  String? _outputDirectory;
  int _fps = 30;
  String _format = 'png';
  int _quality = 100;
  double _scale = 1.0;
  YouTubeQuality _ytQuality = YouTubeQuality.p1080;
  bool _ytInfoLoading = false;
  YouTubeVideoInfo? _ytInfo;

  // Feature toggles
  bool _showAdvanced = false;
  bool _openFolderOnDone = true;
  String _framePrefix = 'frame_';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.35,
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

  // Build
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: BlocListener<ExtractionBloc, ExtractionState>(
          listener: _onStateChange,
          child: Column(
            children: [
              _buildTitleBar(),
              _buildSourceTabs(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (_sourceMode == _SourceMode.local)
                          _buildLocalSourceCard()
                        else
                          _buildYouTubeCard(),
                        const SizedBox(height: 10),
                        _buildOutputCard(),
                        const SizedBox(height: 10),
                        _buildSettingsCard(),
                        const SizedBox(height: 4),
                        _buildAdvancedToggle(),
                        if (_showAdvanced) ...[
                          const SizedBox(height: 10),
                          _buildAdvancedCard(),
                        ],
                        const SizedBox(height: 10),
                        _buildProgressCard(),
                        const SizedBox(height: 12),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Title Bar
  Widget _buildTitleBar() {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        color: _C.surface,
        padding: EdgeInsets.only(
          top: Platform.isLinux || Platform.isWindows || Platform.isMacOS
              ? 12
              : MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 10,
          bottom: 10,
        ),
        child: Row(
          children: [
            // App icon
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
            // Log button
            _TitleBarBtn(
              icon: Icons.terminal_rounded,
              tooltip: 'View logs',
              onTap: _showLogPanel,
            ),
            const SizedBox(width: 4),

            // Desktop: Minimize & Close Button
            if (!Platform.isAndroid && !Platform.isIOS) ...{
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
            },
          ],
        ),
      ),
    );
  }

  // Source Tabs
  Widget _buildSourceTabs() {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _SourceTab(
            label: 'Local File',
            icon: Icons.folder_rounded,
            selected: _sourceMode == _SourceMode.local,
            onTap: () => setState(() => _sourceMode = _SourceMode.local),
          ),
          const SizedBox(width: 8),
          _SourceTab(
            label: 'YouTube',
            icon: Icons.play_circle_filled_rounded,
            selected: _sourceMode == _SourceMode.youtube,
            onTap: () => setState(() => _sourceMode = _SourceMode.youtube),
            accentColor: _C.ytRed,
          ),
        ],
      ),
    );
  }

  // Local Source Card
  Widget _buildLocalSourceCard() {
    return _Card(
      label: 'VIDEO SOURCE',
      child: _FileRow(
        icon: Icons.movie_rounded,
        label: 'Video File',
        value: _videoPath,
        placeholder: 'Select a video file…',
        accent: _C.accent,
        onTap: _pickVideoFile,
      ),
    );
  }

  // YouTube Card
  Widget _buildYouTubeCard() {
    return _Card(
      label: 'YOUTUBE SOURCE',
      child: Column(
        children: [
          // URL input
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
                  onTap: _ytInfoLoading ? null : _fetchYtInfo,
                  color: _C.accent,
                ),
              ],
            ),
          ),

          // Video info (after fetch)
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
                      color: _C.green.withValues(alpha: 0.12),
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
                ],
              ),
            ),
            Divider(color: _C.border, height: 1),

            // Quality picker
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
                    children: YouTubeQuality.values.map((q) {
                      return _Chip(
                        label: q.label,
                        selected: _ytQuality == q,
                        onTap: () => setState(() => _ytQuality = q),
                        color: q == YouTubeQuality.audioOnly
                            ? _C.purple
                            : _C.accent,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Output Card
  Widget _buildOutputCard() {
    return _Card(
      label: 'OUTPUT',
      child: _FileRow(
        icon: Icons.folder_rounded,
        label: 'Output Folder',
        value: _outputDirectory,
        placeholder: 'Select output directory…',
        accent: _C.purple,
        onTap: _pickOutputDirectory,
      ),
    );
  }

  // Settings Card
  Widget _buildSettingsCard() {
    return _Card(
      label: 'EXTRACTION SETTINGS',
      child: Column(
        children: [
          // Time range
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: _TimeField(
                    controller: _startTimeCtrl,
                    label: 'Start',
                    icon: Icons.play_circle_outline_rounded,
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
            onChanged: (v) => setState(() => _quality = v.toInt()),
          ),
          Divider(color: _C.border, height: 1),
          // Format chips
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
                        onTap: () => setState(() => _format = fmt),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Advanced Card
  Widget _buildAdvancedCard() {
    return _Card(
      label: 'ADVANCED',
      child: Column(
        children: [
          // Scale slider
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
          // Frame prefix
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
                  onChanged: (v) => _framePrefix = v,
                  hint: 'frame_',
                ),
              ],
            ),
          ),
          Divider(color: _C.border, height: 1),
          // Open folder on done toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Open folder when done',
                    style: TextStyle(
                      color: _C.textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
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

  Widget _buildAdvancedToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showAdvanced = !_showAdvanced),
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
              style: TextStyle(
                color: _C.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Progress Card
  Widget _buildProgressCard() {
    return BlocBuilder<ExtractionBloc, ExtractionState>(
      builder: (context, state) {
        if (state is! ExtractionInProgress) return const SizedBox.shrink();
        final p = state.progress;
        final isDownloading = state.phase == 'downloading';

        return _Card(
          label: isDownloading ? 'DOWNLOADING' : 'PROGRESS',
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
                            color: isDownloading ? _C.ytRed : _C.accent,
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
                    Text(
                      '${p.percentage}%',
                      style: TextStyle(
                        color: isDownloading ? _C.ytRed : _C.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: p.percentage / 100,
                    minHeight: 4,
                    backgroundColor: _C.surfaceHi,
                    valueColor: AlwaysStoppedAnimation(
                      isDownloading ? _C.ytRed : _C.accent,
                    ),
                  ),
                ),
                if (p.estimatedFrames > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${p.framesProcessed} / ${p.estimatedFrames} frames',
                        style: TextStyle(color: _C.textSec, fontSize: 11),
                      ),
                      const Spacer(),
                      if (p.timeRemaining != null)
                        Text(
                          'ETA ${_fmtDuration(p.timeRemaining!)}',
                          style: TextStyle(color: _C.textMuted, fontSize: 11),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Action Buttons
  Widget _buildActionButtons() {
    return BlocBuilder<ExtractionBloc, ExtractionState>(
      builder: (context, state) {
        final isExtracting = state is ExtractionInProgress;

        return Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: isExtracting ? 'Working…' : 'Extract Frames',
                icon: isExtracting
                    ? Icons.hourglass_top_rounded
                    : Icons.play_arrow_rounded,
                color: _C.accent,
                onPressed: isExtracting ? null : _startExtraction,
              ),
            ),
            if (isExtracting) ...[
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
      },
    );
  }

  // Log Panel
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

  // State handler
  void _onStateChange(BuildContext context, ExtractionState state) {
    if (state is ExtractionSuccess) {
      _toast(state.message, _C.green);
      if (_openFolderOnDone && state.outputDirectory.isNotEmpty) {
        _openFolder(state.outputDirectory);
      }
    } else if (state is ExtractionFailure) {
      _toast(state.error, _C.red);
    } else if (state is ExtractionCancelled) {
      _toast('Extraction cancelled', _C.orange);
    }
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Actions
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
      _toast('Could not fetch video info. Check yt-dlp.', _C.red);
    }
  }

  void _startExtraction() {
    if (_outputDirectory == null) {
      _toast('Select an output directory first.', _C.orange);
      return;
    }

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
      final url = _ytUrlCtrl.text.trim();
      if (url.isEmpty) {
        _toast('Enter a YouTube URL.', _C.orange);
        return;
      }
      context.read<ExtractionBloc>().add(
        StartYouTubeExtraction(
          url: url,
          quality: _ytQuality,
          params: baseParams,
        ),
      );
    } else {
      if (_videoPath == null) {
        _toast('Select a video file first.', _C.orange);
        return;
      }
      context.read<ExtractionBloc>().add(StartExtraction(baseParams));
    }
  }

  void _cancelExtraction() {
    context.read<ExtractionBloc>().add(CancelExtraction());
  }

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

// Widgets
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
          style: TextStyle(
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

class _TitleBarBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color hoverColor;
  const _TitleBarBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.hoverColor = _C.surfaceHi,
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

class _SourceTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color accentColor;
  const _SourceTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.accentColor = _C.accent,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected
            ? accentColor.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: selected ? accentColor.withValues(alpha: 0.5) : _C.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: selected ? accentColor : _C.textMuted, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? accentColor : _C.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final Color accent;
  final VoidCallback onTap;
  const _FileRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final name = hasValue
        ? value!.split('/').last.split('\\').last
        : placeholder;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: accent, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
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
                      fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
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
              color: hasValue ? accent : _C.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label, display;
  final double value, min, max;
  final int divisions;
  final Color color;
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
  });

  @override
  Widget build(BuildContext context) => Padding(
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
                    color: color,
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
              activeTrackColor: color,
              inactiveTrackColor: _C.surfaceHi,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.15),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = _C.accent,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? color : _C.surfaceHi,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: selected ? color : _C.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : _C.textSec,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _TimeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  const _TimeField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: const TextStyle(
      color: _C.textPri,
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
      prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      filled: true,
      fillColor: _C.surfaceHi,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
  );
}

class _CompactField extends StatelessWidget {
  final String initialValue, hint;
  final ValueChanged<String> onChanged;
  const _CompactField({
    required this.initialValue,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
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
  );
}

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
  Widget build(BuildContext context) => GestureDetector(
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
  );
}

class _ActionBtn extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final off = onPressed == null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 20 : 0,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: off ? _C.surfaceHi : color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: off ? _C.border : color.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: off ? _C.textMuted : color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: off ? _C.textMuted : color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Log Panel
class _LogPanel extends StatelessWidget {
  final List<String> logs;
  const _LogPanel({required this.logs});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (_, ctrl) => Column(
        children: [
          // Handle
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
          // Header
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
                Text(
                  '${logs.length} lines',
                  style: TextStyle(color: _C.textSec, fontSize: 11),
                ),
              ],
            ),
          ),
          Divider(color: _C.border, height: 1),
          // Log lines
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
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          line,
                          style: TextStyle(
                            color: isErr ? _C.red : _C.textSec,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            height: 1.5,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Copy button
          Padding(
            padding: const EdgeInsets.all(16),
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
        ],
      ),
    );
  }
}
