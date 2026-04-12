import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frameextractor/data/services/ffmpeg/ffmpeg_service_base.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

class FramePreviewResult {
  final String? startTime;
  final String? endTime;
  const FramePreviewResult({this.startTime, this.endTime});
}

class FramePreviewScreen extends StatefulWidget {
  final String videoPath;
  final FFmpegService ffmpegService;
  final Duration? videoDuration;
  final void Function(FramePreviewResult)? onTimeSelected;

  const FramePreviewScreen({
    super.key,
    required this.videoPath,
    required this.ffmpegService,
    this.videoDuration,
    this.onTimeSelected,
  });

  @override
  State<FramePreviewScreen> createState() => _FramePreviewScreenState();
}

class _FramePreviewScreenState extends State<FramePreviewScreen> {
  String _timestamp = '00:00:01';
  String? _imagePath;
  bool _loading = false;
  String? _error;
  double _sliderSec = 1.0;
  int _fetchToken = 0;
  Timer? _debounceTimer;

  double get _maxSec {
    final dur = widget.videoDuration;
    if (dur == null || dur.inSeconds <= 0) return 600.0;
    return dur.inSeconds.toDouble();
  }

  @override
  void initState() {
    super.initState();
    _sliderSec = _maxSec > 1 ? 1.0 : 0.0;
    _timestamp = _secToTimestamp(_sliderSec);
    _fetchFrame();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchFrame() async {
    final token = ++_fetchToken;
    setState(() {
      _loading = true;
      _error = null;
    });

    final path = await widget.ffmpegService.extractPreviewFrame(
      videoPath: widget.videoPath,
      timestamp: _timestamp,
    );

    if (!mounted || token != _fetchToken) return;

    setState(() {
      _imagePath = path;
      _loading = false;
      if (path == null) _error = 'Could not extract frame at $_timestamp';
    });
  }

  void _onSliderChanged(double v) {
    setState(() {
      _sliderSec = v;
      _timestamp = _secToTimestamp(v);
    });
  }

  void _onSliderChangeEnd(double v) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), _fetchFrame);
  }

  String _secToTimestamp(double sec) {
    final total = sec.toInt().clamp(0, _maxSec.toInt());
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  void _copyTimestamp() {
    Clipboard.setData(ClipboardData(text: _timestamp));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $_timestamp to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _setAsStart() {
    widget.onTimeSelected?.call(FramePreviewResult(startTime: _timestamp));
    _showSetToast('Start time set to $_timestamp');
  }

  void _setAsEnd() {
    widget.onTimeSelected?.call(FramePreviewResult(endTime: _timestamp));
    _showSetToast('End time set to $_timestamp');
  }

  void _showSetToast(String msg) {
    final c = AppTheme.of(context).colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: c.green, size: 15),
            const SizedBox(width: 8),
            Text(msg, style: TextStyle(color: c.green, fontSize: 13)),
          ],
        ),
        backgroundColor: c.greenDim,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: c.green.withValues(alpha: 0.3)),
        ),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final c = theme.colors;
    final hasCallback = widget.onTimeSelected != null;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        title: Text(
          'Frame Preview',
          style: TextStyle(
            color: c.textPri,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: c.textSec),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
      ),
      body: Column(
        children: [
          // Preview area
          Expanded(
            child: GestureDetector(
              onLongPress: _imagePath != null ? _copyTimestamp : null,
              child: Center(
                child: _loading
                    ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(c.accent),
                      )
                    : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_rounded,
                              color: c.textMuted,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: c.textMuted,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: _fetchFrame,
                              icon: Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry'),
                              style: TextButton.styleFrom(
                                foregroundColor: c.accent,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _imagePath != null
                    ? Stack(
                        children: [
                          InteractiveViewer(
                            child: Image.file(
                              File(_imagePath!),
                              fit: BoxFit.contain,
                            ),
                          ),
                          // Long-press hint
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.touch_app_rounded,
                                    size: 11,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Long-press to copy timestamp',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Icon(
                        Icons.image_not_supported_outlined,
                        color: c.textMuted,
                        size: 48,
                      ),
              ),
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timestamp + refresh
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 13, color: c.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      _timestamp,
                      style: TextStyle(
                        color: c.textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Copy timestamp button
                    Tooltip(
                      message: 'Copy timestamp',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _copyTimestamp,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: c.surfaceHi,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: c.border),
                            ),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 12,
                              color: c.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _loading ? null : _fetchFrame,
                      icon: Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Refresh'),
                      style: TextButton.styleFrom(foregroundColor: c.accent),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Scrubber
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: c.accent,
                    inactiveTrackColor: c.surfaceHi,
                    thumbColor: c.accent,
                    overlayColor: c.accent.withValues(alpha: 0.15),
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                  ),
                  child: Slider(
                    value: _sliderSec.clamp(0.0, _maxSec),
                    min: 0,
                    max: _maxSec,
                    onChanged: _onSliderChanged,
                    onChangeEnd: _onSliderChangeEnd,
                  ),
                ),

                // Duration labels
                Row(
                  children: [
                    Text(
                      '0:00:00',
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _secToTimestamp(_maxSec),
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),

                if (hasCallback) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SetTimeBtn(
                          c: c,
                          label: 'Set as Start',
                          icon: Icons.play_circle_outline_rounded,
                          color: c.accent,
                          onTap: _setAsStart,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SetTimeBtn(
                          c: c,
                          label: 'Set as End',
                          icon: Icons.stop_circle_outlined,
                          color: c.green,
                          onTap: _setAsEnd,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetTimeBtn extends StatelessWidget {
  final AppColors c;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SetTimeBtn({
    required this.c,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.40)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
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
