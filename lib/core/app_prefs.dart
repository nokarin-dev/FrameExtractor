import 'dart:convert';
import 'package:frameextractor/data/models/extraction_present.dart';
import 'package:frameextractor/data/models/extraction_record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frameextractor/core/app_constants.dart';

class AppPrefs {
  AppPrefs._();
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Theme mode
  static String get themeMode =>
      _prefs.getString(AppConstants.prefThemeMode) ?? 'dark';
  static Future<void> setThemeMode(String v) =>
      _prefs.setString(AppConstants.prefThemeMode, v);

  // UI style
  static String get uiStyle =>
      _prefs.getString(AppConstants.prefUIStyle) ?? 'classic';
  static Future<void> setUIStyle(String v) =>
      _prefs.setString(AppConstants.prefUIStyle, v);

  // Last used output directory
  static String? get lastOutputDir =>
      _prefs.getString(AppConstants.prefLastOutput);
  static Future<void> setLastOutputDir(String v) =>
      _prefs.setString(AppConstants.prefLastOutput, v);

  // Recent video files
  static List<String> get recentVideos {
    final raw = _prefs.getString(AppConstants.prefRecentVideos);
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  static Future<void> addRecentVideo(String path) async {
    final list = recentVideos.where((p) => p != path).toList();
    list.insert(0, path);
    if (list.length > AppConstants.maxRecentVideos) list.removeLast();
    await _prefs.setString(AppConstants.prefRecentVideos, jsonEncode(list));
  }

  static Future<void> clearRecentVideos() =>
      _prefs.remove(AppConstants.prefRecentVideos);

  // Extraction settings
  static int get lastFps =>
      _prefs.getInt(AppConstants.prefLastFps) ?? AppConstants.defaultFps;
  static Future<void> setLastFps(int v) =>
      _prefs.setInt(AppConstants.prefLastFps, v);

  static String get lastFormat =>
      _prefs.getString(AppConstants.prefLastFormat) ??
      AppConstants.defaultFormat;
  static Future<void> setLastFormat(String v) =>
      _prefs.setString(AppConstants.prefLastFormat, v);

  static int get lastQuality =>
      _prefs.getInt(AppConstants.prefLastQuality) ??
      AppConstants.defaultQuality;
  static Future<void> setLastQuality(int v) =>
      _prefs.setInt(AppConstants.prefLastQuality, v);

  static double get lastScale =>
      _prefs.getDouble(AppConstants.prefLastScale) ?? AppConstants.defaultScale;
  static Future<void> setLastScale(double v) =>
      _prefs.setDouble(AppConstants.prefLastScale, v);

  static String get lastStartTime =>
      _prefs.getString(AppConstants.prefLastStartTime) ??
      AppConstants.defaultStart;
  static Future<void> setLastStartTime(String v) =>
      _prefs.setString(AppConstants.prefLastStartTime, v);

  static String get lastEndTime =>
      _prefs.getString(AppConstants.prefLastEndTime) ?? AppConstants.defaultEnd;
  static Future<void> setLastEndTime(String v) =>
      _prefs.setString(AppConstants.prefLastEndTime, v);

  static String get lastPrefix =>
      _prefs.getString(AppConstants.prefLastPrefix) ??
      AppConstants.defaultPrefix;
  static Future<void> setLastPrefix(String v) =>
      _prefs.setString(AppConstants.prefLastPrefix, v);

  static bool get openFolderOnDone =>
      _prefs.getBool(AppConstants.prefOpenFolderOnDone) ?? true;
  static Future<void> setOpenFolderOnDone(bool v) =>
      _prefs.setBool(AppConstants.prefOpenFolderOnDone, v);

  // Presets
  static List<ExtractionPreset> get customPresets {
    final raw = _prefs.getString(AppConstants.prefPresets);
    if (raw == null || raw.isEmpty) return [];
    return ExtractionPreset.listFromJson(raw);
  }

  static List<ExtractionPreset> get allPresets => [
    ...ExtractionPreset.defaults,
    ...customPresets,
  ];

  static Future<void> savePreset(ExtractionPreset preset) async {
    final list = customPresets.where((p) => p.id != preset.id).toList();
    list.insert(0, preset);
    if (list.length > AppConstants.maxCustomPresets) list.removeLast();
    await _prefs.setString(
      AppConstants.prefPresets,
      ExtractionPreset.listToJson(list),
    );
  }

  static Future<void> deletePreset(String id) async {
    final list = customPresets.where((p) => p.id != id).toList();
    await _prefs.setString(
      AppConstants.prefPresets,
      ExtractionPreset.listToJson(list),
    );
  }

  static Future<void> clearCustomPresets() =>
      _prefs.remove(AppConstants.prefPresets);

  // Extraction history
  static List<ExtractionRecord> get history {
    final raw = _prefs.getString(AppConstants.prefHistory);
    if (raw == null || raw.isEmpty) return [];
    return ExtractionRecord.listFromJson(raw);
  }

  static Future<void> addHistoryRecord(ExtractionRecord record) async {
    final list = history.where((r) => r.id != record.id).toList();
    list.insert(0, record);
    if (list.length > AppConstants.maxHistoryRecords) list.removeLast();
    await _prefs.setString(
      AppConstants.prefHistory,
      ExtractionRecord.listToJson(list),
    );
  }

  static Future<void> clearHistory() => _prefs.remove(AppConstants.prefHistory);
}
