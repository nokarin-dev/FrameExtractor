class VideoMetadata {
  final Duration duration;
  final int width;
  final int height;
  final double fps;
  final String codec;
  final String? thumbnailPath;

  const VideoMetadata({
    required this.duration,
    required this.width,
    required this.height,
    required this.fps,
    required this.codec,
    this.thumbnailPath,
  });

  String get resolutionLabel => '$width×$height';

  String get durationFormatted {
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    final s = duration.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}
