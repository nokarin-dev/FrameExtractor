import 'dart:io';

import 'package:frameextractor/data/services/ffmpeg/ffmpeg_service_base.dart';
import 'package:frameextractor/data/services/ffmpeg/ffmpeg_service_desktop.dart';
import 'package:frameextractor/data/services/ffmpeg/ffmpeg_service_mobile.dart';

FFmpegService createFFmpegService() {
  if (Platform.isAndroid) {
    return FFmpegServiceMobile();
  }
  return FFmpegServiceDesktop();
}
