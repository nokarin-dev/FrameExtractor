import 'package:frameextractor/data/models/extraction_params.dart';
import 'package:frameextractor/data/models/extraction_present.dart';
import 'package:frameextractor/data/models/extraction_progress.dart';
import 'package:frameextractor/data/services/youtube_service.dart';

abstract class ExtractionEvent {
  const ExtractionEvent();
}

class StartExtraction extends ExtractionEvent {
  final ExtractionParams params;
  const StartExtraction(this.params);
}

class StartYouTubeExtraction extends ExtractionEvent {
  final String url;
  final YouTubeQuality quality;
  final ExtractionParams params;
  const StartYouTubeExtraction({
    required this.url,
    required this.quality,
    required this.params,
  });
}

// Batch Extraction
class StartBatchExtraction extends ExtractionEvent {
  final List<ExtractionParams> paramsList;
  const StartBatchExtraction(this.paramsList);
}

// Control
class CancelExtraction extends ExtractionEvent {
  const CancelExtraction();
}

// Progress & Log
class UpdateProgress extends ExtractionEvent {
  final ExtractionProgress progress;
  const UpdateProgress(this.progress);
}

class AppendLog extends ExtractionEvent {
  final String line;
  final LogLevel level;
  const AppendLog(this.line, {this.level = LogLevel.info});
}

enum LogLevel { debug, info, warn, error }

// Presets
class SavePreset extends ExtractionEvent {
  final ExtractionPreset preset;
  const SavePreset(this.preset);
}

class DeletePreset extends ExtractionEvent {
  final String presetId;
  const DeletePreset(this.presetId);
}
