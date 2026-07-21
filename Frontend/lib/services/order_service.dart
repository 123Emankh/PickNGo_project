// lib/services/order_service.dart
//
// بيربط الفرونت مع /api/orders بالباك إند: إنشاء طلب (checkout)،
// جلب طلباتي (Customer/Restaurant/Driver)، جلب الطلبات المتاحة للسائق،
// وتحديث حالة الطلب.

import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/api_error.dart';
import '../data/models/offer_model.dart';
import '../data/models/order_model.dart';
import 'api_service.dart';

class OrderResult {
  final bool success;
  final String message;
  final OrderModel? order;

  OrderResult({required this.success, required this.message, this.order});
}

class OrdersListResult {
  final bool success;
  final String message;
  final List<OrderModel> orders;

  OrdersListResult({
    required this.success,
    this.message = '',
    this.orders = const [],
  });
}

// ✅ Grouped Delivery (Smart Order Clustering)
class DeliveryGroupResult {
  final bool success;
  final String message;
  final DeliveryGroupDetailModel? group;

  DeliveryGroupResult({required this.success, this.message = '', this.group});
}

// ✅ Phase 3 - Smart Assignment
class PendingOfferResult {
  final bool success;
  final String message;
  final DeliveryOfferModel? offer; // null = ما في عرض معلّق حاليًا

  PendingOfferResult({required this.success, this.message = '', this.offer});
}

class OfferResponseResult {
  final bool success;
  final String message;
  final String? code; // NOT_OFFERED | EXPIRED | ALREADY_ASSIGNED ...

  OfferResponseResult({required this.success, this.message = '', this.code});
}

/// ✅ نداء موحّد لقبول/رفض عرض تعيين ذكي - فردي أو مجموعة (نفس المنطق كان
/// مكرر بين driver_home_screen و notifications_screen).
Future<OfferResponseResult> respondToDeliveryOffer(
  OrderService orderService,
  DeliveryOfferModel offer,
  String action,
) {
  return offer.isGroup
      ? orderService.respondToGroupOffer(groupId: offer.respondTargetId, action: action)
      : orderService.respondToOffer(orderId: offer.respondTargetId, action: action);
}

class OrderService {
  final ApiService _apiService = ApiService();

  /// إنشاء طلب جديد (Checkout) - كل طلب مربوط بمتجر واحد بس،
  /// فإذا السلة فيها أكتر من متجر لازم تنادي هاي الدالة مرة لكل متجر.
  Future<OrderResult> createOrder({
    required String storeId,
    required List<Map<String, dynamic>> items, // [{product_id, quantity}]
    required String deliveryAddress,
    // ✅ إلزامي - أساس حساب رسم التوصيل الصحيح بالباك إند (راجع
    // utils/deliveryFee.js)، مش الإحداثيات. deliveryCity من قائمة
    // palestineAreas الثابتة، deliveryRegion = 'West Bank' | 'Gaza Strip' | 'Israel'
    required String deliveryCity,
    required String deliveryRegion,
    double? deliveryLat,
    double? deliveryLng,
    required String paymentMethod, // Cash | CreditCard | DebitCard | Wallet
    String? specialInstructions,
    String? couponCode,
    int? redeemPoints,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.orders,
        data: {
          'restaurant_id': storeId,
          'items': items,
          'delivery_address': deliveryAddress,
          'delivery_city': deliveryCity,
          'delivery_region': deliveryRegion,
          'delivery_lat': deliveryLat,
          'delivery_lng': deliveryLng,
          'payment_method': paymentMethod,
          'special_instructions': specialInstructions,
          'coupon_code': couponCode,
          if (redeemPoints != null && redeemPoints > 0) 'redeem_points': redeemPoints,
        },
      );

      final data = response.data;
      return OrderResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        order: data['order'] != null ? OrderModel.fromJson(data['order']) : null,
      );
    } catch (e) {
      if (kDebugMode) print('createOrder error: $e');
      return OrderResult(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'Network error while placing your order'),
      );
    }
  }

  /// جلب طلبات المستخدم الحالي (بتختلف حسب الدور تلقائياً بالباك إند:
  /// Customer -> طلباته، Restaurant -> طلبات محله، Driver -> طلباته يلي وصّلها)
  Future<OrdersListResult> getMyOrders({DateTime? from, DateTime? to}) async {
    try {
      final query = <String, dynamic>{};
      if (from != null) query['from'] = from.toIso8601String().split('T').first;
      if (to != null) query['to'] = to.toIso8601String().split('T').first;
      final response = await _apiService.get(
        ApiConstants.myOrders,
        queryParameters: query.isEmpty ? null : query,
      );
      final data = response.data;
      if (data['success'] == true && data['orders'] != null) {
        return OrdersListResult(
          success: true,
          orders: (data['orders'] as List)
              .map((o) => OrderModel.fromJson(o))
              .toList(),
        );
      }
      return OrdersListResult(success: true, orders: []);
    } catch (e) {
      if (kDebugMode) print('getMyOrders error: $e');
      return OrdersListResult(
        success: false,
        message: 'Network error while fetching your orders',
      );
    }
  }

  /// جلب الطلبات الجاهزة يلي بتحتاج سائق (Ready + بدون سائق محدد)
  Future<OrdersListResult> getAvailableOrders() async {
    try {
      final response = await _apiService.get(ApiConstants.availableOrders);
      final data = response.data;
      if (data['success'] == true && data['orders'] != null) {
        return OrdersListResult(
          success: true,
          orders: (data['orders'] as List)
              .map((o) => OrderModel.fromJson(o))
              .toList(),
        );
      }
      return OrdersListResult(success: true, orders: []);
    } catch (e) {
      if (kDebugMode) print('getAvailableOrders error: $e');
      return OrdersListResult(
        success: false,
        message: 'Network error while fetching available orders',
      );
    }
  }

  /// جلب بيانات التتبّع اللحظي لطلب واحد (مواقع المتجر/الوجهة/السائق الحالية)
  Future<OrderResult> getOrderTracking(String orderId) async {
    try {
      final response = await _apiService.get(ApiConstants.orderTracking(orderId));
      final data = response.data;
      return OrderResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        order: data['order'] != null ? OrderModel.fromJson(data['order']) : null,
      );
    } catch (e) {
      if (kDebugMode) print('getOrderTracking error: $e');
      return OrderResult(
        success: false,
        message: 'Network error while fetching order tracking',
      );
    }
  }

  /// تحديث حالة الطلب (تستخدمها لوحة صاحب المتجر أو السائق)
  Future<OrderResult> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      final response = await _apiService.put(
        ApiConstants.orderStatus(orderId),
        data: {'status': status},
      );
      final data = response.data;
      return OrderResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        order: data['order'] != null ? OrderModel.fromJson(data['order']) : null,
      );
    } catch (e) {
      if (kDebugMode) print('updateOrderStatus error: $e');
      return OrderResult(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'Network error while updating order status'),
      );
    }
  }

  /// تفاصيل رحلة توصيل مجمّعة (المتاجر بترتيب الاستلام + حالة كل طلب)
  Future<DeliveryGroupResult> getDeliveryGroupDetail(String groupId) async {
    try {
      final response = await _apiService.get(ApiConstants.deliveryGroupDetail(groupId));
      final data = response.data;
      return DeliveryGroupResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        group: data['group'] != null ? DeliveryGroupDetailModel.fromJson(data['group']) : null,
      );
    } catch (e) {
      if (kDebugMode) print('getDeliveryGroupDetail error: $e');
      return DeliveryGroupResult(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'Network error while fetching delivery group'),
      );
    }
  }

  /// قبول رحلة توصيل مجمّعة كاملة (قائمة الطلبات المتاحة - نفس فلسفة "قبول
  /// الطلب" الفردي، بس لكل الرحلة سوا. ما بيغيّر حالة أي طلب - بس بيثبّت
  /// السائق عليها؛ حالة كل طلب تتغيّر لاحقًا مع كل استلام من متجره)
  Future<DeliveryGroupResult> acceptDeliveryGroup(String groupId) async {
    try {
      final response = await _apiService.post(ApiConstants.deliveryGroupAccept(groupId));
      final data = response.data;
      return DeliveryGroupResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        group: data['group'] != null ? DeliveryGroupDetailModel.fromJson(data['group']) : null,
      );
    } catch (e) {
      if (kDebugMode) print('acceptDeliveryGroup error: $e');
      return DeliveryGroupResult(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'Network error while accepting delivery group'),
      );
    }
  }

  /// العرض المعلّق حاليًا على السائق (Phase 3 - Smart Assignment)، إن وجد -
  /// fallback لحالة إنو تطبيق السائق كان مقفول لما وصل event السوكيت order:offer
  Future<PendingOfferResult> getMyPendingOffer() async {
    try {
      final response = await _apiService.get(ApiConstants.myPendingOffer);
      final data = response.data;
      return PendingOfferResult(
        success: data['success'] ?? false,
        offer: data['offer'] != null ? DeliveryOfferModel.fromJson(data['offer']) : null,
      );
    } catch (e) {
      if (kDebugMode) print('getMyPendingOffer error: $e');
      return PendingOfferResult(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'Network error while fetching pending offer'),
      );
    }
  }

  /// رد السائق على عرض تعيين ذكي فردي (accept|reject)
  Future<OfferResponseResult> respondToOffer({required String orderId, required String action}) async {
    try {
      final response = await _apiService.post(
        ApiConstants.respondToOffer(orderId),
        data: {'action': action},
      );
      final data = response.data;
      return OfferResponseResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        code: data['code'],
      );
    } catch (e) {
      if (kDebugMode) print('respondToOffer error: $e');
      return OfferResponseResult(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'Network error while responding to offer'),
      );
    }
  }

  /// رد السائق على عرض تعيين ذكي لمجموعة توصيل مجمّعة (accept|reject)
  Future<OfferResponseResult> respondToGroupOffer({required String groupId, required String action}) async {
    try {
      final response = await _apiService.post(
        ApiConstants.respondToGroupOffer(groupId),
        data: {'action': action},
      );
      final data = response.data;
      return OfferResponseResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        code: data['code'],
      );
    } catch (e) {
      if (kDebugMode) print('respondToGroupOffer error: $e');
      return OfferResponseResult(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'Network error while responding to group offer'),
      );
    }
  }
}
