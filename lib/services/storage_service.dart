import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exam_app/models/app_settings.dart';
import 'package:exam_app/models/exam_result.dart';

/// خدمة التخزين المحلي للإعدادات ونتائج الامتحانات
class StorageService {
  static SharedPreferences? _prefs;

  static const String _keySettings = 'app_settings';
  static const String _keyResults = 'exam_results';

  /// تهيئة الخدمة
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// تحميل الإعدادات
  static AppSettings loadSettings() {
    final jsonStr = _prefs?.getString(_keySettings);
    if (jsonStr != null) {
      try {
        return AppSettings.fromJson(json.decode(jsonStr));
      } catch (_) {}
    }
    return AppSettings();
  }

  /// حفظ الإعدادات
  static Future<bool> saveSettings(AppSettings settings) async {
    return await _prefs?.setString(
      _keySettings,
      json.encode(settings.toJson()),
    ) ?? false;
  }

  /// تحميل جميع النتائج
  static List<ExamResult> loadResults() {
    final jsonStr = _prefs?.getString(_keyResults);
    if (jsonStr != null) {
      try {
        final List<dynamic> list = json.decode(jsonStr);
        return list.map((e) => ExamResult.fromJson(e)).toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      } catch (_) {}
    }
    return <ExamResult>[];
  }

  /// إضافة نتيجة جديدة
  static Future<bool> saveResult(ExamResult result) async {
    final results = loadResults();
    results.add(result);
    // الاحتفاظ بآخر 100 نتيجة فقط
    if (results.length > 100) results.removeRange(100, results.length);
    return await _prefs?.setString(
      _keyResults,
      json.encode(results.map((e) => e.toJson()).toList()),
    ) ?? false;
  }

  /// مسح جميع النتائج
  static Future<bool> clearResults() async {
    return await _prefs?.remove(_keyResults) ?? false;
  }
}
