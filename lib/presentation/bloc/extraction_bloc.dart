import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frameextractor/core/android_path_helper.dart';
import 'package:frameextractor/core/app_prefs.dart';
import 'package:frameextractor/data/models/extraction_params.dart';
import 'package:frameextractor/data/models/extraction_progress.dart';
import 'package:frameextractor/data/models/extraction_record.dart';
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
    on<StartBatchExtraction>(_onStartBatchExtraction);
    on<CancelExtraction>(_onCancelExtraction);
    on<UpdateProgress>(_onUpdateProgress);
    on<AppendLog>(_onAppendLog);
    on<SavePreset>(_onSavePreset);
    on<DeletePreset>(_onDeletePreset);
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

    await _persistSettings(event.params);

    final videoPath = await AndroidPathHelper.resolveVideoPath(
      event.params.videoPath,
    );
    _log('Video: $videoPath');

    final String ffmpegOutputDir;
    if (Platform.isAndroid) {
      ffmpegOutputDir = await AndroidPathHelper.getWritableOutputDir();
      _log('[Android] ffmpeg output → $ffmpegOutputDir');
    } else {
      ffmpegOutputDir = await AndroidPathHelper.resolveOutputDirectory(
        event.params.outputDirectory,
      );
    }
    _log('Output: $ffmpegOutputDir');

    final params = event.params.copyWith(
      videoPath: videoPath,
      outputDirectory: ffmpegOutputDir,
    );

    final started = DateTime.now();
    final success = await ffmpegService.extractFrames(
      params: params,
      onProgress: (p) {
        if (p.percentage < 100) add(UpdateProgress(p));
      },
      onLog: (line) => add(AppendLog(line)),
    );

    if (isClosed) return;

    final userOutputUri = event.params.outputDirectory;

    if (success) {
      if (Platform.isAndroid && AndroidPathHelper.isSafUri(userOutputUri)) {
        await _copyFramesToUserDir(
          emit: emit,
          tempDir: ffmpegOutputDir,
          targetUri: userOutputUri,
          started: started,
          params: params,
        );
        return;
      }
      final frameCount = _countFramesIn(ffmpegOutputDir, params.format);
      await _saveHistoryRecord(
        params: params,
        started: started,
        frameCount: frameCount,
      );
      emit(
        ExtractionSuccess(
          'Extraction completed successfully',
          outputDirectory: ffmpegOutputDir,
          frameCount: frameCount,
        ),
      );
    } else {
      emit(
        const ExtractionFailure('Extraction failed. Check logs for details.'),
      );
    }
  }

  // YouTube
  Future<void> _onStartYouTubeExtraction(
    StartYouTubeExtraction event,
    Emitter<ExtractionState> emit,
  ) async {
    _logs.clear();
    youTubeService.resetCancelFlag();

    final userOutputUri = event.params.outputDirectory;

    final String ffmpegOutputDir;
    if (Platform.isAndroid) {
      ffmpegOutputDir = await AndroidPathHelper.getWritableOutputDir();
      _log('[Android] ffmpeg output → $ffmpegOutputDir');
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
      emit(const ExtractionFailure('YouTube download failed. Check logs.'));
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
    final started = DateTime.now();

    final success = await ffmpegService.extractFrames(
      params: params,
      onProgress: (p) {
        if (p.percentage < 100) add(UpdateProgress(p));
      },
      onLog: (line) => add(AppendLog(line)),
    );

    if (isClosed) return;

    await _deleteFile(videoPath);

    if (success) {
      if (Platform.isAndroid) {
        await _copyFramesToUserDir(
          emit: emit,
          tempDir: ffmpegOutputDir,
          targetUri: userOutputUri,
          started: started,
          params: params,
        );
        return;
      }
      final frameCount = _countFramesIn(ffmpegOutputDir, params.format);
      await _saveHistoryRecord(
        params: params,
        started: started,
        frameCount: frameCount,
      );
      emit(
        ExtractionSuccess(
          'YouTube extraction completed!',
          outputDirectory: ffmpegOutputDir,
          frameCount: frameCount,
        ),
      );
    } else {
      emit(const ExtractionFailure('Frame extraction failed. Check logs.'));
    }
  }

  // Batch
  Future<void> _onStartBatchExtraction(
    StartBatchExtraction event,
    Emitter<ExtractionState> emit,
  ) async {
    _logs.clear();

    final jobs = event.paramsList;
    if (jobs.isEmpty) {
      emit(const ExtractionFailure('Batch list is empty.'));
      return;
    }

    int totalFrames = 0;
    String lastOutputDir = '';

    for (var i = 0; i < jobs.length; i++) {
      if (isClosed) return;

      final jobParams = jobs[i];
      _log(
        '[Batch] Job ${i + 1}/${jobs.length}: ${jobParams.startTime} → ${jobParams.endTime}',
      );

      final videoPath = await AndroidPathHelper.resolveVideoPath(
        jobParams.videoPath,
      );
      final String ffmpegOutputDir;
      if (Platform.isAndroid) {
        ffmpegOutputDir = await AndroidPathHelper.getWritableOutputDir();
      } else {
        ffmpegOutputDir = await AndroidPathHelper.resolveOutputDirectory(
          jobParams.outputDirectory,
        );
      }

      final params = jobParams.copyWith(
        videoPath: videoPath,
        outputDirectory: ffmpegOutputDir,
      );

      emit(
        ExtractionInProgress(
          ExtractionProgress(
            message: 'Batch ${i + 1}/${jobs.length}: extracting…',
            percentage: 0,
          ),
          phase: 'batch',
          batchIndex: i,
          batchTotal: jobs.length,
        ),
      );

      final started = DateTime.now();
      final success = await ffmpegService.extractFrames(
        params: params,
        onProgress: (p) {
          if (p.percentage < 100) {
            add(
              UpdateProgress(
                ExtractionProgress(
                  message: 'Batch ${i + 1}/${jobs.length}: ${p.message}',
                  percentage: p.percentage,
                  framesProcessed: p.framesProcessed,
                  estimatedFrames: p.estimatedFrames,
                  timeElapsed: p.timeElapsed,
                  timeRemaining: p.timeRemaining,
                ),
              ),
            );
          }
        },
        onLog: (line) => add(AppendLog(line)),
      );

      if (isClosed) return;

      if (!success) {
        emit(ExtractionFailure('Batch job ${i + 1} failed. Check logs.'));
        return;
      }

      final frameCount = _countFramesIn(ffmpegOutputDir, params.format);
      totalFrames += frameCount;
      lastOutputDir = ffmpegOutputDir;

      await _saveHistoryRecord(
        params: params,
        started: started,
        frameCount: frameCount,
      );
      await _persistSettings(params);
    }

    emit(
      ExtractionSuccess(
        'Batch complete! $totalFrames frames across ${jobs.length} jobs.',
        outputDirectory: lastOutputDir,
        frameCount: totalFrames,
      ),
    );
  }

  Future<void> _copyFramesToUserDir({
    required Emitter<ExtractionState> emit,
    required String tempDir,
    required String targetUri,
    required DateTime started,
    required ExtractionParams params,
  }) async {
    final allFiles = Directory(tempDir).listSync().whereType<File>().where((f) {
      final ext = f.path.split('.').last.toLowerCase();
      return ['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(ext);
    }).toList()..sort((a, b) => a.path.compareTo(b.path));

    final frameCount = allFiles.length;
    _log('[Frames] $frameCount extracted in $tempDir');

    if (frameCount == 0) {
      emit(const ExtractionFailure('No frames were produced. Check logs.'));
      return;
    }

    if (AndroidPathHelper.isSafUri(targetUri)) {
      if (isClosed) return;
      emit(
        ExtractionInProgress(
          ExtractionProgress(
            message: 'Copying $frameCount frames…',
            percentage: 99,
          ),
          phase: 'copying',
        ),
      );

      if (isClosed) return;
      final copied = await AndroidPathHelper.copyFramesToUri(
        tempOutputDir: tempDir,
        targetUri: targetUri,
      );

      if (isClosed) return;

      for (final f in allFiles) {
        try {
          await f.delete();
        } catch (_) {}
      }

      if (copied > 0) {
        await _saveHistoryRecord(
          params: params,
          started: started,
          frameCount: copied,
        );
        emit(
          ExtractionSuccess(
            'Done! $copied frames copied to your chosen folder.',
            outputDirectory: targetUri,
            frameCount: copied,
          ),
        );
      } else {
        _log('[WARN] SAF copy failed. Frames kept in app dir.');
        await _saveHistoryRecord(
          params: params,
          started: started,
          frameCount: frameCount,
        );
        emit(
          ExtractionSuccess(
            'Done! $frameCount frames in:\nAndroid/data/xyz.nokarin.frameextractor/files/',
            outputDirectory: tempDir,
            frameCount: frameCount,
          ),
        );
      }
      return;
    }

    try {
      if (isClosed) return;
      final destDir = Directory(targetUri);
      await destDir.create(recursive: true);
      var copied = 0;
      for (final f in allFiles) {
        if (isClosed) return;
        final dest = File('${destDir.path}/${f.uri.pathSegments.last}');
        await f.copy(dest.path);
        copied++;
      }
      for (final f in allFiles) {
        try {
          await f.delete();
        } catch (_) {}
      }
      _log('[Copy] $copied frames → $targetUri');
      await _saveHistoryRecord(
        params: params,
        started: started,
        frameCount: copied,
      );
      emit(
        ExtractionSuccess(
          'Done! $copied frames saved.',
          outputDirectory: targetUri,
          frameCount: copied,
        ),
      );
    } catch (e) {
      _log('[INFO] Cannot write to $targetUri: $e');
      await _saveHistoryRecord(
        params: params,
        started: started,
        frameCount: frameCount,
      );
      emit(
        ExtractionSuccess(
          'Done! $frameCount frames saved to:\n'
          'Android/data/xyz.nokarin.frameextractor/files/\n\n'
          'Access via Files app → Internal Storage → Android → data '
          '→ xyz.nokarin.frameextractor → files',
          outputDirectory: tempDir,
          frameCount: frameCount,
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
    _log('[Cancelled by user]');
    emit(const ExtractionCancelled());
  }

  // Logs
  void _onUpdateProgress(UpdateProgress event, Emitter<ExtractionState> emit) {
    if (state is! ExtractionInProgress) return;
    final current = state as ExtractionInProgress;
    emit(
      ExtractionInProgress(
        event.progress,
        phase: current.phase,
        batchIndex: current.batchIndex,
        batchTotal: current.batchTotal,
      ),
    );
  }

  void _onAppendLog(AppendLog event, Emitter<ExtractionState> emit) {
    if (event.level == LogLevel.debug) {
      _logs.add('[DEBUG] ${event.line}');
    } else {
      _logs.add(event.line);
    }
  }

  // Presets
  Future<void> _onSavePreset(
    SavePreset event,
    Emitter<ExtractionState> emit,
  ) async {
    await AppPrefs.savePreset(event.preset);
  }

  Future<void> _onDeletePreset(
    DeletePreset event,
    Emitter<ExtractionState> emit,
  ) async {
    await AppPrefs.deletePreset(event.presetId);
  }

  // Helpers
  Future<void> _persistSettings(ExtractionParams p) async {
    await Future.wait([
      AppPrefs.setLastFps(p.fps),
      AppPrefs.setLastFormat(p.format),
      AppPrefs.setLastQuality(p.imageQuality),
      AppPrefs.setLastScale(p.resolutionScale),
      AppPrefs.setLastStartTime(p.startTime),
      AppPrefs.setLastEndTime(p.endTime),
      AppPrefs.setLastPrefix(p.frameNamePrefix),
    ]);
  }

  int _countFramesIn(String dir, String format) {
    try {
      return Directory(dir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.$format'))
          .length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _saveHistoryRecord({
    required ExtractionParams params,
    required DateTime started,
    required int frameCount,
  }) async {
    await AppPrefs.addHistoryRecord(
      ExtractionRecord(
        id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
        videoPath: params.videoPath,
        outputDirectory: params.outputDirectory,
        frameCount: frameCount,
        completedAt: DateTime.now(),
        elapsed: DateTime.now().difference(started),
        format: params.format,
        fps: params.fps,
      ),
    );
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      _log('[WARN] Could not delete $path: $e');
    }
  }

  void _log(String line) => _logs.add(line);

  @override
  Future<void> close() {
    ffmpegService.dispose();
    youTubeService.dispose();
    return super.close();
  }
}
