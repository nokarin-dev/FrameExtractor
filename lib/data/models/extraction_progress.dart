class ExtractionProgress {
  final String message;
  final int percentage;
  final int framesProcessed;
  final int estimatedFrames;
  final Duration? timeElapsed;
  final Duration? timeRemaining;

  const ExtractionProgress({
    required this.message,
    required this.percentage,
    this.framesProcessed = 0,
    this.estimatedFrames = 0,
    this.timeElapsed,
    this.timeRemaining,
  });

  ExtractionProgress copyWith({
    String? message,
    int? percentage,
    int? framesProcessed,
    int? estimatedFrames,
    Duration? timeElapsed,
    Duration? timeRemaining,
  }) {
    return ExtractionProgress(
      message: message ?? this.message,
      percentage: percentage ?? this.percentage,
      framesProcessed: framesProcessed ?? this.framesProcessed,
      estimatedFrames: estimatedFrames ?? this.estimatedFrames,
      timeElapsed: timeElapsed ?? this.timeElapsed,
      timeRemaining: timeRemaining ?? this.timeRemaining,
    );
  }
}
