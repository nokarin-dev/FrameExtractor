import 'dart:convert';
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
    if (list.length > AppConstants.maxRecentVideos) {
      list.removeLast();
    }
    await _prefs.setString(AppConstants.prefRecentVideos, jsonEncode(list));
  }

  static Future<void> clearRecentVideos() =>
      _prefs.remove(AppConstants.prefRecentVideos);
}
