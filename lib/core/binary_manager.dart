import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

const bool _kFlatpak = bool.fromEnvironment('FLATPAK');

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

  bool get isInitialized => _ytDlpPath != null || Platform.isAndroid;

  Future<void> initialize({bool isPortable = false}) async {
    if (Platform.isAndroid) return;
    _initDesktop(isPortable: isPortable);
  }

  void _initDesktop({bool isPortable = false}) {
    if (_kFlatpak) {
      _ffmpegPath = 'ffmpeg';
      _ytDlpPath = 'yt-dlp';
      return;
    }

    final String binDir;
    if (kDebugMode) {
      final platform = _platformFolder();
      binDir = p.join(Directory.current.path, 'assets', 'binaries', platform);
    } else {
      binDir = p.join(File(Platform.resolvedExecutable).parent.path, 'bin');
    }

    _ffmpegPath = p.join(binDir, _exeName('ffmpeg'));
    _ytDlpPath = p.join(binDir, _exeName('yt-dlp'));
  }

  Future<({bool ffmpeg, bool ytDlp})> selfTest() async {
    if (Platform.isAndroid) return (ffmpeg: true, ytDlp: true);

    final ffm = await _check(_ffmpegPath!, ['-version']);
    final yt = await _check(_ytDlpPath!, ['--version']);

    return (ffmpeg: ffm, ytDlp: yt);
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
    throw UnsupportedError('Unsupported: ${Platform.operatingSystem}');
  }

  String _exeName(String base) => Platform.isWindows ? '$base.exe' : base;
}
