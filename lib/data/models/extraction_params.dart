import 'package:frameextractor/core/app_constants.dart';

class ExtractionParams {
  final String videoPath;
  final String outputDirectory;
  final String startTime;
  final String endTime;
  final int fps;
  final String frameNamePrefix;
  final String format;
  final int imageQuality;
  final double resolutionScale;

  const ExtractionParams({
    required this.videoPath,
    required this.outputDirectory,
    required this.startTime,
    required this.endTime,
    required this.fps,
    this.frameNamePrefix = 'frame_',
    this.format = 'jpg',
    this.imageQuality = 90,
    this.resolutionScale = 1.0,
  });

  // Validation
  List<String> validate() {
    final errors = <String>[];

    if (videoPath.trim().isEmpty) errors.add('Video path is required.');
    if (outputDirectory.trim().isEmpty) {
      errors.add('Output directory is required.');
    }

    final startSec = parseTimeString(startTime);
    final endSec = parseTimeString(endTime);

    if (startSec == null) {
      errors.add('Start time format is invalid. Use HH:MM:SS.');
    }
    if (endSec == null) errors.add('End time format is invalid. Use HH:MM:SS.');
    if (startSec != null && endSec != null) {
      if (startSec >= endSec) errors.add('Start time must be before end time.');
      if ((endSec - startSec) < 0.1) {
        errors.add('Time range is too short (minimum 0.1 s).');
      }
    }

    if (fps < AppConstants.minFps || fps > AppConstants.maxFps) {
      errors.add(
        'FPS must be between ${AppConstants.minFps} and ${AppConstants.maxFps}.',
      );
    }
    if (imageQuality < 1 || imageQuality > 100) {
      errors.add('Image quality must be between 1 and 100.');
    }
    if (resolutionScale < AppConstants.minScale ||
        resolutionScale > AppConstants.maxScale) {
      errors.add(
        'Resolution scale must be between ${AppConstants.minScale} and ${AppConstants.maxScale}.',
      );
    }
    if (frameNamePrefix.trim().isEmpty) {
      errors.add('Frame name prefix cannot be empty.');
    }
    if (RegExp(r'[<>:"/\\|?*]').hasMatch(frameNamePrefix)) {
      errors.add('Frame prefix contains illegal characters.');
    }

    return errors;
  }

  bool get isValid => validate().isEmpty;

  List<String> validateForYouTube() {
    final errors = <String>[];

    if (outputDirectory.trim().isEmpty) {
      errors.add('Output directory is required.');
    }

    final startSec = parseTimeString(startTime);
    final endSec = parseTimeString(endTime);

    if (startSec == null) {
      errors.add('Start time format is invalid. Use HH:MM:SS.');
    }
    if (endSec == null) errors.add('End time format is invalid. Use HH:MM:SS.');
    if (startSec != null && endSec != null) {
      if (startSec >= endSec) errors.add('Start time must be before end time.');
      if ((endSec - startSec) < 0.1) {
        errors.add('Time range is too short (minimum 0.1 s).');
      }
    }

    if (fps < AppConstants.minFps || fps > AppConstants.maxFps) {
      errors.add(
        'FPS must be between ${AppConstants.minFps} and ${AppConstants.maxFps}.',
      );
    }
    if (imageQuality < 1 || imageQuality > 100) {
      errors.add('Image quality must be between 1 and 100.');
    }
    if (resolutionScale < AppConstants.minScale ||
        resolutionScale > AppConstants.maxScale) {
      errors.add(
        'Resolution scale must be between ${AppConstants.minScale} and ${AppConstants.maxScale}.',
      );
    }
    if (frameNamePrefix.trim().isEmpty) {
      errors.add('Frame name prefix cannot be empty.');
    }
    if (RegExp(r'[<>:\"/\\|?*]').hasMatch(frameNamePrefix)) {
      errors.add('Frame prefix contains illegal characters.');
    }

    return errors;
  }

  factory ExtractionParams.validated({
    required String videoPath,
    required String outputDirectory,
    required String startTime,
    required String endTime,
    required int fps,
    String frameNamePrefix = 'frame_',
    String format = 'jpg',
    int imageQuality = 90,
    double resolutionScale = 1.0,
  }) {
    final params = ExtractionParams(
      videoPath: videoPath,
      outputDirectory: outputDirectory,
      startTime: startTime,
      endTime: endTime,
      fps: fps,
      frameNamePrefix: frameNamePrefix,
      format: format,
      imageQuality: imageQuality,
      resolutionScale: resolutionScale,
    );
    final errors = params.validate();
    if (errors.isNotEmpty) {
      throw ArgumentError(errors.join('\n'));
    }
    return params;
  }

  // Estimate
  int get estimatedFrameCount {
    final s = parseTimeString(startTime) ?? 0;
    final e = parseTimeString(endTime) ?? 0;
    final dur = (e - s).clamp(0.0, double.infinity);
    return (dur * fps).round();
  }

  int get estimatedSizeBytes {
    final frames = estimatedFrameCount;
    final bytesPerFrame = switch (format) {
      'png' => 500 * 1024,
      'jpg' => 80 * 1024,
      'webp' => 60 * 1024,
      'bmp' => 3 * 1024 * 1024,
      _ => 100 * 1024,
    };
    return frames * bytesPerFrame;
  }

  String get estimatedSizeFormatted {
    final bytes = estimatedSizeBytes;
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  // Utilities
  ExtractionParams copyWith({
    String? videoPath,
    String? outputDirectory,
    String? startTime,
    String? endTime,
    int? fps,
    String? frameNamePrefix,
    String? format,
    int? imageQuality,
    double? resolutionScale,
  }) => ExtractionParams(
    videoPath: videoPath ?? this.videoPath,
    outputDirectory: outputDirectory ?? this.outputDirectory,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    fps: fps ?? this.fps,
    frameNamePrefix: frameNamePrefix ?? this.frameNamePrefix,
    format: format ?? this.format,
    imageQuality: imageQuality ?? this.imageQuality,
    resolutionScale: resolutionScale ?? this.resolutionScale,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractionParams &&
          videoPath == other.videoPath &&
          outputDirectory == other.outputDirectory &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          fps == other.fps &&
          frameNamePrefix == other.frameNamePrefix &&
          format == other.format &&
          imageQuality == other.imageQuality &&
          resolutionScale == other.resolutionScale;

  @override
  int get hashCode => Object.hash(
    videoPath,
    outputDirectory,
    startTime,
    endTime,
    fps,
    frameNamePrefix,
    format,
    imageQuality,
    resolutionScale,
  );

  @override
  String toString() =>
      'ExtractionParams(video: $videoPath, fps: $fps, format: $format, '
      'quality: $imageQuality%, scale: ${resolutionScale}x, '
      'range: $startTime → $endTime)';
}

double? parseTimeString(String t) {
  final parts = t.split(':');
  if (parts.length != 3) return null;
  final h = double.tryParse(parts[0]);
  final m = double.tryParse(parts[1]);
  final s = double.tryParse(parts[2]);
  if (h == null || m == null || s == null) return null;
  if (m >= 60 || s >= 60) return null;
  return h * 3600 + m * 60 + s;
}
