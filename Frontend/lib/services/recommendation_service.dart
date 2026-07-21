// lib/services/recommendation_service.dart
//
// محرك التوصية (Recommendation Engine) - قائم على قواعد/إحصاء بالباك إند
// (الطلبات السابقة/المفضلة/الفئات/القرب)، مش Machine Learning. الخدمة هون
// بس بتنادي الـ API وبترجع نماذج جاهزة للعرض.
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../data/models/recommendation_model.dart';
import 'api_service.dart';

class RecommendationService {
  final ApiService _apiService = ApiService();

  /// متاجر موصى بها للمستخدم الحالي - lat/lng اختياريين لتفعيل عامل "القرب"
  Future<List<RecommendedStore>> getRecommendedStores({double? lat, double? lng, int limit = 10}) async {
    try {
      final response = await _apiService.get(
        ApiConstants.recommendedStores,
        queryParameters: {
          'lat': ?lat,
          'lng': ?lng,
          'limit': limit,
        },
      );
      final data = response.data;
      if (data['success'] == true) {
        return (data['stores'] as List).map((s) => RecommendedStore.fromJson(s)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getRecommendedStores error: $e');
      return [];
    }
  }

  /// منتجات موصى بها للمستخدم الحالي
  Future<List<RecommendedProduct>> getRecommendedProducts({int limit = 10}) async {
    try {
      final response = await _apiService.get(
        ApiConstants.recommendedProducts,
        queryParameters: {'limit': limit},
      );
      final data = response.data;
      if (data['success'] == true) {
        return (data['products'] as List).map((p) => RecommendedProduct.fromJson(p)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getRecommendedProducts error: $e');
      return [];
    }
  }
}
