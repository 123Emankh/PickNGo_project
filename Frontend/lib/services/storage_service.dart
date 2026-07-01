// lib/services/storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../core/constants/app_constants.dart';
import '../data/models/user_model.dart';

class StorageService {
  late SharedPreferences _prefs;

  // ✅ Constructor مع async initialization
  StorageService() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ✅ جميع الدوال تصبح Future مع التأكد من التهيئة
  Future<void> _ensureInitialized() async {
    try {
      // محاولة الوصول إلى _prefs، إذا لم تكن مهيأة ستظهر خطأ
      _prefs.getString('test');
    } catch (e) {
      // إذا لم تكن مهيأة، قم بتهيئتها
      await _init();
    }
  }

  Future<void> saveToken(String token) async {
    await _ensureInitialized();
    await _prefs.setString(AppConstants.tokenKey, token);
  }

  Future<String?> getToken() async {
    await _ensureInitialized();
    return _prefs.getString(AppConstants.tokenKey);
  }

  Future<void> saveTempToken(String tempToken) async {
    await _ensureInitialized();
    await _prefs.setString(AppConstants.tempTokenKey, tempToken);
  }

  Future<String?> getTempToken() async {
    await _ensureInitialized();
    return _prefs.getString(AppConstants.tempTokenKey);
  }

  Future<void> saveUser(UserModel user) async {
    await _ensureInitialized();
    await _prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
  }

  Future<UserModel?> getUser() async {
    await _ensureInitialized();
    final userJson = _prefs.getString(AppConstants.userKey);
    if (userJson != null) {
      return UserModel.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  Future<void> clearAll() async {
    await _ensureInitialized();
    await _prefs.remove(AppConstants.tokenKey);
    await _prefs.remove(AppConstants.tempTokenKey);
    await _prefs.remove(AppConstants.userKey);
  }

  Future<void> clearTempToken() async {
    await _ensureInitialized();
    await _prefs.remove(AppConstants.tempTokenKey);
  }

  Future<bool> isLoggedIn() async {
    await _ensureInitialized();
    final token = _prefs.getString(AppConstants.tokenKey);
    return token != null && token.isNotEmpty;
  }
}