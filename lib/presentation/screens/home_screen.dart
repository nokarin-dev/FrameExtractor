import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frameextractor/data/models/extraction_present.dart';
import 'package:frameextractor/data/services/update_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:frameextractor/core/app_constants.dart';
import 'package:frameextractor/core/app_prefs.dart';
import 'package:frameextractor/data/models/extraction_params.dart';
import 'package:frameextractor/data/services/youtube_service.dart';
import 'package:frameextractor/presentation/bloc/extraction_bloc.dart';
import 'package:frameextractor/presentation/bloc/extraction_event.dart';
import 'package:frameextractor/presentation/bloc/extraction_state.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

enum _SourceMode { local, youtube }

bool get _isDesktop => !Platform.isAndroid;

// HomeScreen
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

  // State
  _SourceMode _sourceMode = _SourceMode.local;
  String? _videoPath;
  String? _outputDirectory;
  int _fps = AppConstants.defaultFps;
  String _format = AppConstants.defaultFormat;
  int _quality = AppConstants.defaultQuality;
  double _scale = AppConstants.defaultScale;
  YouTubeQuality _ytQuality = YouTubeQuality.p1080;
  bool _ytInfoLoading = false;
  YouTubeVideoInfo? _ytInfo;
  bool _showAdvanced = false;
  bool _openFolderOnDone = true;
  String _framePrefix = AppConstants.defaultPrefix;
  List<String> _recentVideos = [];
  UpdateResult? _updateResult;

  // Time field validation
  String? _startTimeError;
  String? _endTimeError;

  bool get _isExtracting =>
      context.read<ExtractionBloc>().state is ExtractionInProgress;

  bool get _settingsEnabled {
    if (_isExtracting) return false;
    if (_outputDirectory == null) return false;
    if (_sourceMode == _SourceMode.local) return _videoPath != null;
    return _ytInfo != null;
  }

  bool get _canExtract {
    if (_outputDirectory == null) return false;
    if (_startTimeError != null || _endTimeError != null) return false;
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

  ExtractionParams? _cachedParams;
  int _cachedEstimatedFrames = 0;
  String _cachedEstimatedSize = '';

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

  ExtractionParams? _buildParams() => _cachedParams;

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

  void _onUpdateResult() {
    if (!mounted) return;
    setState(() => _updateResult = UpdateService.resultNotifier.value);
  }

  void _onTimeChanged() {
    _validateTimeRange();
    _refreshEstimates();
  }

  Future<void> _loadPrefs() async {
    final lastOut = AppPrefs.lastOutputDir;
    final recents = await _filterExistingRecents(AppPrefs.recentVideos);

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

  @override
  void dispose() {
    UpdateService.resultNotifier.removeListener(_onUpdateResult);
    _pulseCtrl.dispose();
    _ytUrlCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
  }

  // Validation
  void _validateTimeRange() {
    final start = _startTimeCtrl.text;
    final end = _endTimeCtrl.text;

    String? startErr;
    String? endErr;

    final timePattern = RegExp(r'^\d{2}:\d{2}:\d{2}(\.\d+)?$');
    if (start.isNotEmpty && !timePattern.hasMatch(start)) {
      startErr = 'Use HH:MM:SS';
    }
    if (end.isNotEmpty && !timePattern.hasMatch(end)) {
      endErr = 'Use HH:MM:SS';
    }

    if (startErr == null &&
        endErr == null &&
        start.isNotEmpty &&
        end.isNotEmpty) {
      final s = _parseSeconds(start);
      final e = _parseSeconds(end);
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

  double? _parseSeconds(String t) {
    final parts = t.split(':');
    if (parts.length != 3) return null;
    final h = double.tryParse(parts[0]);
    final m = double.tryParse(parts[1]);
    final s = double.tryParse(parts[2]);
    if (h == null || m == null || s == null) return null;
    return h * 3600 + m * 60 + s;
  }

  // Build
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
                child: BlocBuilder<ExtractionBloc, ExtractionState>(
                  builder: (ctx, state) {
                    final extracting = state is ExtractionInProgress;

                    return Column(
                      children: [
                        _buildTitleBar(theme),
                        _buildSourceTabs(theme, disabled: extracting),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                            child: Column(
                              children: [
                                if (_sourceMode == _SourceMode.local)
                                  _buildLocalSourceCard(
                                    theme,
                                    disabled: extracting,
                                  )
                                else
                                  _buildYouTubeCard(
                                    theme,
                                    disabled: extracting,
                                  ),
                                const SizedBox(height: 10),
                                _buildOutputCard(theme, disabled: extracting),
                                const SizedBox(height: 10),
                                _buildSettingsCard(
                                  theme,
                                  disabled: !_settingsEnabled,
                                ),
                                const SizedBox(height: 4),
                                _buildAdvancedToggle(
                                  theme,
                                  disabled: !_settingsEnabled,
                                ),
                                if (_showAdvanced && _settingsEnabled) ...[
                                  const SizedBox(height: 10),
                                  _buildAdvancedCard(theme),
                                ],
                                if (_settingsEnabled &&
                                    _cachedEstimatedFrames > 0) ...[
                                  const SizedBox(height: 6),
                                  _buildEstimateRow(theme),
                                ],
                                const SizedBox(height: 10),
                                if (extracting)
                                  _buildProgressCard(theme, state),
                                const SizedBox(height: 10),
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
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Keyboard
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
  }

  // Estimate Row
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

  // Title bar
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
          Image(
            image: AssetImage("assets/icons/icon_32.png"),
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
            tooltip: 'View logs (Ctrl+L)',
            onTap: _showLogPanel,
            isGlass: isGlass,
            isDark: theme.isDark,
          ),
          const SizedBox(width: 4),
          _TitleBarBtn(
            c: c,
            icon: Icons.tune_rounded,
            tooltip: 'Settings (Ctrl+S)',
            onTap: () => _showSettings(),
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

  // Settings dialog
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

  // Log panel
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
        builder: (sheetCtx) => _ThemedSheetWrapper(
          parentContext: context,
          builder: (liveTheme) =>
              _LogContent(logs: bloc.logs, parentContext: context),
        ),
      );
    }
  }

  // Presets panel
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
              currentParams: _buildParams(),
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
        builder: (sheetCtx) => _ThemedSheetWrapper(
          parentContext: context,
          builder: (liveTheme) => _PresetsContent(
            parentContext: context,
            currentParams: _buildParams(),
            onApply: _applyPreset,
          ),
        ),
      );
    }
  }

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

  // Source tabs
  Widget _buildSourceTabs(AppTheme theme, {required bool disabled}) {
    final c = theme.colors;
    final isGlass = theme.isGlass;

    Widget tabs = Container(
      color: isGlass ? Colors.transparent : c.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _SourceTab(
            c: c,
            label: 'Local File',
            icon: Icons.folder_rounded,
            selected: _sourceMode == _SourceMode.local,
            onTap: disabled
                ? null
                : () => setState(() {
                    _sourceMode = _SourceMode.local;
                    _ytInfo = null;
                  }),
            isGlass: isGlass,
            isDark: theme.isDark,
          ),
          const SizedBox(width: 8),
          _SourceTab(
            c: c,
            label: 'YouTube',
            icon: Icons.play_circle_filled_rounded,
            selected: _sourceMode == _SourceMode.youtube,
            accentColor: c.ytRed,
            onTap: disabled
                ? null
                : () => setState(() => _sourceMode = _SourceMode.youtube),
            isGlass: isGlass,
            isDark: theme.isDark,
          ),
        ],
      ),
    );

    if (isGlass) {
      tabs = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: theme.isDark ? 0.18 : 0.55),
              border: Border(
                bottom: BorderSide(
                  color: theme.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : c.border.withValues(alpha: 0.60),
                ),
              ),
            ),
            child: tabs,
          ),
        ),
      );
    }
    return tabs;
  }

  // Card factory
  Widget _buildCard(
    AppTheme theme, {
    required String label,
    required Widget child,
  }) {
    return theme.isGlass
        ? _LiquidAppCard(theme: theme, label: label, child: child)
        : _ClassicAppCard(theme: theme, label: label, child: child);
  }

  // Local source card
  Widget _buildLocalSourceCard(AppTheme theme, {required bool disabled}) {
    final c = theme.colors;
    return _buildCard(
      theme,
      label: 'VIDEO SOURCE',
      child: Column(
        children: [
          _FileRow(
            c: c,
            icon: Icons.movie_rounded,
            label: 'Video File',
            value: _videoPath,
            placeholder: 'Select a video file…',
            accent: c.accent,
            disabled: disabled,
            onTap: disabled ? null : _pickVideoFile,
            isGlass: theme.isGlass,
            isDark: theme.isDark,
          ),
          if (_recentVideos.isNotEmpty && _videoPath == null && !disabled) ...[
            _Divider(c: c, isGlass: theme.isGlass, isDark: theme.isDark),
            _RecentVideosRow(
              c: c,
              recents: _recentVideos,
              onSelect: (path) => setState(() => _videoPath = path),
              onClear: () async {
                await AppPrefs.clearRecentVideos();
                setState(() => _recentVideos = []);
              },
            ),
          ],
          if (_videoPath != null) ...[
            _Divider(c: c, isGlass: theme.isGlass, isDark: theme.isDark),
            _ClearRow(
              c: c,
              disabled: disabled,
              onTap: () => setState(() => _videoPath = null),
              isGlass: theme.isGlass,
            ),
          ],
        ],
      ),
    );
  }

  // YouTube card
  Widget _buildYouTubeCard(AppTheme theme, {required bool disabled}) {
    final c = theme.colors;
    return _buildCard(
      theme,
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
                    controller: _ytUrlCtrl,
                    enabled: !disabled,
                    style: TextStyle(color: c.textPri, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'https://youtube.com/watch?v=…',
                      hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _fetchYtInfo(),
                  ),
                ),
                const SizedBox(width: 8),
                _SmallBtn(
                  c: c,
                  label: _ytInfoLoading ? '…' : 'Fetch',
                  onTap: (disabled || _ytInfoLoading) ? null : _fetchYtInfo,
                  color: c.accent,
                  isGlass: theme.isGlass,
                  isDark: theme.isDark,
                ),
              ],
            ),
          ),
          if (_ytInfo != null) ...[
            _Divider(c: c, isGlass: theme.isGlass, isDark: theme.isDark),
            Padding(
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
                          _ytInfo!.title,
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
                          '${_ytInfo!.uploader}  ·  ${_ytInfo!.durationFormatted}',
                          style: TextStyle(color: c.textSec, fontSize: 11),
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
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: c.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _Divider(c: c, isGlass: theme.isGlass, isDark: theme.isDark),
            Padding(
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
                          (q) => _GlossChip(
                            c: c,
                            label: q.label,
                            selected: _ytQuality == q,
                            disabled: disabled,
                            onTap: disabled
                                ? null
                                : () => setState(() => _ytQuality = q),
                            color: q == YouTubeQuality.audioOnly
                                ? c.purple
                                : c.accent,
                            isGlass: theme.isGlass,
                            isDark: theme.isDark,
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
  Widget _buildOutputCard(AppTheme theme, {required bool disabled}) {
    final c = theme.colors;
    return _buildCard(
      theme,
      label: 'OUTPUT',
      child: Column(
        children: [
          _FileRow(
            c: c,
            icon: Icons.folder_rounded,
            label: 'Output Folder',
            value: _outputDirectory,
            placeholder: 'Select output directory…',
            accent: c.purple,
            disabled: disabled,
            onTap: disabled ? null : _pickOutputDirectory,
            isGlass: theme.isGlass,
            isDark: theme.isDark,
          ),
          if (_outputDirectory != null) ...[
            _Divider(c: c, isGlass: theme.isGlass, isDark: theme.isDark),
            _ClearRow(
              c: c,
              disabled: disabled,
              onTap: () => setState(() => _outputDirectory = null),
              isGlass: theme.isGlass,
            ),
          ],
        ],
      ),
    );
  }

  // Settings card
  Widget _buildSettingsCard(AppTheme theme, {required bool disabled}) {
    final c = theme.colors;
    return _DisabledOverlay(
      disabled: disabled,
      tooltip: _settingsHint,
      isGlass: theme.isGlass,
      child: _buildCard(
        theme,
        label: 'EXTRACTION SETTINGS',
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      c: c,
                      controller: _startTimeCtrl,
                      label: 'Start',
                      icon: Icons.play_circle_outline_rounded,
                      errorText: _startTimeError,
                      disabled: disabled,
                      isGlass: theme.isGlass,
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
                    child: _TimeField(
                      c: c,
                      controller: _endTimeCtrl,
                      label: 'End',
                      icon: Icons.stop_circle_outlined,
                      errorText: _endTimeError,
                      disabled: disabled,
                      isGlass: theme.isGlass,
                      isDark: theme.isDark,
                    ),
                  ),
                ],
              ),
            ),
            _Divider(c: c, isGlass: theme.isGlass, isDark: theme.isDark),
            _SliderRow(
              c: c,
              label: 'FPS',
              value: _fps.toDouble(),
              display: '$_fps fps',
              min: AppConstants.minFps.toDouble(),
              max: AppConstants.maxFps.toDouble(),
              divisions: AppConstants.maxFps - AppConstants.minFps,
              color: c.accent,
              disabled: disabled,
              onChanged: (v) {
                setState(() => _fps = v.toInt());
                _refreshEstimates();
              },
            ),
            _Divider(c: c, isGlass: theme.isGlass, isDark: theme.isDark),
            _SliderRow(
              c: c,
              label: 'Quality',
              value: _quality.toDouble(),
              display: '$_quality%',
              min: 1,
              max: 100,
              divisions: 99,
              color: c.green,
              disabled: disabled,
              onChanged: (v) {
                setState(() => _quality = v.toInt());
                _refreshEstimates();
              },
            ),
            _Divider(c: c, isGlass: theme.isGlass, isDark: theme.isDark),
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
                          (fmt) => _GlossChip(
                            c: c,
                            label: fmt.toUpperCase(),
                            selected: _format == fmt,
                            disabled: disabled,
                            onTap: disabled
                                ? null
                                : () {
                                    setState(() => _format = fmt);
                                    _refreshEstimates();
                                  },
                            isGlass: theme.isGlass,
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

  // Advanced card
  Widget _buildAdvancedCard(AppTheme theme) {
    final c = theme.colors;
    return _buildCard(
      theme,
      label: 'ADVANCED',
      child: Column(
        children: [
          _SliderRow(
            c: c,
            label: 'Scale',
            value: _scale,
            display: '${(_scale * 100).toInt()}%',
            min: AppConstants.minScale,
            max: AppConstants.maxScale,
            divisions: 19,
            color: c.orange,
            onChanged: (v) {
              setState(() => _scale = v);
              _refreshEstimates();
            },
          ),
          _Divider(c: c, isGlass: theme.isGlass, isDark: theme.isDark),
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
                _CompactField(
                  c: c,
                  initialValue: _framePrefix,
                  hint: 'frame_',
                  onChanged: (v) {
                    _framePrefix = v;
                    _refreshEstimates();
                  },
                  isGlass: theme.isGlass,
                  isDark: theme.isDark,
                ),
              ],
            ),
          ),
          _Divider(c: c, isGlass: theme.isGlass, isDark: theme.isDark),
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
                  value: _openFolderOnDone,
                  onChanged: (v) => setState(() => _openFolderOnDone = v),
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
          _Divider(c: c, isGlass: theme.isGlass, isDark: theme.isDark),
          Padding(
            padding: const EdgeInsets.all(14),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _showSavePresetDialog(theme),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.isGlass
                        ? c.purple.withValues(alpha: 0.12)
                        : c.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.isGlass
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

  // Presets dialog
  void _showSavePresetDialog(AppTheme theme) {
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
                        if (name.isEmpty) return;
                        final preset = ExtractionPreset(
                          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                          name: name,
                          fps: _fps,
                          format: _format,
                          imageQuality: _quality,
                          resolutionScale: _scale,
                          startTime: _startTimeCtrl.text,
                          endTime: _endTimeCtrl.text,
                          frameNamePrefix: _framePrefix,
                          createdAt: DateTime.now(),
                        );
                        await AppPrefs.savePreset(preset);
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        final col = AppTheme.of(context).colors;
                        _toast(
                          'Preset "$name" saved!',
                          col.purple,
                          col.purple.withValues(alpha: 0.12),
                          Icons.bookmark_added_rounded,
                        );
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

  // Progress card
  Widget _buildProgressCard(AppTheme theme, ExtractionInProgress state) {
    final c = theme.colors;
    final p = state.progress;
    final isDownloading = state.phase == 'downloading';
    final color = isDownloading ? c.ytRed : c.accent;
    final bgTint = isDownloading
        ? c.redDim.withValues(alpha: 0.5)
        : c.accentDim.withValues(alpha: 0.5);

    Widget content = Padding(
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
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.percentage / 100,
              minHeight: 3,
              backgroundColor: c.surfaceHi,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
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

    Widget card = theme.isGlass
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            isDownloading ? 'DOWNLOADING' : 'EXTRACTING',
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

  // Action buttons
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

  // Hint
  Widget _buildHint(AppTheme theme) {
    final c = theme.colors;
    final String msg;
    if (_sourceMode == _SourceMode.local && _videoPath == null) {
      msg = 'Select a video file to continue';
    } else if (_outputDirectory == null) {
      msg = 'Select an output folder to continue';
    } else if (_sourceMode == _SourceMode.youtube && _ytInfo == null) {
      msg = 'Fetch a YouTube video to continue';
    } else if (_startTimeError != null || _endTimeError != null) {
      msg = 'Fix the time range errors to continue';
    } else {
      return const SizedBox.shrink();
    }

    if (theme.isGlass) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.accent.withValues(alpha: 0.30)),
            ),
            child: Row(
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
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.accentDim,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
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
              color: c.accent.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // State change handler
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

  // File picker
  Future<void> _pickVideoFile() async {
    final r = await FilePicker.pickFiles(type: FileType.video);
    if (r?.files.single.path != null) {
      final path = r!.files.single.path!;
      await AppPrefs.addRecentVideo(path);
      setState(() {
        _videoPath = path;
        _recentVideos = AppPrefs.recentVideos;
      });
      _refreshEstimates();
    }
  }

  Future<void> _pickOutputDirectory() async {
    final r = await FilePicker.getDirectoryPath();
    if (r != null) {
      await AppPrefs.setLastOutputDir(r);
      setState(() => _outputDirectory = r);
      _refreshEstimates();
    }
  }

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

  // Extraction
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
    if (_sourceMode == _SourceMode.youtube) {
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
      context.read<ExtractionBloc>().add(CancelExtraction());

  void _openFolder(String path) {
    if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else {
      Process.run('xdg-open', [path]);
    }
  }

  String _fmtDuration(Duration d) {
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    }
    return '${d.inSeconds}s';
  }
}

class _ThemedDialogWrapper extends StatelessWidget {
  final BuildContext parentContext;
  final Widget Function(AppTheme) builder;
  const _ThemedDialogWrapper({
    required this.parentContext,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final liveTheme = AppTheme.of(parentContext);
    return builder(liveTheme);
  }
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

// GlassBg
class _GlassBg extends StatelessWidget {
  final bool isDark;
  const _GlassBg({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF07090D) : const Color(0xFFECEEF6),
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0C12),
                  Color(0xFF080A0F),
                  Color(0xFF0C0E14),
                ],
                stops: [0.0, 0.5, 1.0],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEDF0FA),
                  Color(0xFFEAECF5),
                  Color(0xFFEFF1FA),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
      ),
    );
  }
}

// GlassDialog
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
    final isGlass = theme.isGlass;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: isGlass
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

// GlassSheet
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
                  // FIX: real border token on light glass
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

// LiquidAppCard
class _LiquidAppCard extends StatelessWidget {
  final AppTheme theme;
  final String label;
  final Widget child;
  const _LiquidAppCard({
    required this.theme,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              color: GlassTokens.cardLabelColor(c, isDark: theme.isDark),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ),
        GlassContainer(
          useOwnLayer: true,
          settings: GlassTokens.cardSettings(isDark: theme.isDark),
          shape: LiquidRoundedRectangle(borderRadius: 18),
          child: child,
        ),
      ],
    );
  }
}

// ClassicAppCard
class _ClassicAppCard extends StatelessWidget {
  final AppTheme theme;
  final String label;
  final Widget child;
  const _ClassicAppCard({
    required this.theme,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
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
        Container(
          decoration: theme.classicCard(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: child,
          ),
        ),
      ],
    );
  }
}

// Settings Content
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
                    _ShortcutRow(c: c, key_: 'Space', label: 'Start extraction'),
                    _ShortcutRow(c: c, key_: 'Esc', label: 'Cancel extraction'),
                    _ShortcutRow(c: c, key_: 'Ctrl+L', label: 'Open log panel'),
                    _ShortcutRow(c: c, key_: 'Ctrl+S', label: 'Open settings panel'),
                    _ShortcutRow(c: c, key_: 'Ctrl+P', label: 'Open presets panel'),
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

// Small close button
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

// Divider
class _Divider extends StatelessWidget {
  final AppColors c;
  final bool isGlass, isDark;
  const _Divider({
    required this.c,
    required this.isGlass,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    color: isGlass
        ? (isDark
              ? Colors.white.withValues(alpha: 0.07)
              : c.border.withValues(alpha: 0.50))
        : c.border,
  );
}

// DisabledOverlay
class _DisabledOverlay extends StatelessWidget {
  final bool disabled;
  final bool isGlass;
  final String tooltip;
  final Widget child;
  const _DisabledOverlay({
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

// ClearRow
class _ClearRow extends StatelessWidget {
  final AppColors c;
  final bool disabled;
  final VoidCallback onTap;
  final bool isGlass;
  const _ClearRow({
    required this.c,
    required this.disabled,
    required this.onTap,
    required this.isGlass,
  });

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
    child: InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              size: 14,
              color: disabled ? c.textMuted : c.red.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              'Clear',
              style: TextStyle(
                color: disabled ? c.textMuted : c.red.withValues(alpha: 0.7),
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

// TitleBarBtn
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

// SourceTab
class _SourceTab extends StatelessWidget {
  final AppColors c;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color? accentColor;
  final bool isGlass, isDark;
  const _SourceTab({
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

    if (isGlass) {
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
              color: selected
                  ? eff.withValues(alpha: 0.18)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : c.surface.withValues(alpha: 0.55)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? eff.withValues(alpha: 0.50)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : c.borderHi.withValues(alpha: 0.60)),
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
                      : (isDark
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
                        : (isDark
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
              color: selected ? eff.withValues(alpha: 0.5) : c.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? eff : c.textMuted, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? eff : c.textMuted,
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

// FileRow
class _FileRow extends StatefulWidget {
  final AppColors c;
  final IconData icon;
  final String label, placeholder;
  final String? value;
  final Color accent;
  final bool disabled, isGlass, isDark;
  final VoidCallback? onTap;
  const _FileRow({
    required this.c,
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.accent,
    required this.isGlass,
    required this.isDark,
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
    final eff = widget.disabled ? widget.c.textMuted : widget.accent;

    return Tooltip(
      message: hasValue ? widget.value! : '',
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: widget.disabled
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hov = true),
        onExit: (_) => setState(() => _hov = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: (!widget.disabled && _hov)
                  ? (widget.isGlass
                        ? Colors.white.withValues(
                            alpha: widget.isDark ? 0.06 : 0.18,
                          )
                        : widget.c.borderHi.withValues(alpha: 0.5))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: eff.withValues(
                        alpha: widget.disabled ? 0.05 : 0.14,
                      ),
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
                            color: widget.isGlass
                                ? (widget.isDark
                                      ? Colors.white.withValues(alpha: 0.38)
                                      : widget.c.textSec)
                                : widget.c.textSec,
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
                            color: hasValue
                                ? (widget.isGlass
                                      ? (widget.isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.88,
                                              )
                                            : widget.c.textPri)
                                      : widget.c.textPri)
                                : (widget.isGlass
                                      ? (widget.isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.28,
                                              )
                                            : widget.c.textMuted)
                                      : widget.c.textMuted),
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
                    color: hasValue
                        ? eff
                        : (widget.isGlass
                              ? (widget.isDark
                                    ? Colors.white.withValues(alpha: 0.20)
                                    : widget.c.textMuted)
                              : widget.c.textMuted),
                    size: 18,
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

// SliderRow
class _SliderRow extends StatelessWidget {
  final AppColors c;
  final String label, display;
  final double value, min, max;
  final int divisions;
  final Color color;
  final bool disabled;
  final ValueChanged<double> onChanged;
  const _SliderRow({
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

// GlossChip
class _GlossChip extends StatelessWidget {
  final AppColors c;
  final String label;
  final bool selected, disabled, isGlass, isDark;
  final VoidCallback? onTap;
  final Color color;
  const _GlossChip({
    required this.c,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isGlass,
    required this.isDark,
    this.disabled = false,
    this.color = const Color(0xFF4F8EF7),
  });

  @override
  Widget build(BuildContext context) {
    if (!isGlass) {
      final eff = disabled ? c.textMuted : color;
      return MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? eff : c.surfaceHi,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: selected ? eff : c.border),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : (disabled ? c.textMuted : c.textSec),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: GlassTokens.pillDecoration(
            c,
            selected: selected,
            accent: disabled ? c.textMuted : color,
            isDark: isDark,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? (disabled ? c.textMuted : color)
                  : (isDark ? Colors.white.withValues(alpha: 0.65) : c.textSec),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// TimeField
class _TimeField extends StatelessWidget {
  final AppColors c;
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool disabled, isGlass, isDark;
  final String? errorText;

  const _TimeField({
    required this.c,
    required this.controller,
    required this.label,
    required this.icon,
    this.disabled = false,
    this.isGlass = false,
    this.isDark = true,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final fillColor = isGlass
        ? (isDark
              ? Colors.white.withValues(alpha: disabled ? 0.04 : 0.08)
              : c.surface.withValues(alpha: disabled ? 0.40 : 0.65))
        : (disabled ? c.disabled : c.surfaceHi);

    final borderColor = hasError
        ? c.red
        : isGlass
        ? (isDark
              ? Colors.white.withValues(alpha: disabled ? 0.08 : 0.18)
              : c.border.withValues(alpha: disabled ? 0.40 : 0.70))
        : c.border;

    final labelColor = hasError
        ? c.red
        : isGlass
        ? (isDark
              ? Colors.white.withValues(alpha: disabled ? 0.20 : 0.50)
              : (disabled ? c.textMuted : c.textSec))
        : c.textSec;

    final iconColor = hasError
        ? c.red
        : isGlass
        ? (isDark ? Colors.white.withValues(alpha: 0.35) : c.textMuted)
        : c.textMuted;

    return TextField(
      controller: controller,
      enabled: !disabled,
      style: TextStyle(
        color: hasError ? c.red : (disabled ? c.textMuted : c.textPri),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: labelColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        errorText: errorText,
        errorStyle: TextStyle(color: c.red, fontSize: 9, height: 0.9),
        prefixIcon: Icon(icon, color: iconColor, size: 14),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 30,
          minHeight: 30,
        ),
        filled: true,
        fillColor: hasError
            ? (isGlass
                  ? c.red.withValues(alpha: 0.06)
                  : c.redDim.withValues(alpha: 0.5))
            : fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: borderColor,
            width: hasError ? 1.5 : 1.0,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: hasError ? c.red : c.accent,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.red, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.red, width: 1.5),
        ),
      ),
    );
  }
}

// CompactField
class _CompactField extends StatelessWidget {
  final AppColors c;
  final String initialValue, hint;
  final ValueChanged<String> onChanged;
  final bool isGlass, isDark;
  const _CompactField({
    required this.c,
    required this.initialValue,
    required this.hint,
    required this.onChanged,
    this.isGlass = false,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = isGlass
        ? (isDark
              ? Colors.white.withValues(alpha: 0.07)
              : c.surface.withValues(alpha: 0.60))
        : c.surfaceHi;
    final borderColor = isGlass
        ? (isDark
              ? Colors.white.withValues(alpha: 0.18)
              : c.border.withValues(alpha: 0.70))
        : c.border;

    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      style: TextStyle(color: c.textPri, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isGlass
              ? (isDark ? Colors.white.withValues(alpha: 0.28) : c.textMuted)
              : c.textMuted,
          fontSize: 13,
        ),
        filled: true,
        fillColor: fillColor,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
      ),
    );
  }
}

// SmallBtn
class _SmallBtn extends StatelessWidget {
  final AppColors c;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool isGlass, isDark;
  const _SmallBtn({
    required this.c,
    required this.label,
    required this.onTap,
    required this.color,
    required this.isGlass,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: onTap == null
                ? (isGlass
                      ? Colors.white.withValues(alpha: 0.05)
                      : color.withValues(alpha: 0.05))
                : color.withValues(alpha: isGlass ? 0.20 : 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: onTap == null
                  ? (isGlass
                        ? (isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : c.border)
                        : color.withValues(alpha: 0.2))
                  : color.withValues(alpha: 0.50),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: onTap == null ? c.textMuted : color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ActionBtn
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

// SectionLabel
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

// RecentVideosRow
class _RecentVideosRow extends StatelessWidget {
  final AppColors c;
  final List<String> recents;
  final ValueChanged<String> onSelect;
  final VoidCallback onClear;
  const _RecentVideosRow({
    required this.c,
    required this.recents,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => Padding(
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
                      Icon(Icons.movie_outlined, size: 11, color: c.textMuted),
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
                        ? 'v\${widget.version} available'
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
