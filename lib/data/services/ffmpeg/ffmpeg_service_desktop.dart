import 'dart:convert';
import 'dart:io';

import 'package:frameextractor/core/app_constants.dart';
import 'package:frameextractor/core/binary_manager.dart';
import 'package:frameextractor/data/models/extraction_params.dart';
import 'package:frameextractor/data/models/extraction_progress.dart';
import 'package:frameextractor/data/models/video_metadata.dart';
import 'package:frameextractor/data/services/ffmpeg/ffmpeg_service_base.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Desktop implementation (Windows / Linux)
class FFmpegServiceDesktop extends FFmpegService {
  Process? _activeProcess;

  String get _ffmpeg => BinaryManager.instance.ffmpegPath!;

  @override
  Future<bool> isFFmpegAvailable() async {
    try {
      final r = await Process.run(_ffmpeg, ['-version']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  // Metadata
  @override
  Future<VideoMetadata?> getVideoMetadata(String videoPath) async {
    try {
      final result = await Process.run(_ffmpeg, ['-i', videoPath]);
      final stderr = result.stderr as String;

      Duration duration = Duration.zero;
      final durMatch = RegExp(
        r'Duration:\s+(\d+):(\d+):(\d+)\.(\d+)',
      ).firstMatch(stderr);
      if (durMatch != null) {
        duration = Duration(
          hours: int.parse(durMatch.group(1)!),
          minutes: int.parse(durMatch.group(2)!),
          seconds: int.parse(durMatch.group(3)!),
          milliseconds: int.parse(
            durMatch.group(4)!.padRight(3, '0').substring(0, 3),
          ),
        );
      }

      int w = 0, h = 0;
      double fps = 0;
      String codec = 'unknown';
      final vidMatch = RegExp(
        r'Video:\s+(\w+).*?(\d{3,5})x(\d{3,5}).*?([\d.]+)\s+fps',
      ).firstMatch(stderr);
      if (vidMatch != null) {
        codec = vidMatch.group(1)!;
        w = int.tryParse(vidMatch.group(2)!) ?? 0;
        h = int.tryParse(vidMatch.group(3)!) ?? 0;
        fps = double.tryParse(vidMatch.group(4)!) ?? 0;
      }

      final thumbPath = await _generateThumbnail(videoPath);

      return VideoMetadata(
        duration: duration,
        width: w,
        height: h,
        fps: fps,
        codec: codec,
        thumbnailPath: thumbPath,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _generateThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbPath = p.join(
        tempDir.path,
        'thumb_${videoPath.hashCode.abs()}.jpg',
      );
      if (File(thumbPath).existsSync()) return thumbPath;

      final result = await Process.run(_ffmpeg, [
        '-y',
        '-ss',
        '00:00:01',
        '-i',
        videoPath,
        '-vframes',
        '1',
        '-q:v',
        '3',
        '-vf',
        'scale=320:-1',
        thumbPath,
      ]);

      return result.exitCode == 0 && File(thumbPath).existsSync()
          ? thumbPath
          : null;
    } catch (_) {
      return null;
    }
  }

  // Preview frame
  @override
  Future<String?> extractPreviewFrame({
    required String videoPath,
    required String timestamp,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outPath = p.join(
        tempDir.path,
        'preview_${videoPath.hashCode.abs()}_${timestamp.replaceAll(':', '-')}.jpg',
      );

      final result = await Process.run(_ffmpeg, [
        '-y',
        '-ss',
        timestamp,
        '-i',
        videoPath,
        '-vframes',
        '1',
        '-q:v',
        '3',
        outPath,
      ]);

      if (result.exitCode == 0 && await File(outPath).exists()) return outPath;
      return null;
    } catch (_) {
      return null;
    }
  }

  // Estimate
  @override
  ({int frames, Duration time}) estimateExtraction(ExtractionParams params) =>
      estimateExtractionImpl(params);

  // Extract frame
  @override
  Future<bool> extractFrames({
    required ExtractionParams params,
    void Function(ExtractionProgress)? onProgress,
    void Function(String)? onLog,
  }) async {
    final errors = params.validate();
    if (errors.isNotEmpty) {
      onLog?.call('[ERR] Validation failed:\n${errors.join('\n')}');
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
    final threads = AppConstants.ffmpegThreads;

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

    onLog?.call('$_ffmpeg ${args.join(' ')}');

    try {
      _activeProcess = await Process.start(_ffmpeg, args);

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
      onLog?.call('[ERR] ProcessException: ${e.message}');
      onProgress?.call(
        ExtractionProgress(message: 'Error: ${e.message}', percentage: 0),
      );
      return false;
    } catch (e) {
      _activeProcess = null;
      onLog?.call('[ERR] Unexpected: $e');
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
