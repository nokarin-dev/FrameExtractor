import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import 'package:frameextractor/data/models/extraction_params.dart';
import 'package:frameextractor/data/models/extraction_progress.dart';
import 'package:frameextractor/data/services/ffmpeg/ffmpeg_service_base.dart';

// Mobile implementation (Android)
class FFmpegServiceMobile extends FFmpegService {
  @override
  Future<bool> isFFmpegAvailable() async {
    try {
      final session = await FFmpegKit.execute('-version');
      return ReturnCode.isSuccess(await session.getReturnCode());
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
        '${params.outputDirectory}/${params.frameNamePrefix}%05d.${params.format}';
    final vf = buildVfFilter(params);
    final qv = qualityToQv(params.imageQuality);

    final cmd =
        '-y -ss ${params.startTime} -to ${params.endTime} '
        '-i "${params.videoPath}" -vf $vf -q:v $qv -fps_mode vfr "$out"';

    onLog?.call('ffmpeg $cmd');

    var frames = 0;
    var lastEmit = DateTime.now();
    var completed = false;
    var success = false;

    FFmpegKitConfig.enableStatisticsCallback((stats) {
      final now = DateTime.now();
      if (now.difference(lastEmit).inMilliseconds < 300) return;
      lastEmit = now;

      final timeSec = stats.getTime() / 1000.0;
      frames = (timeSec * params.fps).toInt();

      if (frames > 0) {
        final el = now.difference(t0);
        final pct = est.frames > 0
            ? ((frames / est.frames) * 100).toInt().clamp(0, 99)
            : 0;
        Duration? eta;
        if (est.frames > frames && frames > 0) {
          eta = Duration(
            milliseconds: ((el.inMilliseconds / frames) * (est.frames - frames))
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

    FFmpegKitConfig.enableLogCallback((log) => onLog?.call(log.getMessage()));

    final session = await FFmpegKit.executeAsync(cmd, (completedSession) async {
      success = ReturnCode.isSuccess(await completedSession.getReturnCode());
      completed = true;
    });

    while (!completed) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    FFmpegKitConfig.enableStatisticsCallback(null);
    FFmpegKitConfig.enableLogCallback(null);

    final total = DateTime.now().difference(t0);

    if (success) {
      onProgress?.call(
        ExtractionProgress(
          message: 'Done! $frames frames in ${total.inSeconds}s',
          percentage: 100,
          framesProcessed: frames,
          estimatedFrames: est.frames,
          timeElapsed: total,
        ),
      );
    } else {
      final output = await session.getOutput();
      onProgress?.call(
        ExtractionProgress(
          message: 'FFmpeg failed',
          percentage: 0,
          timeElapsed: total,
        ),
      );
      onLog?.call('[ERROR] FFmpeg output: $output');
    }

    return success;
  }

  @override
  Future<void> cancelExtraction() async {
    await FFmpegKit.cancel();
  }

  @override
  void dispose() {}
}
