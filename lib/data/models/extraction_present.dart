import 'dart:convert';

class ExtractionPreset {
  final String id;
  final String name;
  final int fps;
  final String format;
  final int imageQuality;
  final double resolutionScale;
  final String startTime;
  final String endTime;
  final String frameNamePrefix;
  final DateTime createdAt;

  const ExtractionPreset({
    required this.id,
    required this.name,
    required this.fps,
    required this.format,
    required this.imageQuality,
    required this.resolutionScale,
    required this.startTime,
    required this.endTime,
    required this.frameNamePrefix,
    required this.createdAt,
  });

  // Built-in default presets
  static List<ExtractionPreset> get defaults => [
    ExtractionPreset(
      id: 'preset_high_quality_png',
      name: 'High Quality PNG',
      fps: 30,
      format: 'png',
      imageQuality: 100,
      resolutionScale: 1.0,
      startTime: '00:00:00',
      endTime: '00:00:05',
      frameNamePrefix: 'frame_',
      createdAt: DateTime(2026),
    ),
    ExtractionPreset(
      id: 'preset_fast_preview',
      name: 'Fast Preview',
      fps: 5,
      format: 'jpg',
      imageQuality: 70,
      resolutionScale: 0.5,
      startTime: '00:00:00',
      endTime: '00:00:05',
      frameNamePrefix: 'preview_',
      createdAt: DateTime(2026),
    ),
    ExtractionPreset(
      id: 'preset_web_optimized',
      name: 'Web Optimized',
      fps: 24,
      format: 'webp',
      imageQuality: 85,
      resolutionScale: 0.75,
      startTime: '00:00:00',
      endTime: '00:00:05',
      frameNamePrefix: 'frame_',
      createdAt: DateTime(2026),
    ),
    ExtractionPreset(
      id: 'preset_4k_lossless',
      name: '4K Lossless',
      fps: 60,
      format: 'png',
      imageQuality: 100,
      resolutionScale: 2.0,
      startTime: '00:00:00',
      endTime: '00:00:05',
      frameNamePrefix: 'frame_',
      createdAt: DateTime(2026),
    ),
  ];

  bool get isDefault => id.startsWith('preset_');

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'fps': fps,
    'format': format,
    'imageQuality': imageQuality,
    'resolutionScale': resolutionScale,
    'startTime': startTime,
    'endTime': endTime,
    'frameNamePrefix': frameNamePrefix,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ExtractionPreset.fromJson(Map<String, dynamic> json) =>
      ExtractionPreset(
        id: json['id'] as String,
        name: json['name'] as String,
        fps: json['fps'] as int,
        format: json['format'] as String,
        imageQuality: json['imageQuality'] as int,
        resolutionScale: (json['resolutionScale'] as num).toDouble(),
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String,
        frameNamePrefix: json['frameNamePrefix'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  static List<ExtractionPreset> listFromJson(String raw) {
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ExtractionPreset.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<ExtractionPreset> presets) =>
      jsonEncode(presets.map((p) => p.toJson()).toList());

  ExtractionPreset copyWith({
    String? id,
    String? name,
    int? fps,
    String? format,
    int? imageQuality,
    double? resolutionScale,
    String? startTime,
    String? endTime,
    String? frameNamePrefix,
  }) => ExtractionPreset(
    id: id ?? this.id,
    name: name ?? this.name,
    fps: fps ?? this.fps,
    format: format ?? this.format,
    imageQuality: imageQuality ?? this.imageQuality,
    resolutionScale: resolutionScale ?? this.resolutionScale,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    frameNamePrefix: frameNamePrefix ?? this.frameNamePrefix,
    createdAt: createdAt,
  );

  @override
  String toString() => 'ExtractionPreset($name, fps:$fps, format:$format)';
}
