class AppConstants {
  // App info
  static const String appName = 'Frame Extractor';
  static const String appVersion = '1.1.2';
  static const String appDescription = 'Effortless video frame extraction';

  // Extraction defaults
  static const int defaultFps = 30;
  static const int minFps = 1;
  static const int maxFps = 60;
  static const int defaultQuality = 90;
  static const int minQuality = 1;
  static const int maxQuality = 100;
  static const double defaultScale = 1.0;
  static const double minScale = 0.25;
  static const double maxScale = 2.0;
  static const String defaultStart = '00:00:00';
  static const String defaultEnd = '00:00:05';
  static const String defaultPrefix = 'frame_';
  static const String defaultFormat = 'jpg';

  // Supported formats and video file types
  static const List<String> supportedFormats = ['png', 'jpg', 'webp', 'bmp'];
  static const List<String> supportedVideoExtensions = [
    'mp4',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    'm4v',
    'mpg',
    'mpeg',
  ];

  // Preferences
  static const String prefThemeMode = 'theme_mode';
  static const String prefUIStyle = 'ui_style';
  static const String prefLastOutput = 'last_output_dir';
  static const String prefRecentVideos = 'recent_videos';
  static const int maxRecentVideos = 8;

  // Processing speed estimates
  static const double desktopSpeed = 150.0;
  static const double mobileSpeed = 50.0;
}
