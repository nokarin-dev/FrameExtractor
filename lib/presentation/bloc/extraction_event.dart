import 'package:frameextractor/data/models/extraction_params.dart';
import 'package:frameextractor/data/models/extraction_present.dart';
import 'package:frameextractor/data/models/extraction_progress.dart';
import 'package:frameextractor/data/services/youtube_service.dart';

abstract class ExtractionEvent {}

class StartExtraction extends ExtractionEvent {
  final ExtractionParams params;
  StartExtraction(this.params);
}

class StartYouTubeExtraction extends ExtractionEvent {
  final String url;
  final YouTubeQuality quality;
  final ExtractionParams params;
  StartYouTubeExtraction({
    required this.url,
    required this.quality,
    required this.params,
  });
}

class CancelExtraction extends ExtractionEvent {}

class UpdateProgress extends ExtractionEvent {
  final ExtractionProgress progress;
  UpdateProgress(this.progress);
}

class AppendLog extends ExtractionEvent {
  final String line;
  AppendLog(this.line);
}

class SavePreset extends ExtractionEvent {
  final ExtractionPreset preset;
  SavePreset(this.preset);
}

class DeletePreset extends ExtractionEvent {
  final String presetId;
  DeletePreset(this.presetId);
}
