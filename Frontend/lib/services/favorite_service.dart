// lib/services/favorite_service.dart
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../data/models/store_model.dart';
import 'api_service.dart';

class FavoriteResult {
  final bool success;
  final String message;
  FavoriteResult({required this.success, this.message = ''});
}

class FavoriteService {
  final ApiService _apiService = ApiService();

  /// جلب قائمة المتاجر المفضلة لدى المستخدم الحالي
  Future<List<StoreModel>> listFavorites() async {
    try {
      final response = await _apiService.get(ApiConstants.favorites);
      final data = response.data;
      if (data['success'] == true && data['stores'] != null) {
        return (data['stores'] as List).map((s) => StoreModel.fromJson(s)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('listFavorites error: $e');
      return [];
    }
  }

  /// إضافة متجر للمفضلة (idempotent بالباك إند)
  Future<FavoriteResult> addFavorite(String storeId) async {
    try {
      final response = await _apiService.post(ApiConstants.favoriteToggle(storeId));
      final data = response.data;
      return FavoriteResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('addFavorite error: $e');
      return FavoriteResult(success: false, message: 'Network error while adding favorite');
    }
  }

  /// إزالة متجر من المفضلة
  Future<FavoriteResult> removeFavorite(String storeId) async {
    try {
      final response = await _apiService.delete(ApiConstants.favoriteToggle(storeId));
      final data = response.data;
      return FavoriteResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('removeFavorite error: $e');
      return FavoriteResult(success: false, message: 'Network error while removing favorite');
    }
  }

  /// إضافة منتج للمفضلة (idempotent بالباك إند)
  Future<FavoriteResult> addFavoriteProduct(String productId) async {
    try {
      final response = await _apiService.post(ApiConstants.favoriteProductToggle(productId));
      final data = response.data;
      return FavoriteResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('addFavoriteProduct error: $e');
      return FavoriteResult(success: false, message: 'Network error while adding favorite');
    }
  }

  /// إزالة منتج من المفضلة
  Future<FavoriteResult> removeFavoriteProduct(String productId) async {
    try {
      final response = await _apiService.delete(ApiConstants.favoriteProductToggle(productId));
      final data = response.data;
      return FavoriteResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('removeFavoriteProduct error: $e');
      return FavoriteResult(success: false, message: 'Network error while removing favorite');
    }
  }
}
