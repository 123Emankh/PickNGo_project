// lib/services/payment_service.dart
//
// يربط الفرونت مع /api/payments: إنشاء جلسة دفع HyperPay لطلب موجود،
// والتحقق من نتيجة الدفع الفعلية بعد ما العميل يخلّص من صفحة الويدجت.
// ⚠️ هاد الملف ما بيقرر أبدًا إنه الدفع نجح - بس بينقل رد الباك إند كما هو.
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/api_error.dart';
import 'api_service.dart';

class CheckoutSessionResult {
  final bool success;
  final String message;
  final String? checkoutId;
  final String? widgetUrl;

  CheckoutSessionResult({
    required this.success,
    this.message = '',
    this.checkoutId,
    this.widgetUrl,
  });
}

class PaymentStatusResult {
  final bool success;
  final String message;
  final String? paymentStatus; // Pending | Paid | Failed | Refunded

  PaymentStatusResult({
    required this.success,
    this.message = '',
    this.paymentStatus,
  });
}

class PaymentService {
  final ApiService _apiService = ApiService();

  /// ينشئ جلسة دفع HyperPay لطلب موجود (لازم يكون payment_method بطاقة و payment_status Pending)
  Future<CheckoutSessionResult> createCheckoutSession({required String orderId}) async {
    try {
      final response = await _apiService.post(
        ApiConstants.paymentCheckout,
        data: {'order_id': orderId},
      );
      final data = response.data;
      return CheckoutSessionResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        checkoutId: data['checkoutId'],
        widgetUrl: data['widgetUrl'],
      );
    } catch (e) {
      if (kDebugMode) print('createCheckoutSession error: $e');
      return CheckoutSessionResult(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'Network error while starting card payment'),
      );
    }
  }

  /// يتحقق من نتيجة الدفع الفعلية من الباك إند (اللي بدوره يتحقق من HyperPay) - مصدر الحقيقة الوحيد
  Future<PaymentStatusResult> verifyPaymentStatus({required String orderId}) async {
    try {
      final response = await _apiService.get(ApiConstants.paymentStatus(orderId));
      final data = response.data;
      return PaymentStatusResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        paymentStatus: data['payment_status'],
      );
    } catch (e) {
      if (kDebugMode) print('verifyPaymentStatus error: $e');
      return PaymentStatusResult(
        success: false,
        message: 'Network error while verifying payment status',
      );
    }
  }
}
