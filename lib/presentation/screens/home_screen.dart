import 'dart:io';
import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:frameextractor/core/app_constants.dart';
import 'package:frameextractor/core/app_prefs.dart';
import 'package:frameextractor/data/models/extraction_params.dart';
import 'package:frameextractor/data/models/extraction_present.dart';
import 'package:frameextractor/data/models/video_metadata.dart';
import 'package:frameextractor/data/services/update_service.dart';
import 'package:frameextractor/data/services/youtube_service.dart';
import 'package:frameextractor/presentation/bloc/extraction_bloc.dart';
import 'package:frameextractor/presentation/bloc/extraction_event.dart';
import 'package:frameextractor/presentation/bloc/extraction_state.dart';
import 'package:frameextractor/presentation/screens/history_screen.dart';
import 'package:frameextractor/presentation/screens/sections/advanced_section.dart';
import 'package:frameextractor/presentation/screens/sections/output_section.dart';
import 'package:frameextractor/presentation/screens/sections/progress_section.dart';
import 'package:frameextractor/presentation/screens/sections/settings_section.dart';
import 'package:frameextractor/presentation/screens/sections/source_section.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

bool get _isDesktop => !Platform.isAndroid && !Platform.isIOS;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  final _ytUrlCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController(text: AppConstants.defaultStart);
  final _endTimeCtrl = TextEditingController(text: AppConstants.defaultEnd);
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Source state
  SourceMode _sourceMode = SourceMode.local;
  String? _videoPath;
  VideoMetadata? _videoMetadata;
  bool _metadataLoading = false;

  // Output state
  String? _outputDirectory;

  // Settings state
  int _fps = AppConstants.defaultFps;
  String _format = AppConstants.defaultFormat;
  int _quality = AppConstants.defaultQuality;
  double _scale = AppConstants.defaultScale;
  String _framePrefix = AppConstants.defaultPrefix;
  bool _openFolderOnDone = true;
  bool _showAdvanced = false;

  // YouTube state
  YouTubeQuality _ytQuality = YouTubeQuality.p1080;
  bool _ytInfoLoading = false;
  YouTubeVideoInfo? _ytInfo;

  // Misc
  List<String> _recentVideos = [];
  UpdateResult? _updateResult;
  String? _startTimeError;
  String? _endTimeError;

  // Cached estimates
  ExtractionParams? _cachedParams;
  int _cachedEstimatedFrames = 0;
  String _cachedEstimatedSize = '';

  // Derived flags
  bool get _isExtracting =>
      context.read<ExtractionBloc>().state is ExtractionInProgress;

  bool get _settingsEnabled {
    if (_isExtracting) return false;
    if (_outputDirectory == null) return false;
    if (_sourceMode == SourceMode.local) return _videoPath != null;
    return _ytInfo != null;
  }

  bool get _canExtract {
    if (_outputDirectory == null) return false;
    if (_startTimeError != null || _endTimeError != null) return false;
    if (_sourceMode == SourceMode.local) return _videoPath != null;
    return _ytInfo != null && _ytUrlCtrl.text.trim().isNotEmpty;
  }

  String get _settingsHint {
    if (_sourceMode == SourceMode.local && _videoPath == null) {
      return 'Select a video file first';
    }
    if (_outputDirectory == null) {
      return 'Select an output folder first';
    }
    if (_sourceMode == SourceMode.youtube && _ytInfo == null) {
      return 'Fetch a YouTube video first';
    }
    return '';
  }

  // Lifecycle
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

    _loadPrefs();
    _updateResult = UpdateService.cachedResult;
    UpdateService.resultNotifier.addListener(_onUpdateResult);
    _startTimeCtrl.addListener(_onTimeChanged);
    _endTimeCtrl.addListener(_onTimeChanged);
  }

  @override
  void dispose() {
    UpdateService.resultNotifier.removeListener(_onUpdateResult);
    _pulseCtrl.dispose();
    _ytUrlCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
  }

  // Prefs / init
  Future<void> _loadPrefs() async {
    final lastOut = AppPrefs.lastOutputDir;
    final recents = await _filterExistingRecents(AppPrefs.recentVideos);
    if (!mounted) return;
    setState(() {
      if (lastOut != null) _outputDirectory = lastOut;
      _recentVideos = recents;
      _fps = AppPrefs.lastFps;
      _format = AppPrefs.lastFormat;
      _quality = AppPrefs.lastQuality;
      _scale = AppPrefs.lastScale;
      _framePrefix = AppPrefs.lastPrefix;
      _openFolderOnDone = AppPrefs.openFolderOnDone;
      _startTimeCtrl.text = AppPrefs.lastStartTime;
      _endTimeCtrl.text = AppPrefs.lastEndTime;
    });
    _refreshEstimates();
  }

  Future<List<String>> _filterExistingRecents(List<String> paths) async {
    final result = <String>[];
    for (final p in paths) {
      if (await File(p).exists()) result.add(p);
    }
    return result;
  }

  // Video selection & metadata
  Future<void> _onVideoSelected(String path) async {
    if (path.isEmpty) {
      setState(() {
        _videoPath = null;
        _videoMetadata = null;
        _recentVideos = AppPrefs.recentVideos;
      });
      return;
    }
    setState(() {
      _videoPath = path;
      _videoMetadata = null;
      _metadataLoading = true;
    });
    _refreshEstimates();

    final bloc = context.read<ExtractionBloc>();
    final meta = await bloc.ffmpegService.getVideoMetadata(path);
    if (!mounted) return;
    setState(() {
      _videoMetadata = meta;
      _metadataLoading = false;
    });
  }

  // YouTube fetch
  Future<void> _fetchYtInfo() async {
    final url = _ytUrlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _ytInfoLoading = true;
      _ytInfo = null;
    });
    final svc = context.read<ExtractionBloc>().youTubeService;
    final c = AppTheme.of(context).colors;
    final info = await svc.getVideoInfo(url);
    if (!mounted) return;
    setState(() {
      _ytInfo = info;
      _ytInfoLoading = false;
    });
    if (info == null) {
      _toast(
        'Could not fetch video info. Check the URL or yt-dlp.',
        c.red,
        c.redDim,
        Icons.error_rounded,
      );
    }
  }

  // Drag & drop
  void _onDropDone(DropDoneDetails details) {
    if (details.files.isEmpty) return;
    final file = details.files.first;
    final ext = file.path.split('.').last.toLowerCase();
    if (!AppConstants.supportedVideoExtensions.contains(ext)) {
      final c = AppTheme.of(context).colors;
      _toast(
        'Unsupported file type: .$ext',
        c.red,
        c.redDim,
        Icons.error_rounded,
      );
      return;
    }
    AppPrefs.addRecentVideo(file.path);
    _onVideoSelected(file.path);
  }

  // Time validation
  void _onTimeChanged() {
    _validateTimeRange();
    _refreshEstimates();
  }

  void _validateTimeRange() {
    final start = _startTimeCtrl.text;
    final end = _endTimeCtrl.text;
    final timePattern = RegExp(r'^\d{2}:\d{2}:\d{2}(\.\d+)?$');

    String? startErr, endErr;

    if (start.isNotEmpty && !timePattern.hasMatch(start)) {
      startErr = 'Use HH:MM:SS';
    }
    if (end.isNotEmpty && !timePattern.hasMatch(end)) endErr = 'Use HH:MM:SS';

    if (startErr == null &&
        endErr == null &&
        start.isNotEmpty &&
        end.isNotEmpty) {
      final s = parseTimeString(start);
      final e = parseTimeString(end);
      if (s != null && e != null && s >= e) {
        startErr = 'Start must be before end';
      }
    }

    if (startErr != _startTimeError || endErr != _endTimeError) {
      setState(() {
        _startTimeError = startErr;
        _endTimeError = endErr;
      });
    }
  }

  void _refreshEstimates() {
    try {
      _cachedParams = ExtractionParams(
        videoPath: _videoPath ?? '',
        outputDirectory: _outputDirectory ?? '',
        startTime: _startTimeCtrl.text,
        endTime: _endTimeCtrl.text,
        fps: _fps,
        format: _format,
        imageQuality: _quality,
        resolutionScale: _scale,
        frameNamePrefix: _framePrefix,
      );
      _cachedEstimatedFrames = _cachedParams!.estimatedFrameCount;
      _cachedEstimatedSize = _cachedParams!.estimatedSizeFormatted;
    } catch (_) {
      _cachedParams = null;
      _cachedEstimatedFrames = 0;
      _cachedEstimatedSize = '';
    }
  }

  // ── Extraction ────────────────────────────────────────────────────────────────

  void _startExtraction() {
    final params = ExtractionParams(
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
    final errors = params.validate();
    if (errors.isNotEmpty) {
      final c = AppTheme.of(context).colors;
      _toast(errors.first, c.red, c.redDim, Icons.error_rounded);
      return;
    }
    if (_sourceMode == SourceMode.youtube) {
      context.read<ExtractionBloc>().add(
        StartYouTubeExtraction(
          url: _ytUrlCtrl.text.trim(),
          quality: _ytQuality,
          params: params,
        ),
      );
    } else {
      context.read<ExtractionBloc>().add(StartExtraction(params));
    }
  }

  void _cancelExtraction() =>
      context.read<ExtractionBloc>().add(const CancelExtraction());

  // ── Preset apply ──────────────────────────────────────────────────────────────

  void _applyPreset(ExtractionPreset preset) {
    setState(() {
      _fps = preset.fps;
      _format = preset.format;
      _quality = preset.imageQuality;
      _scale = preset.resolutionScale;
      _framePrefix = preset.frameNamePrefix;
      _startTimeCtrl.text = preset.startTime;
      _endTimeCtrl.text = preset.endTime;
    });
    _validateTimeRange();
    _refreshEstimates();
    Navigator.of(context).pop();
    final c = AppTheme.of(context).colors;
    _toast(
      'Preset "${preset.name}" applied',
      c.green,
      c.greenDim,
      Icons.check_circle_rounded,
    );
  }

  // State change listener
  void _onStateChange(BuildContext context, ExtractionState state) {
    if (state is ExtractionInProgress && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (state is! ExtractionInProgress && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }
    final c = AppTheme.of(context).colors;
    if (state is ExtractionSuccess) {
      _toast(state.message, c.green, c.greenDim, Icons.check_circle_rounded);
      if (_openFolderOnDone && state.outputDirectory.isNotEmpty) {
        _openFolder(state.outputDirectory);
      }
    } else if (state is ExtractionFailure) {
      _toast(state.error, c.red, c.redDim, Icons.error_rounded);
    } else if (state is ExtractionCancelled) {
      _toast(
        'Extraction cancelled',
        c.orange,
        c.orange.withValues(alpha: 0.15),
        Icons.cancel_rounded,
      );
    }
  }

  void _onUpdateResult() {
    if (!mounted) return;
    setState(() => _updateResult = UpdateService.resultNotifier.value);
  }

  // ── Keyboard ──────────────────────────────────────────────────────────────────

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space && !_isExtracting && _canExtract) {
      _startExtraction();
      return;
    }
    if (key == LogicalKeyboardKey.escape && _isExtracting) {
      _cancelExtraction();
      return;
    }
    if (key == LogicalKeyboardKey.keyL &&
        HardwareKeyboard.instance.isControlPressed) {
      _showLogPanel();
      return;
    }
    if (key == LogicalKeyboardKey.keyS &&
        HardwareKeyboard.instance.isControlPressed) {
      _showSettings();
      return;
    }
    if (key == LogicalKeyboardKey.keyP &&
        HardwareKeyboard.instance.isControlPressed) {
      _showPresetsPanel();
      return;
    }
    if (key == LogicalKeyboardKey.keyH &&
        HardwareKeyboard.instance.isControlPressed) {
      _showHistory();
      return;
    }
  }

  // ── Dialogs / panels (delegated to reusable helpers) ─────────────────────────

  void _showSettings() {
    final theme = AppTheme.of(context);
    if (_isDesktop) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(
          alpha: theme.isDark ? 0.55 : 0.30,
        ),
        builder: (dialogCtx) => _ThemedDialogWrapper(
          parentContext: context,
          builder: (liveTheme) => _GlassDialog(
            theme: liveTheme,
            child: _SettingsContent(parentContext: context),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetCtx) => _ThemedSheetWrapper(
          parentContext: context,
          builder: (liveTheme) => _SettingsContent(parentContext: context),
        ),
      );
    }
  }

  void _showLogPanel() {
    final bloc = context.read<ExtractionBloc>();
    final theme = AppTheme.of(context);
    if (_isDesktop) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(
          alpha: theme.isDark ? 0.55 : 0.30,
        ),
        builder: (dialogCtx) => _ThemedDialogWrapper(
          parentContext: context,
          builder: (liveTheme) => _GlassDialog(
            theme: liveTheme,
            maxWidth: 620,
            child: _LogContent(logs: bloc.logs, parentContext: context),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _ThemedSheetWrapper(
          parentContext: context,
          builder: (liveTheme) =>
              _LogContent(logs: bloc.logs, parentContext: context),
        ),
      );
    }
  }

  void _showPresetsPanel() {
    final theme = AppTheme.of(context);
    if (_isDesktop) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(
          alpha: theme.isDark ? 0.55 : 0.30,
        ),
        builder: (dialogCtx) => _ThemedDialogWrapper(
          parentContext: context,
          builder: (liveTheme) => _GlassDialog(
            theme: liveTheme,
            maxWidth: 500,
            child: _PresetsContent(
              parentContext: context,
              currentParams: _cachedParams,
              onApply: _applyPreset,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _ThemedSheetWrapper(
          parentContext: context,
          builder: (liveTheme) => _PresetsContent(
            parentContext: context,
            currentParams: _cachedParams,
            onApply: _applyPreset,
          ),
        ),
      );
    }
  }

  void _showHistory() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
  }

  // ── Utilities ─────────────────────────────────────────────────────────────────

  void _openFolder(String path) {
    if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else {
      Process.run('xdg-open', [path]);
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

  Future<void> _handleClose() async {
    if (_isExtracting) {
      final confirmed = await _showCloseConfirmDialog();
      if (!confirmed || !mounted) return;
    }
    await windowManager.close();
  }

  Future<bool> _showCloseConfirmDialog() async {
    final theme = AppTheme.of(context);
    final c = theme.colors;
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: theme.isDark ? 0.55 : 0.30),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(24),
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
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.warning_rounded, color: c.red, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Extraction in Progress',
                      style: TextStyle(
                        color: c.textPri,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Closing now will cancel the current extraction. Are you sure?',
                style: TextStyle(color: c.textSec, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: c.surfaceHi,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.border),
                          ),
                          child: Center(
                            child: Text(
                              'Keep Running',
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
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: c.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: c.red.withValues(alpha: 0.50),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Close Anyway',
                              style: TextStyle(
                                color: c.red,
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
    return result ?? false;
  }

  // ── Build ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final c = theme.colors;
    final isGlass = theme.isGlass;

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: _handleKey,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: theme.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: isGlass ? Colors.transparent : c.bg,
          body: Stack(
            children: [
              if (isGlass) _GlassBg(isDark: theme.isDark),
              BlocListener<ExtractionBloc, ExtractionState>(
                listener: _onStateChange,
                child: Column(
                  children: [
                    _buildTitleBar(theme),
                    Expanded(
                      child: DropTarget(
                        onDragDone: _onDropDone,
                        child: BlocBuilder<ExtractionBloc, ExtractionState>(
                          builder: (ctx, state) {
                            final extracting = state is ExtractionInProgress;
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                28,
                              ),
                              child: Column(
                                children: [
                                  SourceSection(
                                    mode: _sourceMode,
                                    videoPath: _videoPath,
                                    videoMetadata: _videoMetadata,
                                    metadataLoading: _metadataLoading,
                                    ytInfo: _ytInfo,
                                    ytInfoLoading: _ytInfoLoading,
                                    ytQuality: _ytQuality,
                                    disabled: extracting,
                                    recentVideos: _recentVideos,
                                    ffmpegService: context
                                        .read<ExtractionBloc>()
                                        .ffmpegService,
                                    ytUrlCtrl: _ytUrlCtrl,
                                    onModeChanged: (m) => setState(() {
                                      _sourceMode = m;
                                      if (m == SourceMode.local) _ytInfo = null;
                                    }),
                                    onVideoSelected: _onVideoSelected,
                                    onVideoClear: () => setState(() {
                                      _videoPath = null;
                                      _videoMetadata = null;
                                    }),
                                    onYtInfoChanged: (info) {
                                      if (info == null && _ytInfo == null) {
                                        _fetchYtInfo();
                                      } else {
                                        setState(() => _ytInfo = info);
                                      }
                                    },
                                    onYtQualityChanged: (q) =>
                                        setState(() => _ytQuality = q),
                                  ),
                                  const SizedBox(height: 10),
                                  OutputSection(
                                    outputDirectory: _outputDirectory,
                                    disabled: extracting,
                                    onDirectorySelected: (d) => setState(() {
                                      _outputDirectory = d;
                                      _refreshEstimates();
                                    }),
                                    onClear: () =>
                                        setState(() => _outputDirectory = null),
                                  ),
                                  const SizedBox(height: 10),
                                  SettingsSection(
                                    fps: _fps,
                                    quality: _quality,
                                    format: _format,
                                    startTimeCtrl: _startTimeCtrl,
                                    endTimeCtrl: _endTimeCtrl,
                                    startTimeError: _startTimeError,
                                    endTimeError: _endTimeError,
                                    disabled: !_settingsEnabled,
                                    disabledHint: _settingsHint,
                                    onFpsChanged: (v) {
                                      setState(() => _fps = v);
                                      _refreshEstimates();
                                    },
                                    onQualityChanged: (v) {
                                      setState(() => _quality = v);
                                      _refreshEstimates();
                                    },
                                    onFormatChanged: (v) {
                                      setState(() => _format = v);
                                      _refreshEstimates();
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  _buildAdvancedToggle(
                                    theme,
                                    disabled: !_settingsEnabled,
                                  ),
                                  if (_showAdvanced && _settingsEnabled) ...[
                                    const SizedBox(height: 10),
                                    AdvancedSection(
                                      scale: _scale,
                                      framePrefix: _framePrefix,
                                      openFolderOnDone: _openFolderOnDone,
                                      currentParams: _cachedParams,
                                      onScaleChanged: (v) {
                                        setState(() => _scale = v);
                                        _refreshEstimates();
                                      },
                                      onPrefixChanged: (v) {
                                        _framePrefix = v;
                                        _refreshEstimates();
                                      },
                                      onOpenFolderChanged: (v) {
                                        setState(() => _openFolderOnDone = v);
                                        AppPrefs.setOpenFolderOnDone(v);
                                      },
                                      onToast: () {
                                        final col = AppTheme.of(context).colors;
                                        _toast(
                                          'Preset saved!',
                                          col.purple,
                                          col.purple.withValues(alpha: 0.12),
                                          Icons.bookmark_added_rounded,
                                        );
                                      },
                                    ),
                                  ],
                                  if (_settingsEnabled &&
                                      _cachedEstimatedFrames > 0) ...[
                                    const SizedBox(height: 6),
                                    _buildEstimateRow(theme),
                                  ],
                                  const SizedBox(height: 10),
                                  if (extracting) ...[
                                    ProgressSection(
                                      state: state,
                                      pulseAnim: _pulseAnim,
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  _buildActionButtons(
                                    theme,
                                    extracting: extracting,
                                  ),
                                  if (!_canExtract && !extracting) ...[
                                    const SizedBox(height: 8),
                                    _buildHint(theme),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Small build helpers ────────────────────────────────────────────────────────

  Widget _buildTitleBar(AppTheme theme) {
    final c = theme.colors;
    final isGlass = theme.isGlass;

    Widget inner = Container(
      padding: EdgeInsets.only(
        top: _isDesktop ? 12 : MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 10,
        bottom: 10,
      ),
      child: Row(
        children: [
          const Image(
            image: AssetImage('assets/icons/icon_32.png'),
            width: 20,
            height: 20,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppConstants.appName,
                  style: TextStyle(
                    color: c.textPri,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  AppConstants.appDescription,
                  style: TextStyle(color: c.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          if (_updateResult?.available == true) ...[
            _UpdateBadge(
              c: c,
              version: _updateResult!.latestVersion,
              releaseUrl: _updateResult!.releaseUrl,
              isGlass: isGlass,
              isDark: theme.isDark,
            ),
            const SizedBox(width: 10),
          ],
          _TitleBarBtn(
            c: c,
            icon: Icons.history_rounded,
            tooltip: 'History (Ctrl+H)',
            onTap: _showHistory,
            isGlass: isGlass,
            isDark: theme.isDark,
          ),
          const SizedBox(width: 4),
          _TitleBarBtn(
            c: c,
            icon: Icons.bookmarks_rounded,
            tooltip: 'Presets (Ctrl+P)',
            onTap: _showPresetsPanel,
            isGlass: isGlass,
            isDark: theme.isDark,
          ),
          const SizedBox(width: 4),
          _TitleBarBtn(
            c: c,
            icon: Icons.terminal_rounded,
            tooltip: 'Logs (Ctrl+L)',
            onTap: _showLogPanel,
            isGlass: isGlass,
            isDark: theme.isDark,
          ),
          const SizedBox(width: 4),
          _TitleBarBtn(
            c: c,
            icon: Icons.tune_rounded,
            tooltip: 'Settings (Ctrl+S)',
            onTap: _showSettings,
            isGlass: isGlass,
            isDark: theme.isDark,
          ),
          if (_isDesktop) ...[
            const SizedBox(width: 4),
            _TitleBarBtn(
              c: c,
              icon: Icons.remove_rounded,
              tooltip: 'Minimize',
              onTap: () => windowManager.minimize(),
              isGlass: isGlass,
              isDark: theme.isDark,
            ),
            const SizedBox(width: 4),
            _TitleBarBtn(
              c: c,
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onTap: _handleClose,
              hoverColor: c.red,
              isGlass: isGlass,
              isDark: theme.isDark,
            ),
          ],
        ],
      ),
    );

    if (isGlass) {
      inner = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassTokens.blurTitBar,
            sigmaY: GlassTokens.blurTitBar,
          ),
          child: Container(
            decoration: GlassTokens.fallbackTitleBar(c, isDark: theme.isDark),
            child: inner,
          ),
        ),
      );
    } else {
      inner = Container(color: c.surface, child: inner);
    }

    return GestureDetector(
      onPanStart: _isDesktop ? (_) => windowManager.startDragging() : null,
      child: inner,
    );
  }

  Widget _buildEstimateRow(AppTheme theme) {
    final c = theme.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_outlined, size: 11, color: c.textMuted),
        const SizedBox(width: 4),
        Text(
          '~$_cachedEstimatedFrames frames',
          style: TextStyle(
            color: c.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.save_outlined, size: 11, color: c.textMuted),
        const SizedBox(width: 4),
        Text(
          '~$_cachedEstimatedSize',
          style: TextStyle(
            color: c.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedToggle(AppTheme theme, {required bool disabled}) {
    final c = theme.colors;
    return Opacity(
      opacity: disabled
          ? GlassTokens.disabledOpacity(isGlass: theme.isGlass)
          : 1.0,
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
                  color: c.textMuted,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _showAdvanced ? 'Hide advanced' : 'Advanced options',
                  style: TextStyle(
                    color: c.textMuted,
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

  Widget _buildActionButtons(AppTheme theme, {required bool extracting}) {
    final c = theme.colors;
    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            c: c,
            label: extracting ? 'Working…' : 'Extract Frames',
            icon: extracting
                ? Icons.hourglass_top_rounded
                : Icons.play_arrow_rounded,
            color: c.accent,
            tooltip: _canExtract && !extracting ? 'Space to start' : null,
            onPressed: (extracting || !_canExtract) ? null : _startExtraction,
            isGlass: theme.isGlass,
            isDark: theme.isDark,
          ),
        ),
        if (extracting) ...[
          const SizedBox(width: 10),
          _ActionBtn(
            c: c,
            label: 'Cancel',
            icon: Icons.stop_rounded,
            color: c.red,
            tooltip: 'Esc to cancel',
            onPressed: _cancelExtraction,
            compact: true,
            isGlass: theme.isGlass,
            isDark: theme.isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildHint(AppTheme theme) {
    final c = theme.colors;
    final String msg;
    if (_sourceMode == SourceMode.local && _videoPath == null) {
      msg = 'Select a video file to continue';
    } else if (_outputDirectory == null) {
      msg = 'Select an output folder to continue';
    } else if (_sourceMode == SourceMode.youtube && _ytInfo == null) {
      msg = 'Fetch a YouTube video to continue';
    } else if (_startTimeError != null || _endTimeError != null) {
      msg = 'Fix the time range errors to continue';
    } else {
      return const SizedBox.shrink();
    }

    final decoration = BoxDecoration(
      color: theme.isGlass ? c.accent.withValues(alpha: 0.12) : c.accentDim,
      borderRadius: BorderRadius.circular(theme.isGlass ? 12 : 10),
      border: Border.all(color: c.accent.withValues(alpha: 0.30)),
    );

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 13,
          color: c.accent.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 6),
        Text(
          msg,
          style: TextStyle(
            color: c.accent.withValues(alpha: 0.9),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    if (theme.isGlass) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: decoration,
            child: content,
          ),
        ),
      );
    } else {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: decoration,
        child: content,
      );
    }
    return content;
  }
}

// ── Reused private widgets (kept in this file — small enough) ─────────────────

class _ThemedDialogWrapper extends StatelessWidget {
  final BuildContext parentContext;
  final Widget Function(AppTheme) builder;
  const _ThemedDialogWrapper({
    required this.parentContext,
    required this.builder,
  });
  @override
  Widget build(BuildContext context) => builder(AppTheme.of(parentContext));
}

class _ThemedSheetWrapper extends StatelessWidget {
  final BuildContext parentContext;
  final Widget Function(AppTheme) builder;
  const _ThemedSheetWrapper({
    required this.parentContext,
    required this.builder,
  });
  @override
  Widget build(BuildContext context) {
    final liveTheme = AppTheme.of(parentContext);
    return _GlassSheet(theme: liveTheme, child: builder(liveTheme));
  }
}

class _GlassBg extends StatelessWidget {
  final bool isDark;
  const _GlassBg({required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF07090D) : const Color(0xFFECEEF6),
      gradient: isDark
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0C12), Color(0xFF080A0F), Color(0xFF0C0E14)],
              stops: [0.0, 0.5, 1.0],
            )
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEDF0FA), Color(0xFFEAECF5), Color(0xFFEFF1FA)],
              stops: [0.0, 0.5, 1.0],
            ),
    ),
  );
}

class _GlassDialog extends StatelessWidget {
  final AppTheme theme;
  final Widget child;
  final double maxWidth;
  const _GlassDialog({
    required this.theme,
    required this.child,
    this.maxWidth = 480,
  });
  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: theme.isGlass
            ? GlassContainer(
                useOwnLayer: true,
                settings: GlassTokens.modalSettings(isDark: theme.isDark),
                shape: LiquidRoundedRectangle(borderRadius: 28),
                child: child,
              )
            : Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: theme.isDark ? 0.55 : 0.18,
                      ),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: child,
              ),
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  final AppTheme theme;
  final Widget child;
  const _GlassSheet({required this.theme, required this.child});
  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
    if (theme.isGlass) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassTokens.blurModal,
            sigmaY: GlassTokens.blurModal,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: theme.isDark ? 0.26 : 0.72),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(
                top: BorderSide(
                  color: theme.isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : c.borderHi.withValues(alpha: 0.70),
                ),
              ),
            ),
            child: child,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: child,
    );
  }
}

class _SettingsContent extends StatelessWidget {
  final BuildContext parentContext;
  const _SettingsContent({required this.parentContext});

  @override
  Widget build(BuildContext context) {
    final liveTheme = AppTheme.of(parentContext);
    return _SettingsBody(theme: liveTheme, parentContext: parentContext);
  }
}

class _SettingsBody extends StatelessWidget {
  final AppTheme theme;
  final BuildContext parentContext;
  const _SettingsBody({required this.theme, required this.parentContext});

  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
    final provider = AppThemeProvider.of(parentContext);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.isGlass
                    ? (theme.isDark
                          ? Colors.white.withValues(alpha: 0.20)
                          : c.borderHi)
                    : c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  color: c.textPri,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_isDesktop)
                _CloseBtn(c: c, isGlass: theme.isGlass, isDark: theme.isDark),
            ],
          ),
          const SizedBox(height: 20),
          _SectionLabel(c: c, label: 'APPEARANCE'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SettingsTile(
                  c: c,
                  icon: Icons.dark_mode_rounded,
                  label: 'Dark',
                  selected: theme.isDark,
                  isGlass: theme.isGlass,
                  isDark: theme.isDark,
                  onTap: () async {
                    provider.setDark(true);
                    await AppPrefs.setThemeMode('dark');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SettingsTile(
                  c: c,
                  icon: Icons.light_mode_rounded,
                  label: 'Light',
                  selected: !theme.isDark,
                  isGlass: theme.isGlass,
                  isDark: theme.isDark,
                  onTap: () async {
                    provider.setDark(false);
                    await AppPrefs.setThemeMode('light');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionLabel(c: c, label: 'UI STYLE'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SettingsTile(
                  c: c,
                  icon: Icons.layers_rounded,
                  label: 'Classic',
                  subtitle: 'Clean & sharp',
                  selected: theme.style == UIStyle.classic,
                  isGlass: theme.isGlass,
                  isDark: theme.isDark,
                  onTap: () async {
                    provider.setStyle(UIStyle.classic);
                    await AppPrefs.setUIStyle('classic');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SettingsTile(
                  c: c,
                  icon: Icons.blur_on_rounded,
                  label: 'Liquid Glass',
                  subtitle: 'Experimental',
                  selected: theme.style == UIStyle.glass,
                  isGlass: theme.isGlass,
                  isDark: theme.isDark,
                  onTap: () async {
                    if (theme.style != UIStyle.glass) {
                      _showExperimentalWarning(
                        context,
                        parentContext: parentContext,
                        onConfirm: () async {
                          provider.setStyle(UIStyle.glass);
                          await AppPrefs.setUIStyle('glass');
                        },
                        theme: theme,
                      );
                    } else {
                      provider.setStyle(UIStyle.classic);
                      await AppPrefs.setUIStyle('classic');
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SectionLabel(c: c, label: 'KEYBOARD SHORTCUTS'),
                    const SizedBox(height: 10),
                    _ShortcutRow(
                      c: c,
                      key_: 'Space',
                      label: 'Start extraction',
                    ),
                    _ShortcutRow(c: c, key_: 'Esc', label: 'Cancel extraction'),
                    _ShortcutRow(c: c, key_: 'Ctrl+L', label: 'Open log panel'),
                    _ShortcutRow(
                      c: c,
                      key_: 'Ctrl+S',
                      label: 'Open settings panel',
                    ),
                    _ShortcutRow(
                      c: c,
                      key_: 'Ctrl+P',
                      label: 'Open presets panel',
                    ),
                  ],
                ),
              ),
              Text(
                "${AppConstants.appName} ${AppConstants.appVersion}",
                style: TextStyle(color: c.textSec, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExperimentalWarning(
    BuildContext context, {
    required BuildContext parentContext,
    required VoidCallback onConfirm,
    required AppTheme theme,
  }) {
    final c = theme.colors;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: theme.isDark ? 0.60 : 0.35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(24),
          decoration: theme.isGlass
              ? BoxDecoration(
                  color: c.surface.withValues(
                    alpha: theme.isDark ? 0.30 : 0.82,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.isDark
                        ? Colors.white.withValues(alpha: 0.20)
                        : c.borderHi.withValues(alpha: 0.80),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: theme.isDark ? 0.50 : 0.15,
                      ),
                      blurRadius: 48,
                      offset: const Offset(0, 16),
                    ),
                  ],
                )
              : BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: theme.isDark ? 0.50 : 0.15,
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
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: c.orange,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Experimental Feature',
                      style: TextStyle(
                        color: c.textPri,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Liquid Glass style is still in early development, and not all platform may support this features.',
                style: TextStyle(color: c.textSec, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 8),
              _WarningBullet(
                c: c,
                text: 'May cause performance issues on low-end devices',
              ),
              _WarningBullet(
                c: c,
                text: 'Memory spikes possible when animating shapes',
              ),
              _WarningBullet(
                c: c,
                text: 'Using experimental features at your own risk!',
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: c.surfaceHi,
                            borderRadius: BorderRadius.circular(10),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          onConfirm();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: c.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: c.orange.withValues(alpha: 0.50),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Enable Anyway',
                              style: TextStyle(
                                color: c.orange,
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
}

// SettingsTile
class _SettingsTile extends StatelessWidget {
  final AppColors c;
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected, isGlass, isDark;
  final VoidCallback onTap;
  const _SettingsTile({
    required this.c,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isGlass,
    required this.isDark,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (!isGlass) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? c.accentDim : c.surfaceHi,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? c.accent.withValues(alpha: 0.50) : c.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: selected ? c.accent : c.textMuted, size: 18),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? c.accent : c.textSec,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(color: c.textMuted, fontSize: 10),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Glass settings tile
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? c.accent.withValues(alpha: 0.18)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : c.surface.withValues(alpha: 0.65)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? c.accent.withValues(alpha: 0.55)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : c.borderHi.withValues(alpha: 0.70)),
              width: selected ? 1.5 : 1.0,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.18),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected
                    ? c.accent
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.45)
                          : c.textSec),
                size: 18,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? c.accent
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.75)
                            : c.textSec),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.30)
                        : c.textMuted,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Preset Content
class _PresetsContent extends StatelessWidget {
  final BuildContext parentContext;
  final ExtractionParams? currentParams;
  final void Function(ExtractionPreset) onApply;

  const _PresetsContent({
    required this.parentContext,
    required this.currentParams,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final liveTheme = AppTheme.of(parentContext);
    return _PresetsBody(
      theme: liveTheme,
      currentParams: currentParams,
      onApply: onApply,
      parentContext: parentContext,
    );
  }
}

class _PresetsBody extends StatefulWidget {
  final AppTheme theme;
  final ExtractionParams? currentParams;
  final void Function(ExtractionPreset) onApply;
  final BuildContext parentContext;

  const _PresetsBody({
    required this.theme,
    required this.currentParams,
    required this.onApply,
    required this.parentContext,
  });

  @override
  State<_PresetsBody> createState() => _PresetsBodyState();
}

class _PresetsBodyState extends State<_PresetsBody> {
  late List<ExtractionPreset> _presets;

  @override
  void initState() {
    super.initState();
    _presets = AppPrefs.allPresets;
  }

  Future<void> _deletePreset(ExtractionPreset preset) async {
    await AppPrefs.deletePreset(preset.id);
    setState(() => _presets = AppPrefs.allPresets);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.theme.colors;
    final isGlass = widget.theme.isGlass;

    return SizedBox(
      height: 520,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Icon(Icons.bookmarks_rounded, color: c.purple, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Presets',
                  style: TextStyle(
                    color: c.textPri,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isGlass
                        ? (widget.theme.isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : c.surfaceHi)
                        : c.surfaceHi,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_presets.length} presets',
                    style: TextStyle(
                      color: c.textSec,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _CloseBtn(c: c, isGlass: isGlass, isDark: widget.theme.isDark),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: isGlass
                ? (widget.theme.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : c.border)
                : c.border,
          ),
          Expanded(
            child: _presets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bookmark_border_rounded,
                          color: c.textMuted,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No presets yet.',
                          style: TextStyle(color: c.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Open Advanced settings to save one.',
                          style: TextStyle(color: c.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _presets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final preset = _presets[i];
                      return _PresetTile(
                        preset: preset,
                        theme: widget.theme,
                        onApply: () => widget.onApply(preset),
                        onDelete: preset.isDefault
                            ? null
                            : () => _deletePreset(preset),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final ExtractionPreset preset;
  final AppTheme theme;
  final VoidCallback onApply;
  final VoidCallback? onDelete;

  const _PresetTile({
    required this.preset,
    required this.theme,
    required this.onApply,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
    final isGlass = theme.isGlass;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isGlass
            ? (theme.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : c.surface.withValues(alpha: 0.65))
            : c.surfaceHi,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGlass
              ? (theme.isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : c.borderHi.withValues(alpha: 0.60))
              : c.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.purple.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              preset.isDefault
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_added_rounded,
              color: c.purple,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  style: TextStyle(
                    color: c.textPri,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${preset.fps}fps · ${preset.format.toUpperCase()} · '
                  '${preset.imageQuality}% · ${(preset.resolutionScale * 100).toInt()}%',
                  style: TextStyle(color: c.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onDelete != null)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isGlass ? c.red.withValues(alpha: 0.10) : c.redDim,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: c.red.withValues(alpha: 0.30)),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: c.red,
                    size: 14,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 6),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onApply,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isGlass
                      ? c.purple.withValues(alpha: 0.18)
                      : c.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.purple.withValues(alpha: 0.45)),
                ),
                child: Text(
                  'Apply',
                  style: TextStyle(
                    color: c.purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

// Log Content
class _LogContent extends StatelessWidget {
  final List<String> logs;
  final BuildContext parentContext;
  const _LogContent({required this.logs, required this.parentContext});

  @override
  Widget build(BuildContext context) {
    final liveTheme = AppTheme.of(parentContext);
    return _LogBody(logs: logs, theme: liveTheme);
  }
}

class _LogBody extends StatelessWidget {
  final List<String> logs;
  final AppTheme theme;
  const _LogBody({required this.logs, required this.theme});

  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
    return SizedBox(
      height: _isDesktop ? 480 : null,
      child: DraggableScrollableSheet(
        expand: _isDesktop ? true : false,
        initialChildSize: _isDesktop ? 1.0 : 0.55,
        maxChildSize: 1.0,
        minChildSize: _isDesktop ? 1.0 : 0.3,
        builder: (_, ctrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.isGlass
                      ? (theme.isDark
                            ? Colors.white.withValues(alpha: 0.20)
                            : c.borderHi)
                      : c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.terminal_rounded, color: c.accent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Process Log',
                    style: TextStyle(
                      color: c.textPri,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.isGlass
                          ? (theme.isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : c.surfaceHi)
                          : c.surfaceHi,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${logs.length} lines',
                      style: TextStyle(
                        color: c.textSec,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_isDesktop) ...[
                    const SizedBox(width: 8),
                    _CloseBtn(
                      c: c,
                      isGlass: theme.isGlass,
                      isDark: theme.isDark,
                    ),
                  ],
                ],
              ),
            ),
            Container(
              height: 1,
              color: theme.isGlass
                  ? (theme.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : c.border)
                  : c.border,
            ),
            Expanded(
              child: logs.isEmpty
                  ? Center(
                      child: Text(
                        'No logs yet.',
                        style: TextStyle(color: c.textMuted, fontSize: 13),
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
                            ? c.red
                            : isWarn
                            ? c.orange
                            : isInfo
                            ? c.accent
                            : c.textSec;
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
                      color: theme.isGlass
                          ? (theme.isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : c.surfaceHi)
                          : c.surfaceHi,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.isGlass
                            ? (theme.isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : c.borderHi)
                            : c.border,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.copy_rounded, color: c.textSec, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Copy all logs',
                          style: TextStyle(
                            color: c.textSec,
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
      ),
    );
  }
}

// Title Bar Button
class _TitleBarBtn extends StatefulWidget {
  final AppColors c;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? hoverColor;
  final bool isGlass, isDark;
  const _TitleBarBtn({
    required this.c,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isGlass,
    required this.isDark,
    this.hoverColor,
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
            color: _hov
                ? (widget.hoverColor ??
                      (widget.isGlass
                          ? Colors.white.withValues(
                              alpha: widget.isDark ? 0.18 : 0.40,
                            )
                          : widget.c.borderHi))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            widget.icon,
            color: _hov ? Colors.white : widget.c.textSec,
            size: 16,
          ),
        ),
      ),
    ),
  );
}

// Close button
class _CloseBtn extends StatelessWidget {
  final AppColors c;
  final bool isGlass, isDark;
  const _CloseBtn({
    required this.c,
    required this.isGlass,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isGlass
              ? (isDark ? Colors.white.withValues(alpha: 0.08) : c.surfaceHi)
              : c.surfaceHi,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isGlass
                ? (isDark ? Colors.white.withValues(alpha: 0.15) : c.borderHi)
                : c.border,
          ),
        ),
        child: Icon(Icons.close_rounded, size: 14, color: c.textSec),
      ),
    ),
  );
}

// Action Button
class _ActionBtn extends StatefulWidget {
  final AppColors c;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool compact, isGlass, isDark;
  final String? tooltip;
  const _ActionBtn({
    required this.c,
    required this.label,
    required this.icon,
    required this.color,
    required this.isGlass,
    required this.isDark,
    this.onPressed,
    this.compact = false,
    this.tooltip,
  });
  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final off = widget.onPressed == null;
    final col = off ? widget.c.textMuted : widget.color;

    Widget btn = MouseRegion(
      cursor: off ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: widget.isGlass
            ? GlassContainer(
                useOwnLayer: true,
                settings: LiquidGlassSettings(
                  thickness: off ? 0.28 : (_hov ? 0.72 : 0.55),
                  blur: off ? 4 : 8,
                  glassColor: off
                      ? Colors.white.withValues(alpha: 0.05)
                      : col.withValues(alpha: _hov ? 0.25 : 0.18),
                ),
                shape: LiquidRoundedRectangle(borderRadius: 16),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 20 : 0,
                    vertical: 14,
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
              )
            : AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 20 : 0,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: off
                      ? widget.c.surfaceHi
                      : _hov
                      ? widget.color.withValues(alpha: 0.22)
                      : widget.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: off
                        ? widget.c.border
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

    if (widget.tooltip != null && !off) {
      btn = Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}

// Warning bullet
class _WarningBullet extends StatelessWidget {
  final AppColors c;
  final String text;
  const _WarningBullet({required this.c, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: c.orange.withValues(alpha: 0.70),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: c.textSec, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

// ShortcutRow
class _ShortcutRow extends StatelessWidget {
  final AppColors c;
  final String key_, label;
  const _ShortcutRow({
    required this.c,
    required this.key_,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: c.surfaceHi,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.border),
          ),
          child: Text(
            key_,
            style: TextStyle(
              color: c.textSec,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: c.textSec, fontSize: 12)),
      ],
    ),
  );
}

// Section Label
class _SectionLabel extends StatelessWidget {
  final AppColors c;
  final String label;
  const _SectionLabel({required this.c, required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      color: c.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );
}

// Update Badge
class _UpdateBadge extends StatefulWidget {
  final AppColors c;
  final String? version;
  final String releaseUrl;
  final bool isGlass, isDark;

  const _UpdateBadge({
    required this.c,
    required this.version,
    required this.releaseUrl,
    required this.isGlass,
    required this.isDark,
  });

  @override
  State<_UpdateBadge> createState() => _UpdateBadgeState();
}

class _UpdateBadgeState extends State<_UpdateBadge>
    with SingleTickerProviderStateMixin {
  bool _hov = false;
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _open() {
    final url = widget.releaseUrl;
    if (Platform.isWindows) {
      Process.run('explorer', [url]);
    } else {
      Process.run('xdg-open', [url]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orange = widget.c.orange;
    final tip = widget.version != null
        ? 'v${widget.version} Available — Click to download'
        : 'New version available — Click to download';

    return Tooltip(
      message: tip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hov = true),
        onExit: (_) => setState(() => _hov = false),
        child: GestureDetector(
          onTap: _open,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) => AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _hov
                    ? orange.withValues(alpha: 0.28)
                    : Color.lerp(
                        orange.withValues(alpha: 0.10),
                        orange.withValues(alpha: 0.22),
                        _pulse.value,
                      ),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: orange.withValues(
                    alpha: _hov ? 0.75 : (0.30 + _pulse.value * 0.20),
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_circle_up_rounded, color: orange, size: 10),
                  const SizedBox(width: 4),
                  Text(
                    widget.version != null
                        ? 'v${widget.version} available'
                        : 'Update available',
                    style: TextStyle(
                      color: orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
