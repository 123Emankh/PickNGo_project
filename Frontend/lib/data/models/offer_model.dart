// lib/data/models/offer_model.dart
//
// عرض تعيين ذكي (Phase 3 - Smart Assignment) معروض حاليًا على السائق -
// نفس الشكل بالضبط يجي من حدث السوكيت order:offer (بث لحظي) ومن
// GET /api/orders/offers/mine (fallback لو تطبيق السائق كان مقفول وقت البث).

class OfferStoreStop {
  final String? restaurantId;
  final String? name;
  final String? address;
  final int pickupSequence;

  OfferStoreStop({this.restaurantId, this.name, this.address, required this.pickupSequence});

  factory OfferStoreStop.fromJson(Map<String, dynamic> json) {
    return OfferStoreStop(
      restaurantId: json['restaurant_id']?.toString(),
      name: json['name'],
      address: json['address'],
      pickupSequence: json['pickup_sequence'] ?? 0,
    );
  }
}

class DeliveryOfferModel {
  final bool isGroup;
  final String? orderId; // فردي بس
  final String? orderNumber; // فردي بس
  final String? groupId; // مجمّع بس
  final int orderCount;
  final List<String> orderIds; // مجمّع بس
  final String? storeName; // فردي بس
  final String? storeAddress; // فردي بس
  final List<OfferStoreStop> stores; // مجمّع بس، مرتّبة بترتيب الاستلام
  final String deliveryAddress;
  final double? distanceKm;
  final double deliveryFee;
  final String? reasonLabel;
  final DateTime expiresAt;

  DeliveryOfferModel({
    required this.isGroup,
    this.orderId,
    this.orderNumber,
    this.groupId,
    this.orderCount = 1,
    this.orderIds = const [],
    this.storeName,
    this.storeAddress,
    this.stores = const [],
    required this.deliveryAddress,
    this.distanceKm,
    this.deliveryFee = 0,
    this.reasonLabel,
    required this.expiresAt,
  });

  /// المعرّف المستخدم لنداء respond (order_id للفردي، group_id للمجمّع)
  String get respondTargetId => isGroup ? (groupId ?? '') : (orderId ?? '');

  factory DeliveryOfferModel.fromJson(Map<String, dynamic> json) {
    final isGroup = json['is_group'] == true;
    return DeliveryOfferModel(
      isGroup: isGroup,
      orderId: json['order_id']?.toString(),
      orderNumber: json['order_number'],
      groupId: json['group_id']?.toString(),
      orderCount: json['order_count'] ?? 1,
      orderIds: json['order_ids'] != null
          ? (json['order_ids'] as List).map((e) => e.toString()).toList()
          : const [],
      storeName: json['store_name'],
      storeAddress: json['store_address'],
      stores: json['stores'] != null
          ? ((json['stores'] as List).map((s) => OfferStoreStop.fromJson(s)).toList()
            ..sort((a, b) => a.pickupSequence.compareTo(b.pickupSequence)))
          : const [],
      deliveryAddress: json['delivery_address'] ?? '',
      distanceKm: json['distance_km'] != null ? (json['distance_km'] as num).toDouble() : null,
      deliveryFee: json['delivery_fee'] != null ? (json['delivery_fee'] as num).toDouble() : 0,
      reasonLabel: json['reason_label'],
      expiresAt: json['expires_at'] != null
          ? (DateTime.tryParse(json['expires_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
