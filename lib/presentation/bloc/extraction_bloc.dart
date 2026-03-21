import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frameextractor/core/android_path_helper.dart';
import 'package:frameextractor/data/models/extraction_progress.dart';
import 'package:frameextractor/data/services/ffmpeg/ffmpeg_service_base.dart';
import 'package:frameextractor/data/services/youtube_service.dart';
import 'package:frameextractor/presentation/bloc/extraction_event.dart';
import 'package:frameextractor/presentation/bloc/extraction_state.dart';

class ExtractionBloc extends Bloc<ExtractionEvent, ExtractionState> {
  final FFmpegService ffmpegService;
  final YouTubeService youTubeService;

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  ExtractionBloc({required this.ffmpegService, required this.youTubeService})
    : super(ExtractionInitial()) {
    on<StartExtraction>(_onStartExtraction);
    on<StartYouTubeExtraction>(_onStartYouTubeExtraction);
    on<CancelExtraction>(_onCancelExtraction);
    on<UpdateProgress>(_onUpdateProgress);
    on<AppendLog>(_onAppendLog);
  }

  // Local file extraction
  Future<void> _onStartExtraction(
    StartExtraction event,
    Emitter<ExtractionState> emit,
  ) async {
    _logs.clear();
    emit(
      ExtractionInProgress(
        ExtractionProgress(message: 'Starting extraction…', percentage: 0),
      ),
    );

    final videoPath = await AndroidPathHelper.resolveVideoPath(
      event.params.videoPath,
    );

    final userOutputUri = event.params.outputDirectory;
    _logs.add('[DEBUG] raw outputDirectory: $userOutputUri');

    final String ffmpegOutputDir;
    if (Platform.isAndroid) {
      ffmpegOutputDir = await AndroidPathHelper.getWritableOutputDir();
      _logs.add('[Android] ffmpeg output → $ffmpegOutputDir');
    } else {
      ffmpegOutputDir = await AndroidPathHelper.resolveOutputDirectory(
        userOutputUri,
      );
    }

    _logs.add('Video: $videoPath');
    _logs.add('Output: $ffmpegOutputDir');

    final params = event.params.copyWith(
      videoPath: videoPath,
      outputDirectory: ffmpegOutputDir,
    );

    final success = await ffmpegService.extractFrames(
      params: params,
      onProgress: (p) {
        if (p.percentage < 100) add(UpdateProgress(p));
      },
      onLog: (line) => add(AppendLog(line)),
    );

    if (isClosed) return;

    if (success) {
      if (Platform.isAndroid && AndroidPathHelper.isSafUri(userOutputUri)) {
        await _copyFramesToUserDir(
          emit: emit,
          tempDir: ffmpegOutputDir,
          targetUri: userOutputUri,
        );
        return;
      }
      emit(
        ExtractionSuccess(
          'Extraction completed successfully',
          outputDirectory: ffmpegOutputDir,
        ),
      );
    } else {
      emit(ExtractionFailure('Extraction failed. Check logs for details.'));
    }
  }

  // YouTube
  Future<void> _onStartYouTubeExtraction(
    StartYouTubeExtraction event,
    Emitter<ExtractionState> emit,
  ) async {
    _logs.clear();

    final userOutputUri = event.params.outputDirectory;
    _logs.add('[DEBUG] raw outputDirectory: $userOutputUri');
    _logs.add('[DEBUG] isAndroid: ${Platform.isAndroid}');
    _logs.add('[DEBUG] isSafUri: ${AndroidPathHelper.isSafUri(userOutputUri)}');

    final String ffmpegOutputDir;

    if (Platform.isAndroid) {
      ffmpegOutputDir = await AndroidPathHelper.getWritableOutputDir();
      _logs.add('[Android] ffmpeg output → $ffmpegOutputDir');
    } else {
      ffmpegOutputDir = await AndroidPathHelper.resolveOutputDirectory(
        userOutputUri,
      );
    }

    // Download
    emit(
      ExtractionInProgress(
        ExtractionProgress(message: 'Downloading from YouTube…', percentage: 0),
        phase: 'downloading',
      ),
    );

    final videoPath = await youTubeService.downloadVideo(
      url: event.url,
      quality: event.quality,
      outputDirectory: ffmpegOutputDir,
      onProgress: (msg, pct) {
        if (pct < 100) {
          add(
            UpdateProgress(ExtractionProgress(message: msg, percentage: pct)),
          );
        }
      },
      onLog: (line) => add(AppendLog(line)),
    );

    if (isClosed) return;

    if (videoPath == null) {
      emit(ExtractionFailure('YouTube download failed. Check logs.'));
      return;
    }

    add(AppendLog('Download complete → $videoPath'));

    // Extract frames
    emit(
      ExtractionInProgress(
        ExtractionProgress(
          message: 'Starting frame extraction…',
          percentage: 0,
        ),
        phase: 'extracting',
      ),
    );

    final params = event.params.copyWith(
      videoPath: videoPath,
      outputDirectory: ffmpegOutputDir,
    );

    final success = await ffmpegService.extractFrames(
      params: params,
      onProgress: (p) {
        if (p.percentage < 100) add(UpdateProgress(p));
      },
      onLog: (line) => add(AppendLog(line)),
    );

    if (isClosed) return;

    // Delete the downloaded video
    await _deleteFile(videoPath);

    if (success) {
      if (Platform.isAndroid) {
        await _copyFramesToUserDir(
          emit: emit,
          tempDir: ffmpegOutputDir,
          targetUri: userOutputUri,
        );
        return;
      }
      emit(
        ExtractionSuccess(
          'YouTube extraction completed!',
          outputDirectory: ffmpegOutputDir,
        ),
      );
    } else {
      emit(ExtractionFailure('Frame extraction failed. Check logs.'));
    }
  }

  Future<void> _copyFramesToUserDir({
    required Emitter<ExtractionState> emit,
    required String tempDir,
    required String targetUri,
  }) async {
    final allFiles = Directory(tempDir).listSync().whereType<File>().where((f) {
      final ext = f.path.split('.').last.toLowerCase();
      return ['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(ext);
    }).toList()..sort((a, b) => a.path.compareTo(b.path));

    final frameCount = allFiles.length;
    _logs.add('[Frames] $frameCount extracted in $tempDir');

    if (frameCount == 0) {
      emit(ExtractionFailure('No frames were produced. Check logs.'));
      return;
    }

    if (AndroidPathHelper.isSafUri(targetUri)) {
      emit(
        ExtractionInProgress(
          ExtractionProgress(
            message: 'Copying $frameCount frames…',
            percentage: 99,
          ),
          phase: 'extracting',
        ),
      );
      final copied = await AndroidPathHelper.copyFramesToUri(
        tempOutputDir: tempDir,
        targetUri: targetUri,
      );
      for (final f in allFiles) {
        try {
          await f.delete();
        } catch (_) {}
      }
      if (copied > 0) {
        emit(
          ExtractionSuccess(
            'Done! $copied frames copied to your chosen folder.',
            outputDirectory: targetUri,
          ),
        );
      } else {
        _logs.add('[WARN] SAF copy failed. Frames kept in app dir.');
        emit(
          ExtractionSuccess(
            'Done! $frameCount frames in:\nAndroid/data/com.nokarin.frameextractor/files/',
            outputDirectory: tempDir,
          ),
        );
      }
      return;
    }

    try {
      final destDir = Directory(targetUri);
      await destDir.create(recursive: true);
      var copied = 0;
      for (final f in allFiles) {
        final dest = File('\${destDir.path}/\${f.uri.pathSegments.last}');
        await f.copy(dest.path);
        copied++;
      }
      for (final f in allFiles) {
        try {
          await f.delete();
        } catch (_) {}
      }
      _logs.add('[Copy] $copied frames → $targetUri');
      emit(
        ExtractionSuccess(
          'Done! $copied frames saved.',
          outputDirectory: targetUri,
        ),
      );
    } catch (e) {
      _logs.add('[INFO] Cannot write to $targetUri: $e');
      emit(
        ExtractionSuccess(
          'Done! $frameCount frames saved to:\n'
          'Android/data/com.nokarin.frameextractor/files/\n\n'
          'Access via Files app → Internal Storage → Android → data → com.nokarin.frameextractor → files',
          outputDirectory: tempDir,
        ),
      );
    }
  }

  // Cancel
  Future<void> _onCancelExtraction(
    CancelExtraction event,
    Emitter<ExtractionState> emit,
  ) async {
    await ffmpegService.cancelExtraction();
    await youTubeService.cancelDownload();
    _logs.add('[Cancelled by user]');
    emit(ExtractionCancelled());
  }

  void _onUpdateProgress(UpdateProgress event, Emitter<ExtractionState> emit) {
    if (state is! ExtractionInProgress) return;
    final phase = (state as ExtractionInProgress).phase;
    emit(ExtractionInProgress(event.progress, phase: phase));
  }

  void _onAppendLog(AppendLog event, Emitter<ExtractionState> emit) {
    _logs.add(event.line);
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      _logs.add('[WARN] Could not delete $path: $e');
    }
  }

  @override
  Future<void> close() {
    ffmpegService.dispose();
    youTubeService.dispose();
    return super.close();
  }
}
