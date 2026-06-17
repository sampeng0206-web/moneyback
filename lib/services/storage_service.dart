import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/case_model.dart';

class StorageService {
  static const String _caseKey = 'moneyback_case';

  // Save Case to SharedPreferences
  static Future<void> saveCase(CaseModel caseModel) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(caseModel.toJson());
    await prefs.setString(_caseKey, jsonStr);
  }

  // Load Case from SharedPreferences
  static Future<CaseModel> loadCase() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_caseKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return CaseModel(); // Return empty default case
    }
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
      return CaseModel.fromJson(jsonMap);
    } catch (e) {
      // If parsing fails, return a fresh case
      return CaseModel();
    }
  }

  // Generic helpers
  static Future<void> setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  static Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  static Future<void> setInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  static Future<int> getInt(String key, {int defaultValue = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? defaultValue;
  }

  static Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String> getString(String key, {String defaultValue = ""}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? defaultValue;
  }

  // Clear all data
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
