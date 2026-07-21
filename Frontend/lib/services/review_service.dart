// lib/services/review_service.dart
//
// يربط الفرونت مع /api/reviews و /api/stores/:id/reviews: تقييم طلب تم
// توصيله، تعديل/حذف تقييمي، وجلب تقييمات متجر معيّن.
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/api_error.dart';
import 'api_service.dart';

class ReviewModel {
  final String id;
  final String orderId;
  final int rating;
  final String? comment;
  final String? customerName;
  final DateTime? createdAt;

  ReviewModel({
    required this.id,
    required this.orderId,
    required this.rating,
    this.comment,
    this.customerName,
    this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      rating: json['rating'] ?? 0,
      comment: json['comment'],
      customerName: json['customer_name'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

class ReviewResult {
  final bool success;
  final String message;
  final ReviewModel? review;

  ReviewResult({required this.success, this.message = '', this.review});
}

class ReviewListResult {
  final bool success;
  final String message;
  final List<ReviewModel> reviews;
  final int total;

  ReviewListResult({required this.success, this.message = '', this.reviews = const [], this.total = 0});
}

class ReviewService {
  final ApiService _apiService = ApiService();

  Future<ReviewResult> createReview({
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.reviews,
        data: {'order_id': orderId, 'rating': rating, 'comment': comment},
      );
      final data = response.data;
      return ReviewResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        review: data['review'] != null ? ReviewModel.fromJson(data['review']) : null,
      );
    } catch (e) {
      if (kDebugMode) print('createReview error: $e');
      return ReviewResult(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'Network error while creating review'),
      );
    }
  }

  Future<ReviewResult> updateReview({
    required String reviewId,
    int? rating,
    String? comment,
  }) async {
    try {
      final response = await _apiService.put(
        ApiConstants.reviewById(reviewId),
        data: {'rating': rating, 'comment': comment},
      );
      final data = response.data;
      return ReviewResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        review: data['review'] != null ? ReviewModel.fromJson(data['review']) : null,
      );
    } catch (e) {
      if (kDebugMode) print('updateReview error: $e');
      return ReviewResult(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'Network error while updating review'),
      );
    }
  }

  Future<ReviewResult> deleteReview(String reviewId) async {
    try {
      final response = await _apiService.delete(ApiConstants.reviewById(reviewId));
      final data = response.data;
      return ReviewResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('deleteReview error: $e');
      return ReviewResult(success: false, message: 'Network error while deleting review');
    }
  }

  Future<ReviewResult> getReviewForOrder(String orderId) async {
    try {
      final response = await _apiService.get(ApiConstants.reviewForOrder(orderId));
      final data = response.data;
      return ReviewResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        review: data['review'] != null ? ReviewModel.fromJson(data['review']) : null,
      );
    } catch (e) {
      if (kDebugMode) print('getReviewForOrder error: $e');
      return ReviewResult(success: false, message: 'Network error while fetching review');
    }
  }

  /// تقييمات المستخدم الحالي لعدة طلبات دفعة وحدة (نداء واحد) - بدل ما
  /// تنادي getReviewForOrder لكل طلب لحاله بحلقة (كان N نداء متسلسل لعميل
  /// عنده N طلب مسلّم).
  Future<Map<String, ReviewModel?>> getMyReviewsForOrders(List<String> orderIds) async {
    if (orderIds.isEmpty) return {};
    try {
      final response = await _apiService.get(ApiConstants.myReviewsForOrders(orderIds));
      final data = response.data;
      final result = <String, ReviewModel?>{};
      if (data['success'] == true && data['reviews'] is Map) {
        (data['reviews'] as Map).forEach((orderId, reviewJson) {
          result[orderId.toString()] = ReviewModel.fromJson(reviewJson as Map<String, dynamic>);
        });
      }
      return result;
    } catch (e) {
      if (kDebugMode) print('getMyReviewsForOrders error: $e');
      return {};
    }
  }

  Future<ReviewListResult> getStoreReviews(String storeId) async {
    try {
      final response = await _apiService.get(ApiConstants.storeReviews(storeId));
      final data = response.data;
      if (data['success'] == true && data['reviews'] != null) {
        return ReviewListResult(
          success: true,
          reviews: (data['reviews'] as List).map((r) => ReviewModel.fromJson(r)).toList(),
          total: data['total'] ?? 0,
        );
      }
      return ReviewListResult(success: true, reviews: []);
    } catch (e) {
      if (kDebugMode) print('getStoreReviews error: $e');
      return ReviewListResult(success: false, message: 'Network error while fetching store reviews');
    }
  }

  /// تقييمات منتج معيّن (تُحسب من مشتريات فعلية - راجع reviewController
  /// syncProductReviews بالباك إند) - تغذّي قسم "التقييمات" بصفحة تفاصيل المنتج.
  Future<ReviewListResult> getProductReviews(String productId) async {
    try {
      final response = await _apiService.get(ApiConstants.productReviews(productId));
      final data = response.data;
      if (data['success'] == true && data['reviews'] != null) {
        return ReviewListResult(
          success: true,
          reviews: (data['reviews'] as List).map((r) => ReviewModel.fromJson(r)).toList(),
          total: data['total'] ?? 0,
        );
      }
      return ReviewListResult(success: true, reviews: []);
    } catch (e) {
      if (kDebugMode) print('getProductReviews error: $e');
      return ReviewListResult(success: false, message: 'Network error while fetching product reviews');
    }
  }
}
