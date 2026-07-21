// lib/core/utils/api_error.dart
//
// Dio بيرمي DioException على أي رد مش 2xx افتراضيًا - بدون هاد الاستخراج،
// أي رسالة خطأ محددة يرجعها الباك إند (زي "You can only review a delivered
// order" أو "This coupon is not valid for this store") بتضيع والمستخدم
// بشوف بس رسالة عامة. نفس المنطق يلي auth_service.dart كان عامله لحاله.
import 'package:dio/dio.dart';

String extractApiErrorMessage(dynamic error, {String fallback = 'Network error. Please try again.'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String && (data['message'] as String).isNotEmpty) {
      return data['message'] as String;
    }
  }
  return fallback;
}
