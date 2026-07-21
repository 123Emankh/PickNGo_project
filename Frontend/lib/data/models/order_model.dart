// lib/data/models/order_model.dart
//
// يمثل الطلب زي ما بيرجعه الباك إند من formatOrder() بـ orderController.js

class OrderItemModel {
  final String productId;
  final String name;
  final String? imageUrl;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  OrderItemModel({
    required this.productId,
    required this.name,
    this.imageUrl,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      productId: json['product_id']?.toString() ?? '',
      name: json['name'] ?? '',
      imageUrl: json['image_url'],
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
    );
  }
}

class OrderStatusEntry {
  final String status;
  final DateTime? at;

  OrderStatusEntry({required this.status, this.at});

  factory OrderStatusEntry.fromJson(Map<String, dynamic> json) {
    return OrderStatusEntry(
      status: json['status'] ?? '',
      at: json['at'] != null ? DateTime.tryParse(json['at'].toString()) : null,
    );
  }
}

// ✅ Grouped Delivery: متجر واحد ضمن رحلة توصيل مجمّعة - راجع formatOrder
// بـ orderController.js (group_stores)
class GroupStoreModel {
  final String orderId;
  final String orderStatus;
  final String? restaurantId;
  final String? name;
  final String? address;
  final int pickupSequence;
  final double? deliveryFee;

  GroupStoreModel({
    required this.orderId,
    required this.orderStatus,
    this.restaurantId,
    this.name,
    this.address,
    required this.pickupSequence,
    this.deliveryFee,
  });

  factory GroupStoreModel.fromJson(Map<String, dynamic> json) {
    return GroupStoreModel(
      orderId: json['order_id']?.toString() ?? '',
      orderStatus: json['order_status'] ?? '',
      restaurantId: json['restaurant_id']?.toString(),
      name: json['name'],
      address: json['address'],
      pickupSequence: json['pickup_sequence'] ?? 0,
      deliveryFee: json['delivery_fee'] != null ? (json['delivery_fee'] as num).toDouble() : null,
    );
  }
}

// ✅ Grouped Delivery: تفصيل رحلة توصيل مجمّعة كاملة - رد GET /api/orders/groups/:id
class DeliveryGroupDetailModel {
  final String groupId;
  final String status;
  final String? driverId;
  final String? deliveryAddress;
  final List<GroupStoreModel> stores;

  DeliveryGroupDetailModel({
    required this.groupId,
    required this.status,
    this.driverId,
    this.deliveryAddress,
    this.stores = const [],
  });

  factory DeliveryGroupDetailModel.fromJson(Map<String, dynamic> json) {
    return DeliveryGroupDetailModel(
      groupId: json['group_id']?.toString() ?? '',
      status: json['status'] ?? '',
      driverId: json['driver_id']?.toString(),
      deliveryAddress: json['delivery_address'],
      stores: json['stores'] != null
          ? (json['stores'] as List).map((s) => GroupStoreModel.fromJson(s)).toList()
          : [],
    );
  }
}

// ✅ Grouped Delivery (#8) - محطة رحلة توصيل مجمّعة بإحداثياتها، ترجع فقط
// برد GET /:id/tracking (group_stops) - عكس GroupStoreModel/group_stores
// (بدون إحداثيات، ترجع بردود تانية زي getMyOrders). تستخدمها شاشة السائق
// النشطة (active_delivery_screen.dart) لرسم المسار الكامل على الخريطة.
class OrderTrackingGroupStop {
  final String orderId;
  final String? storeName;
  final double lat;
  final double lng;
  final int pickupSequence;
  final String status;

  OrderTrackingGroupStop({
    required this.orderId,
    this.storeName,
    required this.lat,
    required this.lng,
    required this.pickupSequence,
    required this.status,
  });

  factory OrderTrackingGroupStop.fromJson(Map<String, dynamic> json) {
    return OrderTrackingGroupStop(
      orderId: json['order_id']?.toString() ?? '',
      storeName: json['store_name'],
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
      pickupSequence: json['pickup_sequence'] ?? 0,
      status: json['status'] ?? '',
    );
  }
}

class OrderEtaModel {
  final int preparingMin;
  final int pickupMin;
  final int deliveryMin;
  final int totalRemainingMin;
  final DateTime? estimatedDeliveryAt;
  // ✅ شفافية التقدير الذكي (etaService بالباك إند): هل اعتمد على متوسط حقيقي
  // من طلبات سابقة لنفس المتجر، وكم طلب نشط حاليًا على نفس السائق (سبب أي تأخير إضافي)
  final bool basedOnHistory;
  final int historySampleSize;
  final int driverActiveLoad;

  OrderEtaModel({
    required this.preparingMin,
    required this.pickupMin,
    required this.deliveryMin,
    required this.totalRemainingMin,
    this.estimatedDeliveryAt,
    this.basedOnHistory = false,
    this.historySampleSize = 0,
    this.driverActiveLoad = 0,
  });

  factory OrderEtaModel.fromJson(Map<String, dynamic> json) {
    final durations = json['stage_durations_min'] as Map<String, dynamic>? ?? {};
    return OrderEtaModel(
      preparingMin: durations['preparing'] ?? 0,
      pickupMin: durations['pickup'] ?? 0,
      deliveryMin: durations['delivery'] ?? 0,
      totalRemainingMin: json['total_remaining_min'] ?? 0,
      estimatedDeliveryAt: json['estimated_delivery_at'] != null
          ? DateTime.tryParse(json['estimated_delivery_at'].toString())
          : null,
      basedOnHistory: json['based_on_history'] ?? false,
      historySampleSize: json['history_sample_size'] ?? 0,
      driverActiveLoad: json['driver_active_load'] ?? 0,
    );
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String status; // Pending | Confirmed | Preparing | Ready | PickedUp | Delivered | Cancelled | Refunded
  final double totalAmount;
  final double deliveryFee;
  final double discount;
  final double finalAmount;
  final String deliveryAddress;
  final String? specialInstructions;
  final String paymentMethod; // Cash | CreditCard | DebitCard | Wallet
  final String paymentStatus; // Pending | Paid | Failed | Refunded
  final DateTime? orderTime;
  final String? storeId;
  final String? storeName;
  final String? storeImage;
  final String? storeAddress;
  final String? storeCity;
  final String? driverId;
  final List<OrderItemModel> items;

  // الحقول التالية موجودة فقط برد GET /:id/tracking (مش برد GET /my القائمة)
  final double? storeLat;
  final double? storeLng;
  final double? deliveryLat;
  final double? deliveryLng;
  final double? driverCurrentLat;
  final double? driverCurrentLng;
  final DateTime? driverLocationUpdatedAt;
  final String? driverName;
  final String? driverPhone;
  final String? driverPhoto;
  final String? driverVehicleType;
  final String? driverCompanyName;
  final List<OrderStatusEntry> statusHistory;
  final OrderEtaModel? eta;

  // ✅ Grouped Delivery (Smart Order Clustering) - null/فاضية للأغلبية
  // (طلب فردي عادي)، معبّاة فقط لو الطلب جزء من رحلة توصيل مجمّعة
  final String? deliveryGroupId;
  final String? groupStatus;
  final List<GroupStoreModel>? groupStores;
  // ✅ محطات الرحلة بإحداثياتها (#8) - null إلا برد GET /:id/tracking لطلب مجمّع
  final List<OrderTrackingGroupStop>? groupStops;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    required this.deliveryFee,
    this.discount = 0,
    required this.finalAmount,
    required this.deliveryAddress,
    this.specialInstructions,
    required this.paymentMethod,
    required this.paymentStatus,
    this.orderTime,
    this.storeId,
    this.storeName,
    this.storeImage,
    this.storeAddress,
    this.storeCity,
    this.driverId,
    this.items = const [],
    this.storeLat,
    this.storeLng,
    this.deliveryLat,
    this.deliveryLng,
    this.driverCurrentLat,
    this.driverCurrentLng,
    this.driverLocationUpdatedAt,
    this.driverName,
    this.driverPhone,
    this.driverPhoto,
    this.driverVehicleType,
    this.driverCompanyName,
    this.statusHistory = const [],
    this.eta,
    this.deliveryGroupId,
    this.groupStatus,
    this.groupStores,
    this.groupStops,
  });

  bool get isGrouped => deliveryGroupId != null;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? 'Pending',
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      deliveryFee: (json['delivery_fee'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      finalAmount: (json['final_amount'] ?? 0).toDouble(),
      deliveryAddress: json['delivery_address'] ?? '',
      specialInstructions: json['special_instructions'],
      paymentMethod: json['payment_method'] ?? 'Cash',
      paymentStatus: json['payment_status'] ?? 'Pending',
      orderTime: json['order_time'] != null
          ? DateTime.tryParse(json['order_time'].toString())
          : null,
      storeId: json['store_id']?.toString(),
      storeName: json['store_name'],
      storeImage: json['store_image'],
      storeAddress: json['store_address'],
      storeCity: json['store_city'],
      driverId: json['driver_id']?.toString(),
      items: json['items'] != null
          ? (json['items'] as List)
              .map((i) => OrderItemModel.fromJson(i))
              .toList()
          : [],
      storeLat: json['store_lat'] != null ? (json['store_lat'] as num).toDouble() : null,
      storeLng: json['store_lng'] != null ? (json['store_lng'] as num).toDouble() : null,
      deliveryLat: json['delivery_lat'] != null ? (json['delivery_lat'] as num).toDouble() : null,
      deliveryLng: json['delivery_lng'] != null ? (json['delivery_lng'] as num).toDouble() : null,
      driverCurrentLat: json['driver_current_lat'] != null
          ? (json['driver_current_lat'] as num).toDouble()
          : null,
      driverCurrentLng: json['driver_current_lng'] != null
          ? (json['driver_current_lng'] as num).toDouble()
          : null,
      driverLocationUpdatedAt: json['driver_location_updated_at'] != null
          ? DateTime.tryParse(json['driver_location_updated_at'].toString())
          : null,
      driverName: json['driver_name'],
      driverPhone: json['driver_phone'],
      driverPhoto: json['driver_photo'],
      driverVehicleType: json['driver_vehicle_type'],
      driverCompanyName: json['driver_company_name'],
      statusHistory: json['status_history'] != null
          ? (json['status_history'] as List)
              .map((e) => OrderStatusEntry.fromJson(e))
              .toList()
          : [],
      eta: json['eta'] != null ? OrderEtaModel.fromJson(json['eta']) : null,
      deliveryGroupId: json['delivery_group_id']?.toString(),
      groupStatus: json['group_status'],
      groupStores: json['group_stores'] != null
          ? (json['group_stores'] as List)
              .map((s) => GroupStoreModel.fromJson(s))
              .toList()
          : null,
      groupStops: json['group_stops'] != null
          ? (json['group_stops'] as List)
              .map((s) => OrderTrackingGroupStop.fromJson(s))
              .toList()
          : null,
    );
  }
}
