// lib/core/constants/api_constants.dart
import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  // Base URL - يتم تحديدها تلقائياً حسب البيئة
  static String get baseUrl {
    // Web - يعمل على localhost
    if (kIsWeb) {
      return 'http://localhost:5000';
    }
    
    // Mobile - كشف البيئة
    if (Platform.isAndroid) {
      // Android Emulator
      return 'http://10.0.2.2:5000';
    } else if (Platform.isIOS) {
      // iOS Emulator
      return 'http://localhost:5000';
    }
    
    // Real Device (استخدمي IP جهازك)
    return 'http://192.168.1.100:5000';
  }
  
  // أو استخدمي متغير بيئة
  static const String devUrl = 'http://localhost:5000';
  static const String prodUrl = 'https://your-production-url.com';
  
  // Auth Endpoints
  static const String signup = '/api/auth/signup';
  static const String verifySignup = '/api/auth/verify-signup';
  static const String resendOtp = '/api/auth/resend-otp';
  static const String login = '/api/auth/login';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';
  static const String verifyOtp = '/api/auth/verify-otp';
  static const String logout = '/api/auth/logout';
  static const String profile = '/api/auth/profile';
  static const String updateProfile = '/api/auth/profile';
  
  // Headers
  static const String contentType = 'application/json';
  static const String authorization = 'Authorization';
  static const String bearer = 'Bearer';
}