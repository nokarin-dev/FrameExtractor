import 'package:frameextractor/data/models/extraction_progress.dart';

abstract class ExtractionState {}

class ExtractionInitial extends ExtractionState {}

class ExtractionInProgress extends ExtractionState {
  final ExtractionProgress progress;
  final String phase; // 'downloading' | 'extracting'
  ExtractionInProgress(this.progress, {this.phase = 'extracting'});
}

class ExtractionSuccess extends ExtractionState {
  final String message;
  final String outputDirectory;
  ExtractionSuccess(this.message, {this.outputDirectory = ''});
}

class ExtractionFailure extends ExtractionState {
  final String error;
  ExtractionFailure(this.error);
}

class ExtractionCancelled extends ExtractionState {}
