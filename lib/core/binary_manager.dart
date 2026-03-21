import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class BinaryManager {
  BinaryManager._();
  static final BinaryManager instance = BinaryManager._();

  String? _ffmpegPath;
  String? _ytDlpPath;

  String? get ffmpegPath => _ffmpegPath;

  String get ytDlpPath {
    assert(_ytDlpPath != null, 'Call initialize() first');
    return _ytDlpPath!;
  }

  bool get isInitialized =>
      _ytDlpPath != null || Platform.isAndroid || Platform.isIOS;

  Future<void> initialize({bool isPortable = false}) async {
    if (Platform.isAndroid || Platform.isIOS) return;
    _initDesktop();
  }

  void _initDesktop() {
    if (kDebugMode) {
      final platform = _platformFolder();
      final assetBinDir = p.join(
        Directory.current.path,
        'assets',
        'binaries',
        platform,
      );
      _ffmpegPath = p.join(assetBinDir, _exeName('ffmpeg'));
      _ytDlpPath = p.join(assetBinDir, _exeName('yt-dlp'));
    } else {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final binDir = p.join(exeDir, 'bin');
      _ffmpegPath = p.join(binDir, _exeName('ffmpeg'));
      _ytDlpPath = p.join(binDir, _exeName('yt-dlp'));
    }
  }

  Future<({bool ffmpeg, bool ytDlp})> selfTest() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return (ffmpeg: true, ytDlp: true);
    }
    final ff = await _check(_ffmpegPath!, ['-version']);
    final yt = await _check(_ytDlpPath!, ['--version']);
    return (ffmpeg: ff, ytDlp: yt);
  }

  Future<bool> _check(String bin, List<String> args) async {
    try {
      final r = await Process.run(
        bin,
        args,
      ).timeout(const Duration(seconds: 10));
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  String _platformFolder() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    throw UnsupportedError('Unsupported: ${Platform.operatingSystem}');
  }

  String _exeName(String base) => Platform.isWindows ? '$base.exe' : base;
}
