import 'dart:convert';
import 'dart:io';

import 'package:frameextractor/core/app_constants.dart';
import 'package:frameextractor/core/binary_manager.dart';
import 'package:frameextractor/data/models/extraction_params.dart';
import 'package:frameextractor/data/models/extraction_progress.dart';
import 'package:frameextractor/data/services/ffmpeg/ffmpeg_service_base.dart';

// Desktop implementation (Windows / Linux)
class FFmpegServiceDesktop extends FFmpegService {
  Process? _activeProcess;

  String get _bin => BinaryManager.instance.ffmpegPath!;

  @override
  Future<bool> isFFmpegAvailable() async {
    try {
      final r = await Process.run(_bin, ['-version']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  ({int frames, Duration time}) estimateExtraction(ExtractionParams params) =>
      estimateExtractionImpl(params);

  @override
  Future<bool> extractFrames({
    required ExtractionParams params,
    void Function(ExtractionProgress)? onProgress,
    void Function(String)? onLog,
  }) async {
    final errors = params.validate();
    if (errors.isNotEmpty) {
      onLog?.call('[ERROR] Validation failed:\n${errors.join('\n')}');
      onProgress?.call(
        ExtractionProgress(
          message: 'Invalid parameters: ${errors.first}',
          percentage: 0,
        ),
      );
      return false;
    }

    final est = estimateExtraction(params);
    final t0 = DateTime.now();

    final out =
        '${params.outputDirectory}${Platform.pathSeparator}'
        '${params.frameNamePrefix}%05d.${params.format}';

    final vf = buildVfFilter(params);
    final qv = qualityToQv(params.imageQuality);
    final threads = AppConstants.ffmpegThreads; // 0 = auto

    final args = [
      '-y',
      '-ss',
      params.startTime,
      '-to',
      params.endTime,
      '-i',
      params.videoPath,
      '-vf',
      vf,
      '-q:v',
      '$qv',
      '-fps_mode',
      'vfr',
      if (threads > 0) ...['-threads', '$threads'],
      out,
    ];

    onLog?.call('$_bin ${args.join(' ')}');

    try {
      _activeProcess = await Process.start(_bin, args);

      var frames = 0;
      var lastEmit = DateTime.now();

      _activeProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            onLog?.call(line);
            final m = RegExp(r'frame=\s*(\d+)').firstMatch(line);
            if (m != null) frames = int.parse(m.group(1)!);

            final now = DateTime.now();
            if (now.difference(lastEmit).inMilliseconds < 300) return;
            lastEmit = now;

            if (frames > 0) {
              final el = now.difference(t0);
              final pct = est.frames > 0
                  ? ((frames / est.frames) * 100).toInt().clamp(0, 99)
                  : 0;
              Duration? eta;
              if (est.frames > frames && frames > 0) {
                eta = Duration(
                  milliseconds:
                      ((el.inMilliseconds / frames) * (est.frames - frames))
                          .toInt(),
                );
              }
              onProgress?.call(
                ExtractionProgress(
                  message: 'Extracting… $frames / ${est.frames} frames',
                  percentage: pct,
                  framesProcessed: frames,
                  estimatedFrames: est.frames,
                  timeElapsed: el,
                  timeRemaining: eta,
                ),
              );
            }
          });

      final code = await _activeProcess!.exitCode;
      _activeProcess = null;
      final total = DateTime.now().difference(t0);

      if (code == 0) {
        onProgress?.call(
          ExtractionProgress(
            message: 'Done! $frames frames in ${total.inSeconds}s',
            percentage: 100,
            framesProcessed: frames,
            estimatedFrames: est.frames,
            timeElapsed: total,
          ),
        );
        return true;
      } else {
        onProgress?.call(
          ExtractionProgress(
            message: 'FFmpeg exited with code $code',
            percentage: 0,
            timeElapsed: total,
          ),
        );
        return false;
      }
    } on ProcessException catch (e) {
      _activeProcess = null;
      onLog?.call('[ERROR] ProcessException: ${e.message}');
      onProgress?.call(
        ExtractionProgress(message: 'Error: ${e.message}', percentage: 0),
      );
      return false;
    } catch (e) {
      _activeProcess = null;
      onLog?.call('[ERROR] Unexpected: $e');
      onProgress?.call(
        ExtractionProgress(message: 'Unexpected error: $e', percentage: 0),
      );
      return false;
    }
  }

  @override
  Future<void> cancelExtraction() async {
    _activeProcess?.kill(ProcessSignal.sigterm);
    if (Platform.isWindows) _activeProcess?.kill();
    _activeProcess = null;
  }

  @override
  void dispose() => cancelExtraction();
}
