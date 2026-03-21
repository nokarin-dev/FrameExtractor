import 'package:frameextractor/data/models/extraction_params.dart';
import 'package:frameextractor/data/models/extraction_progress.dart';

/// Abstract interface
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
    final parts = t.split(':').map(double.parse).toList();
    return parts.length == 3 ? parts[0] * 3600 + parts[1] * 60 + parts[2] : 0;
  }

  ({int frames, Duration time}) estimateExtractionImpl(
    ExtractionParams params,
  ) {
    final s = secondsFromTimeString(params.startTime);
    final e = secondsFromTimeString(params.endTime);
    final dur = (e - s).clamp(0, double.infinity);
    final frames = (dur * params.fps).round();
    final speed = params.format == 'png' ? 100.0 : 150.0;
    return (frames: frames, time: Duration(seconds: (frames / speed).ceil()));
  }
}
