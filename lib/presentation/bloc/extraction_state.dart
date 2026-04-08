import 'package:frameextractor/data/models/extraction_progress.dart';

abstract class ExtractionState {
  const ExtractionState();
}

class ExtractionInitial extends ExtractionState {
  const ExtractionInitial();
}

class ExtractionInProgress extends ExtractionState {
  final ExtractionProgress progress;
  final String phase; // 'downloading' | 'extracting' | 'copying' | 'batch'
  final int batchIndex;
  final int batchTotal;

  const ExtractionInProgress(
    this.progress, {
    this.phase = 'extracting',
    this.batchIndex = 0,
    this.batchTotal = 1,
  });

  bool get isBatch => batchTotal > 1;
}

class ExtractionSuccess extends ExtractionState {
  final String message;
  final String outputDirectory;

  final int frameCount;

  const ExtractionSuccess(
    this.message, {
    this.outputDirectory = '',
    this.frameCount = 0,
  });
}

class ExtractionFailure extends ExtractionState {
  final String error;
  const ExtractionFailure(this.error);
}

class ExtractionCancelled extends ExtractionState {
  const ExtractionCancelled();
}
