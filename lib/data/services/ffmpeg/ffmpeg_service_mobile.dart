import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import 'package:frameextractor/data/models/extraction_params.dart';
import 'package:frameextractor/data/models/extraction_progress.dart';
import 'package:frameextractor/data/services/ffmpeg/ffmpeg_service_base.dart';

/// Mobile implementation (Android / iOS).
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
    final est = estimateExtraction(params);
    final t0 = DateTime.now();

    final out =
        '${params.outputDirectory}/${params.frameNamePrefix}%05d.${params.format}';
    final qv = (1 + ((100 - params.imageQuality) * 0.3)).toInt().clamp(1, 31);
    final vf = [
      if (params.resolutionScale != 1.0)
        'scale=iw*${params.resolutionScale}:ih*${params.resolutionScale}',
      'fps=${params.fps}',
    ].join(',');

    final cmd =
        '-y -ss ${params.startTime} -to ${params.endTime} '
        '-i "${params.videoPath}" -vf $vf -q:v $qv -fps_mode vfr "$out"';

    onLog?.call('ffmpeg $cmd');

    var frames = 0;
    var lastEmit = DateTime.now();

    FFmpegKitConfig.enableStatisticsCallback((stats) {
      final now = DateTime.now();
      if (now.difference(lastEmit).inMilliseconds < 500) return;
      lastEmit = now;

      final timeSec = stats.getTime() / 1000.0;
      frames = (timeSec * params.fps).toInt();

      if (frames > 0) {
        final el = now.difference(t0);
        final pct = est.frames > 0
            ? ((frames / est.frames) * 100).toInt().clamp(0, 99)
            : 0;
        Duration? eta;
        if (est.frames > frames) {
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

    final session = await FFmpegKit.execute(cmd);

    FFmpegKitConfig.enableStatisticsCallback(null);
    FFmpegKitConfig.enableLogCallback(null);

    final success = ReturnCode.isSuccess(await session.getReturnCode());
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
      onLog?.call('FFmpeg error: $output');
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
