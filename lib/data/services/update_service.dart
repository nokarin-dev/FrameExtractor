import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:frameextractor/core/app_constants.dart';

class UpdateResult {
  final bool available;
  final String? latestVersion;
  final String releaseUrl;

  const UpdateResult({
    required this.available,
    this.latestVersion,
    required this.releaseUrl,
  });
}

class UpdateService {
  static const _owner = 'nokarin-dev';
  static const _repo = 'frameextractor';
  static UpdateResult? cachedResult;
  static const _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';
  static const _releaseUrl =
      'https://github.com/$_owner/$_repo/releases/latest';

  static final ValueNotifier<UpdateResult?> resultNotifier = ValueNotifier(
    null,
  );

  static void checkInBackground() {
    check().then((result) {
      cachedResult = result;
      resultNotifier.value = result;
    });
  }

  static Future<UpdateResult?> check() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      final req = await client.getUrl(Uri.parse(_apiUrl));
      req.headers
        ..set('User-Agent', 'FrameExtractor/${AppConstants.appVersion}')
        ..set('Accept', 'application/vnd.github+json');

      final res = await req.close();
      client.close(force: false);

      if (res.statusCode != 200) return null;

      final body = await res.transform(const Utf8Decoder()).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final tag = (json['tag_name'] as String? ?? '')
          .replaceAll('v', '')
          .trim();
      if (tag.isEmpty) return null;

      final available = _isNewer(tag, AppConstants.appVersion);
      return UpdateResult(
        available: available,
        latestVersion: tag,
        releaseUrl: _releaseUrl,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isNewer(String latest, String current) {
    int parse(String v, int i) {
      final parts = v.split('.');
      if (i >= parts.length) return 0;
      return int.tryParse(parts[i].split('-').first) ?? 0;
    }

    for (var i = 0; i < 3; i++) {
      final l = parse(latest, i);
      final c = parse(current, i);
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }
}
