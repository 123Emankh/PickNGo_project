// lib/data/models/admin_models.dart
//
// موديلات خفيفة خاصة بلوحة الأدمن فقط (مش مشتركة مع باقي التطبيق).

import 'order_model.dart' show OrderStatusEntry;

class AdminDashboardStats {
  final int totalUsers;
  final int totalStores;
  final int totalOrders;
  final double revenue;
  final List<AdminOrdersByStatus> ordersByStatus;
  final AdminDeliveryGroupStats deliveryGroups;

  AdminDashboardStats({
    required this.totalUsers,
    required this.totalStores,
    required this.totalOrders,
    required this.revenue,
    required this.ordersByStatus,
    required this.deliveryGroups,
  });

  factory AdminDashboardStats.empty() => AdminDashboardStats(
        totalUsers: 0,
        totalStores: 0,
        totalOrders: 0,
        revenue: 0,
        ordersByStatus: const [],
        deliveryGroups: AdminDeliveryGroupStats.empty(),
      );

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] ?? {};
    return AdminDashboardStats(
      totalUsers: stats['total_users'] ?? 0,
      totalStores: stats['total_stores'] ?? 0,
      totalOrders: stats['total_orders'] ?? 0,
      revenue: (stats['revenue'] ?? 0).toDouble(),
      ordersByStatus: (json['orders_by_status'] as List? ?? [])
          .map((o) => AdminOrdersByStatus.fromJson(o))
          .toList(),
      deliveryGroups: stats['delivery_groups'] != null
          ? AdminDeliveryGroupStats.fromJson(stats['delivery_groups'])
          : AdminDeliveryGroupStats.empty(),
    );
  }
}

// ✅ Grouped Delivery (Smart Order Clustering) - راجع groupingService.getGroupingStats بالباك إند
class AdminDeliveryGroupStats {
  final int totalGroups;
  final int ordersGrouped;
  final double avgOrdersPerGroup;
  final int tripsSaved;
  final int timeSavedMinEstimate;
  // ✅ توفير حقيقي تقديري (#7) - راجع groupingService.getGroupingStats
  final double fuelSavedKmEstimate;
  final double costSavedJdEstimate;
  final double co2SavedKgEstimate;
  // ✅ عدد الرحلات المجمّعة المنشأة اليوم - لقسم "Current Statistics" بصفحة
  // إعدادات Grouped Delivery
  final int groupsCreatedToday;

  AdminDeliveryGroupStats({
    required this.totalGroups,
    required this.ordersGrouped,
    required this.avgOrdersPerGroup,
    required this.tripsSaved,
    required this.timeSavedMinEstimate,
    this.fuelSavedKmEstimate = 0,
    this.costSavedJdEstimate = 0,
    this.co2SavedKgEstimate = 0,
    this.groupsCreatedToday = 0,
  });

  factory AdminDeliveryGroupStats.empty() => AdminDeliveryGroupStats(
        totalGroups: 0,
        ordersGrouped: 0,
        avgOrdersPerGroup: 0,
        tripsSaved: 0,
        timeSavedMinEstimate: 0,
      );

  factory AdminDeliveryGroupStats.fromJson(Map<String, dynamic> json) {
    return AdminDeliveryGroupStats(
      totalGroups: json['total_groups'] ?? 0,
      ordersGrouped: json['orders_grouped'] ?? 0,
      avgOrdersPerGroup: (json['avg_orders_per_group'] ?? 0).toDouble(),
      tripsSaved: json['trips_saved'] ?? 0,
      timeSavedMinEstimate: json['time_saved_min_estimate'] ?? 0,
      fuelSavedKmEstimate: (json['fuel_saved_km_estimate'] ?? 0).toDouble(),
      costSavedJdEstimate: (json['cost_saved_jd_estimate'] ?? 0).toDouble(),
      co2SavedKgEstimate: (json['co2_saved_kg_estimate'] ?? 0).toDouble(),
      groupsCreatedToday: json['groups_created_today'] ?? 0,
    );
  }
}

// ✅ سائق احتياطي (#5) - ثاني أفضل مرشح حي وقت الطلب (غير مخزّن)، راجع
// adminController.computeBackupDriver
class AdminBackupDriver {
  final String id;
  final String name;
  final double score;

  AdminBackupDriver({required this.id, required this.name, required this.score});

  factory AdminBackupDriver.fromJson(Map<String, dynamic> json) {
    return AdminBackupDriver(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      score: (json['score'] ?? 0).toDouble(),
    );
  }
}

// ✅ سجل زمني كامل لرحلة توصيل مجمّعة (#10) - راجع adminController.buildGroupTimeline
class AdminGroupTimelineEvent {
  final String type;
  final String label;
  final DateTime? at;
  final String? orderId;
  final String? storeName;

  AdminGroupTimelineEvent({required this.type, required this.label, this.at, this.orderId, this.storeName});

  factory AdminGroupTimelineEvent.fromJson(Map<String, dynamic> json) {
    return AdminGroupTimelineEvent(
      type: json['type'] ?? '',
      label: json['label'] ?? '',
      at: json['at'] != null ? DateTime.tryParse(json['at'].toString()) : null,
      orderId: json['order_id']?.toString(),
      storeName: json['store_name'],
    );
  }
}

List<AdminGroupTimelineEvent> _parseTimeline(dynamic json) {
  if (json == null) return [];
  return (json as List).map((e) => AdminGroupTimelineEvent.fromJson(e)).toList();
}

class AdminOrdersByStatus {
  final String status;
  final int count;

  AdminOrdersByStatus({required this.status, required this.count});

  factory AdminOrdersByStatus.fromJson(Map<String, dynamic> json) {
    return AdminOrdersByStatus(
      status: json['status'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

class AdminStoreModel {
  final String id;
  final String name;
  final String? category;
  final String address;
  final String imageUrl;
  final String approvalStatus;
  final bool isFeatured;

  AdminStoreModel({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.imageUrl,
    required this.approvalStatus,
    this.isFeatured = false,
  });

  factory AdminStoreModel.fromJson(Map<String, dynamic> json) {
    return AdminStoreModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      category: json['category'],
      address: json['address'] ?? '',
      imageUrl: json['image_url'] ?? '',
      approvalStatus: json['approval_status'] ?? 'Pending',
      isFeatured: json['is_featured'] ?? false,
    );
  }
}

class AdminCompanyModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? city;
  final String? region;
  final String status;

  AdminCompanyModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.city,
    this.region,
    required this.status,
  });

  factory AdminCompanyModel.fromJson(Map<String, dynamic> json) {
    return AdminCompanyModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone']?.toString(),
      city: json['city'],
      region: json['region'],
      status: json['status'] ?? 'Pending',
    );
  }
}

class AdminDriverModel {
  final String id;
  final String fullName;
  final String? phone;
  final String email;
  final String? vehicleType;
  final String accountStatus; // Pending/Approved/Rejected/Suspended
  final bool isActive;
  final String driverStatus; // Available/Busy/Offline (فعلي)
  final String? companyName;
  final int deliveredCount;
  final DateTime? createdAt;
  final double? rating; // null = ما في نظام تقييم سائقين مبني لسا بالمشروع

  AdminDriverModel({
    required this.id,
    required this.fullName,
    this.phone,
    required this.email,
    this.vehicleType,
    required this.accountStatus,
    required this.isActive,
    required this.driverStatus,
    this.companyName,
    required this.deliveredCount,
    this.createdAt,
    this.rating,
  });

  factory AdminDriverModel.fromJson(Map<String, dynamic> json) {
    return AdminDriverModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone']?.toString(),
      email: json['email'] ?? '',
      vehicleType: json['vehicle_type'],
      accountStatus: json['account_status'] ?? 'Pending',
      isActive: json['is_active'] ?? true,
      driverStatus: json['driver_status'] ?? 'Offline',
      companyName: json['company_name'],
      deliveredCount: json['delivered_count'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
    );
  }

  AdminDriverModel copyWith({String? driverStatus, String? accountStatus}) {
    return AdminDriverModel(
      id: id,
      fullName: fullName,
      phone: phone,
      email: email,
      vehicleType: vehicleType,
      accountStatus: accountStatus ?? this.accountStatus,
      isActive: isActive,
      driverStatus: driverStatus ?? this.driverStatus,
      companyName: companyName,
      deliveredCount: deliveredCount,
      createdAt: createdAt,
      rating: rating,
    );
  }
}

// ✅ Grouped Delivery (Smart Order Clustering) - قسم رحلات التوصيل المجمّعة بلوحة الأدمن
class AdminDeliveryGroupStop {
  final String orderId;
  final String orderStatus;
  final String? storeName;
  final int pickupSequence;
  // ✅ سبب التجميع (Grouping Reason) - null لأول عضو (anchor)، راجع
  // backend/src/services/groupingService.js
  final String? matchedWithOrderId;
  final double? storeDistanceKm;
  final double? deliveryDistanceKm;
  final int? timeDifferenceMinutes;
  final List<String>? rulesSatisfied;

  AdminDeliveryGroupStop({
    required this.orderId,
    required this.orderStatus,
    this.storeName,
    required this.pickupSequence,
    this.matchedWithOrderId,
    this.storeDistanceKm,
    this.deliveryDistanceKm,
    this.timeDifferenceMinutes,
    this.rulesSatisfied,
  });

  factory AdminDeliveryGroupStop.fromJson(Map<String, dynamic> json) {
    return AdminDeliveryGroupStop(
      orderId: json['order_id']?.toString() ?? '',
      orderStatus: json['order_status'] ?? '',
      storeName: json['store_name'],
      pickupSequence: json['pickup_sequence'] ?? 0,
      matchedWithOrderId: json['matched_with_order_id']?.toString(),
      storeDistanceKm: json['store_distance_km'] != null ? double.tryParse('${json['store_distance_km']}') : null,
      deliveryDistanceKm: json['delivery_distance_km'] != null ? double.tryParse('${json['delivery_distance_km']}') : null,
      timeDifferenceMinutes: json['time_difference_minutes'],
      rulesSatisfied: json['rules_satisfied'] != null ? List<String>.from(json['rules_satisfied']) : null,
    );
  }
}

class AdminDeliveryGroupModel {
  final String id;
  final String status; // Forming | Assigned | Completed | Cancelled
  final String? customerName;
  final String? driverName;
  final String? assignmentType;
  final Map<String, dynamic>? assignmentReason;
  final DateTime? createdAt;
  final DateTime? assignedAt;
  final List<AdminDeliveryGroupStop> stores;
  final AdminBackupDriver? backupDriver;
  final List<AdminGroupTimelineEvent> timeline;

  AdminDeliveryGroupModel({
    required this.id,
    required this.status,
    this.customerName,
    this.driverName,
    this.assignmentType,
    this.assignmentReason,
    this.createdAt,
    this.assignedAt,
    this.stores = const [],
    this.backupDriver,
    this.timeline = const [],
  });

  factory AdminDeliveryGroupModel.fromJson(Map<String, dynamic> json) {
    return AdminDeliveryGroupModel(
      id: json['id']?.toString() ?? '',
      status: json['status'] ?? 'Forming',
      customerName: json['customer_name'],
      driverName: json['driver_name'],
      assignmentType: json['assignment_type'],
      assignmentReason: json['assignment_reason'] != null ? Map<String, dynamic>.from(json['assignment_reason']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      assignedAt: json['assigned_at'] != null ? DateTime.tryParse(json['assigned_at'].toString()) : null,
      stores: json['stores'] != null
          ? (json['stores'] as List).map((e) => AdminDeliveryGroupStop.fromJson(e)).toList()
          : [],
      backupDriver: json['backup_driver'] != null ? AdminBackupDriver.fromJson(json['backup_driver']) : null,
      timeline: _parseTimeline(json['timeline']),
    );
  }
}

class AdminOrderModel {
  final String id;
  final String orderNumber;
  final String status;
  final double finalAmount;
  final String? storeName;
  final String? customerName;
  final String? driverName;
  final String? driverCompanyName;
  final DateTime? orderTime;
  final DateTime? updatedAt;
  final String? deliveryGroupId;
  final String? assignmentType; // Auto | Manual | null

  AdminOrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.finalAmount,
    this.storeName,
    this.customerName,
    this.driverName,
    this.driverCompanyName,
    this.orderTime,
    this.updatedAt,
    this.deliveryGroupId,
    this.assignmentType,
  });

  bool get isGrouped => deliveryGroupId != null;

  factory AdminOrderModel.fromJson(Map<String, dynamic> json) {
    return AdminOrderModel(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? 'Pending',
      finalAmount: (json['final_amount'] ?? 0).toDouble(),
      storeName: json['store_name'],
      customerName: json['customer_name'],
      driverName: json['driver_name'],
      driverCompanyName: json['driver_company_name'],
      orderTime: json['order_time'] != null
          ? DateTime.tryParse(json['order_time'].toString())
          : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      deliveryGroupId: json['delivery_group_id']?.toString(),
      assignmentType: json['assignment_type'],
    );
  }
}

// ✅ تفاصيل طلب كاملة (GET /api/admin/orders/:id) - العميل/المتجر/السائق/
// الشركة/العناصر/سجل الحالات/معلومات التعيين الذكي/رحلة التوصيل المجمّعة
class AdminOrderPartyInfo {
  final String? id;
  final String? name;
  final String? phone;
  final String? email;
  final String? address;
  final String? vehicleType;
  final String? companyName;

  AdminOrderPartyInfo({this.id, this.name, this.phone, this.email, this.address, this.vehicleType, this.companyName});

  factory AdminOrderPartyInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AdminOrderPartyInfo();
    return AdminOrderPartyInfo(
      id: json['id']?.toString(),
      name: json['full_name'] ?? json['name'],
      phone: json['phone']?.toString(),
      email: json['email'],
      address: json['address'],
      vehicleType: json['vehicle_type'],
      companyName: json['company_name'],
    );
  }
}

class AdminOrderItemModel {
  final String name;
  final int quantity;
  final double unitPrice;
  final String? variantLabel;
  final double subtotal;

  AdminOrderItemModel({required this.name, required this.quantity, required this.unitPrice, this.variantLabel, required this.subtotal});

  factory AdminOrderItemModel.fromJson(Map<String, dynamic> json) {
    return AdminOrderItemModel(
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      variantLabel: json['variant_label'],
      subtotal: (json['subtotal'] ?? 0).toDouble(),
    );
  }
}

class AdminOrderGroupStop {
  final String orderId;
  final String orderStatus;
  final String? storeName;
  final int pickupSequence;

  AdminOrderGroupStop({required this.orderId, required this.orderStatus, this.storeName, required this.pickupSequence});

  factory AdminOrderGroupStop.fromJson(Map<String, dynamic> json) {
    return AdminOrderGroupStop(
      orderId: json['order_id']?.toString() ?? '',
      orderStatus: json['order_status'] ?? '',
      storeName: json['store_name'],
      pickupSequence: json['pickup_sequence'] ?? 0,
    );
  }
}

class AdminOrderDetailModel {
  final String id;
  final String orderNumber;
  final String status;
  final double totalAmount;
  final double deliveryFee;
  final double discount;
  final double finalAmount;
  final String deliveryAddress;
  final String? specialInstructions;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime? orderTime;
  final DateTime? completedTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<OrderStatusEntry> statusHistory;
  final AdminOrderPartyInfo? store;
  final AdminOrderPartyInfo? customer;
  final AdminOrderPartyInfo? driver;
  final List<AdminOrderItemModel> items;
  final DateTime? assignedAt;
  final String? assignmentType;
  final Map<String, dynamic>? assignmentReason;
  final List<dynamic> offerHistory;
  final String? deliveryGroupId;
  final String? deliveryGroupStatus;
  final List<AdminOrderGroupStop> deliveryGroupStores;
  final List<AdminGroupTimelineEvent> deliveryGroupTimeline;
  final AdminBackupDriver? backupDriver;

  AdminOrderDetailModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    required this.deliveryFee,
    required this.discount,
    required this.finalAmount,
    required this.deliveryAddress,
    this.specialInstructions,
    required this.paymentMethod,
    required this.paymentStatus,
    this.orderTime,
    this.completedTime,
    this.createdAt,
    this.updatedAt,
    this.statusHistory = const [],
    this.store,
    this.customer,
    this.driver,
    this.items = const [],
    this.assignedAt,
    this.assignmentType,
    this.assignmentReason,
    this.offerHistory = const [],
    this.deliveryGroupId,
    this.deliveryGroupStatus,
    this.deliveryGroupStores = const [],
    this.deliveryGroupTimeline = const [],
    this.backupDriver,
  });

  bool get isGrouped => deliveryGroupId != null;

  factory AdminOrderDetailModel.fromJson(Map<String, dynamic> json) {
    final group = json['delivery_group'];
    return AdminOrderDetailModel(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? 'Pending',
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      deliveryFee: (json['delivery_fee'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      finalAmount: (json['final_amount'] ?? 0).toDouble(),
      deliveryAddress: json['delivery_address'] ?? '',
      specialInstructions: json['special_instructions'],
      paymentMethod: json['payment_method'] ?? '',
      paymentStatus: json['payment_status'] ?? '',
      orderTime: json['order_time'] != null ? DateTime.tryParse(json['order_time'].toString()) : null,
      completedTime: json['completed_time'] != null ? DateTime.tryParse(json['completed_time'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      statusHistory: json['status_history'] != null
          ? (json['status_history'] as List).map((e) => OrderStatusEntry.fromJson(e)).toList()
          : [],
      store: AdminOrderPartyInfo.fromJson(json['store']),
      customer: AdminOrderPartyInfo.fromJson(json['customer']),
      driver: AdminOrderPartyInfo.fromJson(json['driver']),
      items: json['items'] != null
          ? (json['items'] as List).map((e) => AdminOrderItemModel.fromJson(e)).toList()
          : [],
      assignedAt: json['assigned_at'] != null ? DateTime.tryParse(json['assigned_at'].toString()) : null,
      assignmentType: json['assignment_type'],
      assignmentReason: json['assignment_reason'] != null ? Map<String, dynamic>.from(json['assignment_reason']) : null,
      offerHistory: json['offer_history'] ?? [],
      deliveryGroupId: group != null ? group['group_id']?.toString() : null,
      deliveryGroupStatus: group != null ? group['status'] : null,
      deliveryGroupStores: group != null && group['stores'] != null
          ? (group['stores'] as List).map((e) => AdminOrderGroupStop.fromJson(e)).toList()
          : [],
      deliveryGroupTimeline: group != null ? _parseTimeline(group['timeline']) : [],
      backupDriver: json['backup_driver'] != null ? AdminBackupDriver.fromJson(json['backup_driver']) : null,
    );
  }
}

class AdminUserModel {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? businessType;
  final String? phone;
  final String status; // Pending | Approved | Rejected | Suspended
  final bool isActive;
  final String? city;
  final String? region;
  final DateTime? createdAt;
  final int loyaltyPoints;

  AdminUserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.businessType,
    this.phone,
    this.status = 'Approved',
    this.isActive = true,
    this.city,
    this.region,
    this.createdAt,
    this.loyaltyPoints = 0,
  });

  /// تصنيف مبسّط لتبويب "المستخدمين" بلوحة الأدمن - Customer/Driver/Restaurant
  /// (صاحب متجر)/Company (شركة توصيل)/Admin - نفس الأربع فئات المطلوبة
  /// بالمواصفة + Admin. مبني كليًا من role/businessType الموجودين أصلًا،
  /// بدون أي حقل جديد بالباك إند.
  String get category {
    if (role == 'Driver' && businessType == 'Fleet / Company') return 'Company';
    return role;
  }

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    return AdminUserModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      businessType: json['business_type'],
      phone: json['phone']?.toString(),
      status: json['status'] ?? 'Approved',
      isActive: json['is_active'] ?? true,
      city: json['city'],
      region: json['region'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      loyaltyPoints: json['loyalty_points'] ?? 0,
    );
  }

  AdminUserModel copyWith({String? status}) {
    return AdminUserModel(
      id: id, fullName: fullName, email: email, role: role, businessType: businessType,
      phone: phone, status: status ?? this.status, isActive: isActive, city: city,
      region: region, createdAt: createdAt, loyaltyPoints: loyaltyPoints,
    );
  }
}

class AdminCategoryModel {
  final String id;
  final String name;
  final String icon;
  final int storeCount;
  final int productCount;

  AdminCategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.storeCount,
    required this.productCount,
  });

  factory AdminCategoryModel.fromJson(Map<String, dynamic> json) {
    return AdminCategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? '',
      storeCount: json['store_count'] ?? 0,
      productCount: json['product_count'] ?? 0,
    );
  }
}

/// إعدادات Grouped Delivery (صف وحيد بالباك اند) - لوحة الأدمن (Delivery
/// Management → Grouped Delivery Settings) بتقرأ/تعدّل هاد الكائن بدل ما
/// تكون القواعد ثابتة بالكود.
class SystemSettingsModel {
  final bool groupedDeliveryEnabled;
  final double maxStoreDistance; // كم
  final double maxDeliveryDistance; // كم
  final int maxTimeBetweenOrders; // دقايق
  final int maxOrdersPerGroup;
  final int maxStoresPerTrip;
  final double minimumDriverRating; // محجوز للمستقبل - غير مفعّل بمنطق التعيين
  final bool autoAssignDriver;

  SystemSettingsModel({
    required this.groupedDeliveryEnabled,
    required this.maxStoreDistance,
    required this.maxDeliveryDistance,
    required this.maxTimeBetweenOrders,
    required this.maxOrdersPerGroup,
    required this.maxStoresPerTrip,
    required this.minimumDriverRating,
    required this.autoAssignDriver,
  });

  factory SystemSettingsModel.empty() => SystemSettingsModel(
        groupedDeliveryEnabled: true,
        maxStoreDistance: 0.1,
        maxDeliveryDistance: 0.1,
        maxTimeBetweenOrders: 10,
        maxOrdersPerGroup: 4,
        maxStoresPerTrip: 4,
        minimumDriverRating: 0,
        autoAssignDriver: true,
      );

  factory SystemSettingsModel.fromJson(Map<String, dynamic> json) {
    return SystemSettingsModel(
      groupedDeliveryEnabled: json['grouped_delivery_enabled'] ?? true,
      maxStoreDistance: double.tryParse('${json['max_store_distance']}') ?? 0.1,
      maxDeliveryDistance: double.tryParse('${json['max_delivery_distance']}') ?? 0.1,
      maxTimeBetweenOrders: json['max_time_between_orders'] ?? 10,
      maxOrdersPerGroup: json['max_orders_per_group'] ?? 4,
      maxStoresPerTrip: json['max_stores_per_trip'] ?? 4,
      minimumDriverRating: double.tryParse('${json['minimum_driver_rating']}') ?? 0,
      autoAssignDriver: json['auto_assign_driver'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'grouped_delivery_enabled': groupedDeliveryEnabled,
      'max_store_distance': maxStoreDistance,
      'max_delivery_distance': maxDeliveryDistance,
      'max_time_between_orders': maxTimeBetweenOrders,
      'max_orders_per_group': maxOrdersPerGroup,
      'max_stores_per_trip': maxStoresPerTrip,
      'minimum_driver_rating': minimumDriverRating,
      'auto_assign_driver': autoAssignDriver,
    };
  }
}

// ✅ خريطة تفاعلية حية (#2) - راجع adminController.getLiveMapData
class AdminLiveMapStore {
  final String id;
  final String name;
  final String? category;
  final String? icon;
  final double lat;
  final double lng;
  final bool isOpen;

  AdminLiveMapStore({
    required this.id,
    required this.name,
    this.category,
    this.icon,
    required this.lat,
    required this.lng,
    required this.isOpen,
  });

  factory AdminLiveMapStore.fromJson(Map<String, dynamic> json) {
    return AdminLiveMapStore(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      category: json['category'],
      icon: json['icon'],
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
      isOpen: json['is_open'] ?? true,
    );
  }
}

class AdminLiveMapDriver {
  final String id;
  final String name;
  final String? vehicleType;
  final String status; // Available/Busy/Offline
  final double lat;
  final double lng;

  AdminLiveMapDriver({
    required this.id,
    required this.name,
    this.vehicleType,
    required this.status,
    required this.lat,
    required this.lng,
  });

  factory AdminLiveMapDriver.fromJson(Map<String, dynamic> json) {
    return AdminLiveMapDriver(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      vehicleType: json['vehicle_type'],
      status: json['status'] ?? 'Offline',
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
    );
  }
}

class AdminLiveMapStop {
  final String orderId;
  final String? storeName;
  final double lat;
  final double lng;
  final int pickupSequence;

  AdminLiveMapStop({required this.orderId, this.storeName, required this.lat, required this.lng, required this.pickupSequence});

  factory AdminLiveMapStop.fromJson(Map<String, dynamic> json) {
    return AdminLiveMapStop(
      orderId: json['order_id']?.toString() ?? '',
      storeName: json['store_name'],
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
      pickupSequence: json['pickup_sequence'] ?? 0,
    );
  }
}

class AdminLiveMapGroup {
  final String id;
  final String status;
  final AdminLiveMapDriver? driver;
  final List<AdminLiveMapStop> stops;

  AdminLiveMapGroup({required this.id, required this.status, this.driver, this.stops = const []});

  factory AdminLiveMapGroup.fromJson(Map<String, dynamic> json) {
    return AdminLiveMapGroup(
      id: json['id']?.toString() ?? '',
      status: json['status'] ?? 'Forming',
      driver: json['driver'] != null ? AdminLiveMapDriver.fromJson(json['driver']) : null,
      stops: json['stops'] != null ? (json['stops'] as List).map((e) => AdminLiveMapStop.fromJson(e)).toList() : [],
    );
  }
}

class AdminLiveMapData {
  final List<AdminLiveMapStore> stores;
  final List<AdminLiveMapDriver> drivers;
  final List<AdminLiveMapGroup> activeGroups;

  AdminLiveMapData({this.stores = const [], this.drivers = const [], this.activeGroups = const []});

  factory AdminLiveMapData.empty() => AdminLiveMapData();

  factory AdminLiveMapData.fromJson(Map<String, dynamic> json) {
    return AdminLiveMapData(
      stores: (json['stores'] as List? ?? []).map((e) => AdminLiveMapStore.fromJson(e)).toList(),
      drivers: (json['drivers'] as List? ?? []).map((e) => AdminLiveMapDriver.fromJson(e)).toList(),
      activeGroups: (json['active_groups'] as List? ?? []).map((e) => AdminLiveMapGroup.fromJson(e)).toList(),
    );
  }
}

// ✅ Delivery Simulation (#6) - راجع adminController.simulateGrouping /
// groupingService.evaluateGroupingMatch
class GroupingSimulationResult {
  final double? storeDistanceKm;
  final double? deliveryDistanceKm;
  final int timeDifferenceMinutes;
  final List<String> rulesSatisfied;
  final List<String> rulesFailed;
  final bool willGroup;

  GroupingSimulationResult({
    this.storeDistanceKm,
    this.deliveryDistanceKm,
    required this.timeDifferenceMinutes,
    this.rulesSatisfied = const [],
    this.rulesFailed = const [],
    required this.willGroup,
  });

  factory GroupingSimulationResult.fromJson(Map<String, dynamic> json) {
    return GroupingSimulationResult(
      storeDistanceKm: json['store_distance_km'] != null ? (json['store_distance_km'] as num).toDouble() : null,
      deliveryDistanceKm: json['delivery_distance_km'] != null ? (json['delivery_distance_km'] as num).toDouble() : null,
      timeDifferenceMinutes: json['time_difference_minutes'] ?? 0,
      rulesSatisfied: json['rules_satisfied'] != null ? List<String>.from(json['rules_satisfied']) : [],
      rulesFailed: json['rules_failed'] != null ? List<String>.from(json['rules_failed']) : [],
      willGroup: json['will_group'] ?? false,
    );
  }
}
