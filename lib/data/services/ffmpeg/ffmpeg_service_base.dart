import 'package:frameextractor/core/app_constants.dart';
import 'package:frameextractor/data/models/extraction_params.dart';
import 'package:frameextractor/data/models/extraction_progress.dart';

// Abstract interface
abstract class FFmpegService {
  Future<bool> isFFmpegAvailable();

  ({int frames, Duration time}) estimateExtraction(ExtractionParams params);

  Future<bool> extractFrames({
    required ExtractionParams params,
    void Function(ExtractionProgress)? onProgress,
    void Function(String)? onLog,
  });

  Future<void> cancelExtraction();

  void dispose();

  // Helpers
  double secondsFromTimeString(String t) {
    final parts = t.split(':').map(double.tryParse).toList();
    if (parts.length != 3 || parts.any((p) => p == null)) return 0;
    return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
  }

  ({int frames, Duration time}) estimateExtractionImpl(
    ExtractionParams params,
  ) {
    final s = secondsFromTimeString(params.startTime);
    final e = secondsFromTimeString(params.endTime);
    final dur = (e - s).clamp(0.0, double.infinity);
    final frames = (dur * params.fps).round();
    final speed = params.format == 'png'
        ? AppConstants.desktopSpeed * 0.67
        : AppConstants.desktopSpeed;
    return (frames: frames, time: Duration(seconds: (frames / speed).ceil()));
  }

  String buildVfFilter(ExtractionParams params) {
    final filters = <String>[];
    if (params.resolutionScale != 1.0) {
      filters.add(
        'scale=iw*${params.resolutionScale}:ih*${params.resolutionScale}:flags=lanczos',
      );
    }
    filters.add('fps=${params.fps}');
    return filters.join(',');
  }

  int qualityToQv(int quality) =>
      (1 + ((100 - quality) * 0.3)).toInt().clamp(1, 31);
}
