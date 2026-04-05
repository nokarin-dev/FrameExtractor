import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_explode;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:frameextractor/core/binary_manager.dart';

enum YouTubeQuality {
  best('Best available', null),
  p1080('1080p', VideoResolution(1080, 1920)),
  p720('720p', VideoResolution(720, 1280)),
  p480('480p', VideoResolution(480, 854)),
  p360('360p', VideoResolution(360, 640)),
  audioOnly('Audio only', null);

  final String label;
  final VideoResolution? resolution;
  const YouTubeQuality(this.label, this.resolution);
}

class VideoResolution {
  final int height;
  final int width;
  const VideoResolution(this.height, this.width);
}

class YouTubeVideoInfo {
  final String title, uploader, thumbnailUrl;
  final int durationSeconds;
  const YouTubeVideoInfo({
    required this.title,
    required this.uploader,
    required this.durationSeconds,
    required this.thumbnailUrl,
  });
  String get durationFormatted {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class YouTubeService {
  final bool _useBinary = !Platform.isAndroid && !Platform.isIOS;

  Process? _activeProcess;
  bool _cancelled = false;
  yt_explode.YoutubeExplode? _ytExplode;

  String get _bin => BinaryManager.instance.ytDlpPath;

  void resetCancelFlag() {
    _cancelled = false;
  }

  Future<bool> isAvailable() async {
    if (!_useBinary) return true;
    try {
      final r = await Process.run(_bin, ['--version']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<YouTubeVideoInfo?> getVideoInfo(String url) async {
    if (_useBinary) {
      return _getVideoInfoBinary(url);
    } else {
      return _getVideoInfoExplode(url);
    }
  }

  Future<String?> downloadVideo({
    required String url,
    required YouTubeQuality quality,
    required String outputDirectory,
    void Function(String, int)? onProgress,
    void Function(String)? onLog,
  }) async {
    if (_useBinary) {
      return _downloadBinary(
        url: url,
        quality: quality,
        outputDirectory: outputDirectory,
        onProgress: onProgress,
        onLog: onLog,
      );
    } else {
      return _downloadExplode(
        url: url,
        quality: quality,
        outputDirectory: outputDirectory,
        onProgress: onProgress,
        onLog: onLog,
      );
    }
  }

  // yt-dlp binary (desktop)
  Future<YouTubeVideoInfo?> _getVideoInfoBinary(String url) async {
    try {
      final r = await Process.run(_bin, ['--dump-json', '--no-playlist', url]);
      if (r.exitCode != 0) return null;
      final j = jsonDecode(r.stdout as String) as Map<String, dynamic>;
      return YouTubeVideoInfo(
        title: j['title'] as String? ?? 'Unknown',
        uploader: j['uploader'] as String? ?? 'Unknown',
        durationSeconds: j['duration'] as int? ?? 0,
        thumbnailUrl: j['thumbnail'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _downloadBinary({
    required String url,
    required YouTubeQuality quality,
    required String outputDirectory,
    void Function(String, int)? onProgress,
    void Function(String)? onLog,
  }) async {
    _cancelled = false;

    final tmpl = '$outputDirectory${Platform.pathSeparator}%(title)s.%(ext)s';
    final args = [
      '-f',
      _qualityToFormatCode(quality),
      '--merge-output-format',
      'mp4',
      '--no-playlist',
      '--newline',
      '--print',
      'after_move:filepath',
      '-o',
      tmpl,
      url,
    ];

    try {
      _activeProcess = await Process.start(_bin, args);
      String? finalPath;
      String? mergerPath;

      _activeProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (_cancelled) return;
            onLog?.call(line);
            if (!line.startsWith('[') && line.trim().isNotEmpty) {
              finalPath = line.trim();
            }
            final mergerMatch = RegExp(
              r'\[Merger\] Merging formats into "(.+)"',
            ).firstMatch(line);
            if (mergerMatch != null) {
              mergerPath = mergerMatch.group(1)!.trim();
              onProgress?.call('Merging audio & video...', 95);
            }
            final pctMatch = RegExp(
              r'\[download\]\s+([\d.]+)%',
            ).firstMatch(line);
            if (pctMatch != null) {
              final pct = double.tryParse(pctMatch.group(1)!) ?? 0;
              onProgress?.call(
                'Downloading: ${pct.toStringAsFixed(1)}%',
                pct.toInt(),
              );
            }
          });

      _activeProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((l) => onLog?.call('[ERROR] $l'));

      final code = await _activeProcess!.exitCode;
      _activeProcess = null;

      if (_cancelled) return null;

      final resolved = finalPath ?? mergerPath;
      if (code == 0 && resolved != null) {
        onProgress?.call('Download complete', 100);
        return resolved;
      }
      return null;
    } on ProcessException catch (e) {
      _activeProcess = null;
      onLog?.call('[ERROR] yt-dlp error: ${e.message}');
      return null;
    }
  }

  String _qualityToFormatCode(YouTubeQuality q) {
    return switch (q) {
      YouTubeQuality.p1080 =>
        'bestvideo[height<=1080]+bestaudio/best[height<=1080]',
      YouTubeQuality.p720 =>
        'bestvideo[height<=720]+bestaudio/best[height<=720]',
      YouTubeQuality.p480 =>
        'bestvideo[height<=480]+bestaudio/best[height<=480]',
      YouTubeQuality.p360 =>
        'bestvideo[height<=360]+bestaudio/best[height<=360]',
      YouTubeQuality.audioOnly => 'bestaudio/best',
      _ => 'bestvideo+bestaudio/best',
    };
  }

  // youtube_explode_dart (Android)
  Future<YouTubeVideoInfo?> _getVideoInfoExplode(String url) async {
    try {
      _ytExplode ??= yt_explode.YoutubeExplode();
      final video = await _ytExplode!.videos.get(url);
      return YouTubeVideoInfo(
        title: video.title,
        uploader: video.author,
        durationSeconds: video.duration?.inSeconds ?? 0,
        thumbnailUrl: video.thumbnails.highResUrl,
      );
    } catch (e) {
      return null;
    }
  }

  Future<String?> _downloadExplode({
    required String url,
    required YouTubeQuality quality,
    required String outputDirectory,
    void Function(String, int)? onProgress,
    void Function(String)? onLog,
  }) async {
    _cancelled = false;
    try {
      _ytExplode ??= yt_explode.YoutubeExplode();

      onLog?.call('Fetching video info...');
      final video = await _ytExplode!.videos.get(url);
      final manifest = await _ytExplode!.videos.streamsClient.getManifest(url);

      onLog?.call('Selecting stream for quality: ${quality.label}');

      yt_explode.StreamInfo streamInfo;
      String ext;

      if (quality == YouTubeQuality.audioOnly) {
        streamInfo = manifest.audioOnly.withHighestBitrate();
        ext = 'webm';
      } else {
        final muxed = manifest.muxed;
        if (muxed.isEmpty) {
          onLog?.call('[ERR] No muxed streams available');
          return null;
        }

        yt_explode.MuxedStreamInfo? selected;
        if (quality.resolution != null) {
          final targetHeight = quality.resolution!.height;
          selected = muxed
              .where((s) => s.videoResolution.height <= targetHeight)
              .fold<yt_explode.MuxedStreamInfo?>(
                null,
                (best, s) =>
                    best == null ||
                        s.videoResolution.height > best.videoResolution.height
                    ? s
                    : best,
              );
        }
        selected ??= muxed.withHighestBitrate();
        streamInfo = selected;
        ext = selected.container.name;
      }

      // Sanitize filename
      final safeTitle = video.title
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final String downloadDir;
      if (Platform.isAndroid || Platform.isIOS) {
        final cacheDir = await getTemporaryDirectory();
        downloadDir = cacheDir.path;
        onLog?.call('Using cache dir: $downloadDir');
      } else {
        downloadDir = outputDirectory;
      }

      final outputPath = p.join(downloadDir, '$safeTitle.$ext');
      final outputFile = File(outputPath);

      onLog?.call('Downloading to: $outputPath');
      onProgress?.call('Starting download...', 0);

      final stream = _ytExplode!.videos.streamsClient.get(streamInfo);
      final sink = outputFile.openWrite();

      final totalBytes = streamInfo.size.totalBytes;
      var receivedBytes = 0;

      await for (final chunk in stream) {
        if (_cancelled) {
          await sink.close();
          try {
            await outputFile.delete();
          } catch (_) {}
          onLog?.call('[Cancelled]');
          return null;
        }
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final pct = ((receivedBytes / totalBytes) * 100).toInt().clamp(0, 99);
          onProgress?.call(
            'Downloading: ${(receivedBytes / 1024 / 1024).toStringAsFixed(1)}MB'
            ' / ${(totalBytes / 1024 / 1024).toStringAsFixed(1)}MB',
            pct,
          );
        }
      }

      await sink.flush();
      await sink.close();

      onProgress?.call('Download complete', 100);
      onLog?.call('Saved to: $outputPath');
      return outputPath;
    } catch (e) {
      onLog?.call('[ERR] Download failed: $e');
      return null;
    }
  }

  // Cancel
  Future<void> cancelDownload() async {
    _cancelled = true;
    _activeProcess?.kill(ProcessSignal.sigterm);
    if (Platform.isWindows) _activeProcess?.kill();
    _activeProcess = null;
  }

  void dispose() {
    cancelDownload();
    _ytExplode?.close();
    _ytExplode = null;
  }
}
