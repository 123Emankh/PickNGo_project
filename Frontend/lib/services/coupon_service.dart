// lib/services/coupon_service.dart
//
// يربط الفرونت مع /api/coupons و /api/admin/coupons: معاينة كود خصم قبل
// الدفع، إنشاء/تعديل كوبونات (صاحب متجر لمتجره، أو أدمن لكوبون عام)،
// وقائمة كوبونات المتجر أو كل المنصة (للأدمن).
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/api_error.dart';
import 'api_service.dart';

class CouponModel {
  final String id;
  final String? restaurantId; // null = كوبون عام على كل المنصة
  final String? storeName; // موجود بس برد قائمة الأدمن
  final String code;
  final String discountType; // Percentage | Fixed
  final double discountValue;
  final double minOrderAmount;
  final double? maxDiscountAmount;
  final int? usageLimit;
  final int usageLimitPerCustomer;
  final int usedCount;
  final bool isActive;
  final DateTime? validFrom;
  final DateTime? validUntil;

  CouponModel({
    required this.id,
    this.restaurantId,
    this.storeName,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    this.maxDiscountAmount,
    this.usageLimit,
    required this.usageLimitPerCustomer,
    required this.usedCount,
    required this.isActive,
    this.validFrom,
    this.validUntil,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id']?.toString() ?? '',
      restaurantId: json['restaurant_id']?.toString(),
      storeName: json['store_name'],
      code: json['code'] ?? '',
      discountType: json['discount_type'] ?? 'Fixed',
      discountValue: (json['discount_value'] ?? 0).toDouble(),
      minOrderAmount: (json['min_order_amount'] ?? 0).toDouble(),
      maxDiscountAmount: json['max_discount_amount'] != null ? (json['max_discount_amount'] as num).toDouble() : null,
      usageLimit: json['usage_limit'],
      usageLimitPerCustomer: json['usage_limit_per_customer'] ?? 1,
      usedCount: json['used_count'] ?? 0,
      isActive: json['is_active'] ?? true,
      validFrom: json['valid_from'] != null ? DateTime.tryParse(json['valid_from'].toString()) : null,
      validUntil: json['valid_until'] != null ? DateTime.tryParse(json['valid_until'].toString()) : null,
    );
  }
}

class CouponValidateResult {
  final bool success;
  final String message;
  final double discountAmount;

  CouponValidateResult({required this.success, this.message = '', this.discountAmount = 0});
}

class CouponResult {
  final bool success;
  final String message;
  final CouponModel? coupon;

  CouponResult({required this.success, this.message = '', this.coupon});
}

class CouponListResult {
  final bool success;
  final String message;
  final List<CouponModel> coupons;

  CouponListResult({required this.success, this.message = '', this.coupons = const []});
}

class CouponService {
  final ApiService _apiService = ApiService();

  Future<CouponValidateResult> validateCoupon({
    required String code,
    required String restaurantId,
    required double cartTotal,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.couponValidate,
        data: {'code': code, 'restaurant_id': restaurantId, 'cart_total': cartTotal},
      );
      final data = response.data;
      return CouponValidateResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        discountAmount: (data['discount_amount'] ?? 0).toDouble(),
      );
    } catch (e) {
      if (kDebugMode) print('validateCoupon error: $e');
      return CouponValidateResult(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'Network error while validating coupon'),
      );
    }
  }

  /// كوبونات فعّالة حاليًا للعرض بشاشة "كوبونات خصم" (اختصار الصفحة الرئيسية) - عامة
  Future<CouponListResult> getActiveCoupons() async {
    try {
      final response = await _apiService.get(ApiConstants.activeCoupons);
      final data = response.data;
      if (data['success'] == true && data['coupons'] != null) {
        return CouponListResult(
          success: true,
          coupons: (data['coupons'] as List).map((c) => CouponModel.fromJson(c)).toList(),
        );
      }
      return CouponListResult(success: true, coupons: []);
    } catch (e) {
      if (kDebugMode) print('getActiveCoupons error: $e');
      return CouponListResult(success: false, message: 'Network error while fetching coupons');
    }
  }

  Future<CouponResult> createCoupon(Map<String, dynamic> fields) async {
    try {
      final response = await _apiService.post(ApiConstants.coupons, data: fields);
      final data = response.data;
      return CouponResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        coupon: data['coupon'] != null ? CouponModel.fromJson(data['coupon']) : null,
      );
    } catch (e) {
      if (kDebugMode) print('createCoupon error: $e');
      return CouponResult(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'Network error while creating coupon'),
      );
    }
  }

  Future<CouponListResult> getMyCoupons() async {
    try {
      final response = await _apiService.get(ApiConstants.myCoupons);
      final data = response.data;
      if (data['success'] == true && data['coupons'] != null) {
        return CouponListResult(
          success: true,
          coupons: (data['coupons'] as List).map((c) => CouponModel.fromJson(c)).toList(),
        );
      }
      return CouponListResult(success: true, coupons: []);
    } catch (e) {
      if (kDebugMode) print('getMyCoupons error: $e');
      return CouponListResult(success: false, message: 'Network error while fetching coupons');
    }
  }

  Future<CouponResult> updateCoupon(String couponId, Map<String, dynamic> fields) async {
    try {
      final response = await _apiService.put(ApiConstants.couponById(couponId), data: fields);
      final data = response.data;
      return CouponResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        coupon: data['coupon'] != null ? CouponModel.fromJson(data['coupon']) : null,
      );
    } catch (e) {
      if (kDebugMode) print('updateCoupon error: $e');
      return CouponResult(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'Network error while updating coupon'),
      );
    }
  }

  Future<CouponListResult> getAllCouponsAdmin() async {
    try {
      final response = await _apiService.get(ApiConstants.adminCoupons);
      final data = response.data;
      if (data['success'] == true && data['coupons'] != null) {
        return CouponListResult(
          success: true,
          coupons: (data['coupons'] as List).map((c) => CouponModel.fromJson(c)).toList(),
        );
      }
      return CouponListResult(success: true, coupons: []);
    } catch (e) {
      if (kDebugMode) print('getAllCouponsAdmin error: $e');
      return CouponListResult(success: false, message: 'Network error while fetching coupons');
    }
  }
}
