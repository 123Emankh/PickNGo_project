// lib/services/storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../core/constants/app_constants.dart';
import '../data/models/user_model.dart';

class StorageService {
  late SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

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

  // التوكن (JWT) والتوكن المؤقت حساسان - بيتخزنوا بـ flutter_secure_storage
  // (مشفّرين على الجهاز) بدل SharedPreferences العادي.
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: AppConstants.tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _secureStorage.read(key: AppConstants.tokenKey);
  }

  Future<void> saveTempToken(String tempToken) async {
    await _secureStorage.write(key: AppConstants.tempTokenKey, value: tempToken);
  }

  Future<String?> getTempToken() async {
    return _secureStorage.read(key: AppConstants.tempTokenKey);
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
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.tempTokenKey);
    await _prefs.remove(AppConstants.userKey);
  }

  Future<void> clearTempToken() async {
    await _secureStorage.delete(key: AppConstants.tempTokenKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await _secureStorage.read(key: AppConstants.tokenKey);
    return token != null && token.isNotEmpty;
  }
}
