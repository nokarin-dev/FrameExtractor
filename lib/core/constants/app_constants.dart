class AppConstants {
  // App Info
  static const String appName = 'Frame Extractor';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Effortless video frame extraction';

  // Default Values
  static const int defaultFps = 30;
  static const int minFps = 1;
  static const int maxFps = 120;

  static const int defaultQuality = 95;
  static const int minQuality = 1;
  static const int maxQuality = 100;

  static const double defaultScale = 1.0;
  static const double minScale = 0.25;
  static const double maxScale = 2.0;

  static const String defaultStartTime = '00:00:00';
  static const String defaultEndTime = '00:00:05';
  static const String defaultFramePrefix = 'frame_';
  static const String defaultFormat = 'png';

  // Supported Formats
  static const List<String> supportedFormats = [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'bmp',
  ];

  // Supported Video Extensions
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

  // Time Format
  static const String timeFormat = 'HH:mm:ss';

  // Processing Speed Estimates (frames per second)
  static const double desktopProcessingSpeed = 150.0;
  static const double mobileProcessingSpeed = 50.0;

  // UI
  static const double cardPadding = 16.0;
  static const double sectionSpacing = 16.0;
  static const double buttonHeight = 48.0;

  // Storage
  static const String defaultOutputFolderName = 'FrameExtractor_Output';
}
