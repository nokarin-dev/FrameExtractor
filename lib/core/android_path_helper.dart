import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AndroidPathHelper {
  static const _channel = MethodChannel('com.nokarin.frameextractor/native');

  static Future<String> resolveOutputDirectory(String uriOrPath) async {
    if (!Platform.isAndroid) return uriOrPath;
    if (uriOrPath.startsWith('/')) return uriOrPath;

    if (uriOrPath.startsWith('content://')) {
      try {
        final realPath = await _channel.invokeMethod<String>('getPathFromUri', {
          'uri': uriOrPath,
        });
        if (realPath != null && realPath.isNotEmpty) {
          await Directory(realPath).create(recursive: true);
          return realPath;
        }
      } catch (_) {}

      return getWritableOutputDir();
    }

    return uriOrPath;
  }

  static Future<String> resolveVideoPath(String uriOrPath) async {
    if (!Platform.isAndroid) return uriOrPath;
    if (uriOrPath.startsWith('/')) return uriOrPath;

    if (uriOrPath.startsWith('content://')) {
      try {
        final realPath = await _channel.invokeMethod<String>('getPathFromUri', {
          'uri': uriOrPath,
        });
        if (realPath != null && realPath.isNotEmpty) return realPath;
      } catch (_) {}
    }

    return uriOrPath;
  }

  static Future<String> getWritableOutputDir() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Only needed on Android');
    }
    try {
      final path = await _channel.invokeMethod<String>('getExternalFilesDir', {
        'type': null,
      });
      if (path != null) {
        await Directory(path).create(recursive: true);
        return path;
      }
    } catch (_) {}

    final dir = await getApplicationDocumentsDirectory();
    final frames = Directory('${dir.path}/frames');
    await frames.create(recursive: true);
    return frames.path;
  }

  static Future<int> copyFramesToUri({
    required String tempOutputDir,
    required String targetUri,
    String? subfolder,
  }) async {
    if (!Platform.isAndroid) return -1;
    try {
      final count = await _channel.invokeMethod<int>('copyFramesToUri', {
        'sourceDir': tempOutputDir,
        'targetUri': targetUri,
        'subfolder': subfolder,
      });
      return count ?? -1;
    } catch (e) {
      return -1;
    }
  }

  static bool isSafUri(String path) => path.startsWith('content://');
}
