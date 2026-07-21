// lib/services/loyalty_service.dart
//
// يربط الفرونت مع /api/loyalty: رصيدي وسجل حركاتي، ومعاينة استبدال نقاط
// (بدون حسم فعلي) قبل تأكيد الطلب بالـ checkout.
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/api_error.dart';
import 'api_service.dart';

class LoyaltyTransactionModel {
  final String id;
  final String? orderId;
  final String type; // Earned | Redeemed | Reversed | Refunded
  final int points;
  final int balanceAfter;
  final String? description;
  final DateTime? createdAt;

  LoyaltyTransactionModel({
    required this.id,
    this.orderId,
    required this.type,
    required this.points,
    required this.balanceAfter,
    this.description,
    this.createdAt,
  });

  factory LoyaltyTransactionModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransactionModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString(),
      type: json['type'] ?? '',
      points: json['points'] ?? 0,
      balanceAfter: json['balance_after'] ?? 0,
      description: json['description'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

class LoyaltySummaryResult {
  final bool success;
  final String message;
  final int balance;
  final List<LoyaltyTransactionModel> transactions;
  final int total;

  LoyaltySummaryResult({
    required this.success,
    this.message = '',
    this.balance = 0,
    this.transactions = const [],
    this.total = 0,
  });
}

class PointsRedemptionPreview {
  final bool success;
  final String message;
  final int pointsRedeemed;
  final double discountAmount;
  final int balance;

  PointsRedemptionPreview({
    required this.success,
    this.message = '',
    this.pointsRedeemed = 0,
    this.discountAmount = 0,
    this.balance = 0,
  });
}

class LoyaltyService {
  final ApiService _apiService = ApiService();

  Future<LoyaltySummaryResult> getMyLoyalty({int page = 1, int limit = 20}) async {
    try {
      final response = await _apiService.get(ApiConstants.myLoyalty(page: page, limit: limit));
      final data = response.data;
      if (data['success'] == true) {
        return LoyaltySummaryResult(
          success: true,
          balance: data['balance'] ?? 0,
          transactions: (data['transactions'] as List? ?? [])
              .map((t) => LoyaltyTransactionModel.fromJson(t))
              .toList(),
          total: data['total'] ?? 0,
        );
      }
      return LoyaltySummaryResult(success: false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('getMyLoyalty error: $e');
      return LoyaltySummaryResult(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'Network error while fetching loyalty points'),
      );
    }
  }

  Future<PointsRedemptionPreview> previewRedemption({required int points, required double cartTotal}) async {
    try {
      final response = await _apiService.post(
        ApiConstants.previewPointsRedemption,
        data: {'points': points, 'cart_total': cartTotal},
      );
      final data = response.data;
      if (data['success'] == true) {
        return PointsRedemptionPreview(
          success: true,
          pointsRedeemed: data['points_redeemed'] ?? 0,
          discountAmount: (data['discount_amount'] ?? 0).toDouble(),
          balance: data['balance'] ?? 0,
        );
      }
      return PointsRedemptionPreview(success: false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('previewRedemption error: $e');
      return PointsRedemptionPreview(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'Network error while previewing points redemption'),
      );
    }
  }
}
