import 'dart:convert';

class ExtractionRecord {
  final String id;
  final String videoPath;
  final String outputDirectory;
  final int frameCount;
  final DateTime completedAt;
  final Duration elapsed;
  final String format;
  final int fps;

  const ExtractionRecord({
    required this.id,
    required this.videoPath,
    required this.outputDirectory,
    required this.frameCount,
    required this.completedAt,
    required this.elapsed,
    required this.format,
    required this.fps,
  });

  String get videoName => videoPath.split('/').last.split('\\').last;

  Map<String, dynamic> toJson() => {
    'id': id,
    'videoPath': videoPath,
    'outputDirectory': outputDirectory,
    'frameCount': frameCount,
    'completedAt': completedAt.toIso8601String(),
    'elapsedMs': elapsed.inMilliseconds,
    'format': format,
    'fps': fps,
  };

  factory ExtractionRecord.fromJson(Map<String, dynamic> json) =>
      ExtractionRecord(
        id: json['id'] as String,
        videoPath: json['videoPath'] as String,
        outputDirectory: json['outputDirectory'] as String,
        frameCount: json['frameCount'] as int,
        completedAt: DateTime.parse(json['completedAt'] as String),
        elapsed: Duration(milliseconds: json['elapsedMs'] as int),
        format: json['format'] as String,
        fps: json['fps'] as int,
      );

  static List<ExtractionRecord> listFromJson(String raw) {
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ExtractionRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<ExtractionRecord> records) =>
      jsonEncode(records.map((r) => r.toJson()).toList());
}
