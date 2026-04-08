import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frameextractor/data/services/ffmpeg/ffmpeg_service_base.dart';
import 'package:frameextractor/presentation/theme/app_theme.dart';

class FramePreviewScreen extends StatefulWidget {
  final String videoPath;
  final FFmpegService ffmpegService;
  const FramePreviewScreen({
    super.key,
    required this.videoPath,
    required this.ffmpegService,
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
  static const double _maxSec = 3600.0;

  @override
  void initState() {
    super.initState();
    _fetchFrame();
  }

  Future<void> _fetchFrame() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final path = await widget.ffmpegService.extractPreviewFrame(
      videoPath: widget.videoPath,
      timestamp: _timestamp,
    );
    if (!mounted) return;
    setState(() {
      _imagePath = path;
      _loading = false;
      if (path == null) _error = 'Could not extract frame at $_timestamp';
    });
  }

  String _secToTimestamp(double sec) {
    final total = sec.toInt();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final c = theme.colors;

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
            child: Center(
              child: _loading
                  ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(c.accent),
                    )
                  : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        style: TextStyle(color: c.textMuted, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : _imagePath != null
                  ? InteractiveViewer(
                      child: Image.file(File(_imagePath!), fit: BoxFit.contain),
                    )
                  : Icon(
                      Icons.image_not_supported_outlined,
                      color: c.textMuted,
                      size: 48,
                    ),
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 13, color: c.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      _timestamp,
                      style: TextStyle(
                        color: c.textPri,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
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
                const SizedBox(height: 8),
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
                    value: _sliderSec,
                    min: 0,
                    max: _maxSec,
                    onChanged: (v) => setState(() {
                      _sliderSec = v;
                      _timestamp = _secToTimestamp(v);
                    }),
                    onChangeEnd: (_) => _fetchFrame(),
                  ),
                ),
                Text(
                  'Drag slider to scrub. Frame is rendered at the selected timestamp.',
                  style: TextStyle(color: c.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
