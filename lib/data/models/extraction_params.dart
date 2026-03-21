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
    this.format = 'png',
    this.imageQuality = 95,
    this.resolutionScale = 1.0,
  });

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
  }) {
    return ExtractionParams(
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
  }
}
