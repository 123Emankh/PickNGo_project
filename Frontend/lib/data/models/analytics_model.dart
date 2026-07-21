// lib/data/models/analytics_model.dart
//
// نماذج التحليلات القائمة على القواعد/الإحصاء (لا Machine Learning) - أداء
// السائق، تحليلات المتجر، ولوحة تحليلات الأدمن. كلها مطابقة تمامًا لشكل الرد
// من backend/src/services/analytics/*.

class SmartAssignmentStats {
  final int totalOffers;
  final int accepted;
  final int rejected;
  final int expired;
  final int pending;
  final double? acceptanceRate;
  final double? rejectionRate;

  SmartAssignmentStats({
    required this.totalOffers,
    required this.accepted,
    required this.rejected,
    required this.expired,
    required this.pending,
    this.acceptanceRate,
    this.rejectionRate,
  });

  factory SmartAssignmentStats.fromJson(Map<String, dynamic> json) {
    return SmartAssignmentStats(
      totalOffers: json['total_offers'] ?? 0,
      accepted: json['accepted'] ?? 0,
      rejected: json['rejected'] ?? 0,
      expired: json['expired'] ?? 0,
      pending: json['pending'] ?? 0,
      acceptanceRate: json['acceptance_rate'] != null ? (json['acceptance_rate'] as num).toDouble() : null,
      rejectionRate: json['rejection_rate'] != null ? (json['rejection_rate'] as num).toDouble() : null,
    );
  }
}

class DriverPerformanceModel {
  final int completedOrders;
  final int? avgDeliveryTimeMin;
  final int avgDeliveryTimeSampleSize;
  final SmartAssignmentStats smartAssignment;
  final double? commitmentRate;

  DriverPerformanceModel({
    required this.completedOrders,
    this.avgDeliveryTimeMin,
    required this.avgDeliveryTimeSampleSize,
    required this.smartAssignment,
    this.commitmentRate,
  });

  factory DriverPerformanceModel.fromJson(Map<String, dynamic> json) {
    return DriverPerformanceModel(
      completedOrders: json['completed_orders'] ?? 0,
      avgDeliveryTimeMin: json['avg_delivery_time_min'],
      avgDeliveryTimeSampleSize: json['avg_delivery_time_sample_size'] ?? 0,
      smartAssignment: SmartAssignmentStats.fromJson(json['smart_assignment'] ?? {}),
      commitmentRate: json['commitment_rate'] != null ? (json['commitment_rate'] as num).toDouble() : null,
    );
  }
}

class PeakHourStat {
  final int hour;
  final int count;
  PeakHourStat({required this.hour, required this.count});
  factory PeakHourStat.fromJson(Map<String, dynamic> json) =>
      PeakHourStat(hour: json['hour'] ?? 0, count: json['count'] ?? 0);
}

class TopProductStat {
  final String productId;
  final String name;
  final int totalQuantity;
  final double totalRevenue;
  TopProductStat({required this.productId, required this.name, required this.totalQuantity, required this.totalRevenue});
  factory TopProductStat.fromJson(Map<String, dynamic> json) => TopProductStat(
        productId: json['product_id']?.toString() ?? '',
        name: json['name'] ?? '',
        totalQuantity: json['total_quantity'] ?? 0,
        totalRevenue: (json['total_revenue'] ?? 0).toDouble(),
      );
}

class StoreAnalyticsModel {
  final int totalOrders;
  final int cancelledOrders;
  final double? cancellationRate;
  final double? avgOrderValue;
  final int uniqueCustomers;
  final int repeatCustomers;
  final double? repeatCustomerRate;
  final List<PeakHourStat> peakHours;
  final List<TopProductStat> topProducts;

  StoreAnalyticsModel({
    required this.totalOrders,
    required this.cancelledOrders,
    this.cancellationRate,
    this.avgOrderValue,
    required this.uniqueCustomers,
    required this.repeatCustomers,
    this.repeatCustomerRate,
    required this.peakHours,
    required this.topProducts,
  });

  factory StoreAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return StoreAnalyticsModel(
      totalOrders: json['total_orders'] ?? 0,
      cancelledOrders: json['cancelled_orders'] ?? 0,
      cancellationRate: json['cancellation_rate'] != null ? (json['cancellation_rate'] as num).toDouble() : null,
      avgOrderValue: json['avg_order_value'] != null ? (json['avg_order_value'] as num).toDouble() : null,
      uniqueCustomers: json['unique_customers'] ?? 0,
      repeatCustomers: json['repeat_customers'] ?? 0,
      repeatCustomerRate: json['repeat_customer_rate'] != null ? (json['repeat_customer_rate'] as num).toDouble() : null,
      peakHours: (json['peak_hours'] as List? ?? []).map((h) => PeakHourStat.fromJson(h)).toList(),
      topProducts: (json['top_products'] as List? ?? []).map((p) => TopProductStat.fromJson(p)).toList(),
    );
  }
}

class DailyOrderStat {
  final String date;
  final int orders;
  final double revenue;
  DailyOrderStat({required this.date, required this.orders, required this.revenue});
  factory DailyOrderStat.fromJson(Map<String, dynamic> json) => DailyOrderStat(
        date: json['date'] ?? '',
        orders: json['orders'] ?? 0,
        revenue: (json['revenue'] ?? 0).toDouble(),
      );
}

class TopStoreStat {
  final String storeId;
  final String name;
  final int orderCount;
  TopStoreStat({required this.storeId, required this.name, required this.orderCount});
  factory TopStoreStat.fromJson(Map<String, dynamic> json) => TopStoreStat(
        storeId: json['store_id']?.toString() ?? '',
        name: json['name'] ?? '',
        orderCount: json['order_count'] ?? 0,
      );
}

class TopDriverStat {
  final String driverId;
  final String name;
  final DriverPerformanceModel performance;
  TopDriverStat({required this.driverId, required this.name, required this.performance});
  factory TopDriverStat.fromJson(Map<String, dynamic> json) => TopDriverStat(
        driverId: json['driver_id']?.toString() ?? '',
        name: json['name'] ?? '',
        performance: DriverPerformanceModel.fromJson(json),
      );
}

class SmartAssignmentSummary {
  final int neededAssignment;
  final int autoAssigned;
  final int manualAssigned;
  final int unassigned;
  final double? successRate;
  SmartAssignmentSummary({
    required this.neededAssignment,
    required this.autoAssigned,
    required this.manualAssigned,
    required this.unassigned,
    this.successRate,
  });
  factory SmartAssignmentSummary.fromJson(Map<String, dynamic> json) => SmartAssignmentSummary(
        neededAssignment: json['needed_assignment'] ?? 0,
        autoAssigned: json['auto_assigned'] ?? 0,
        manualAssigned: json['manual_assigned'] ?? 0,
        unassigned: json['unassigned'] ?? 0,
        successRate: json['success_rate'] != null ? (json['success_rate'] as num).toDouble() : null,
      );
}

class AdminAnalyticsModel {
  final int periodDays;
  final int totalOrders;
  final double totalRevenue;
  final List<DailyOrderStat> daily;
  final List<TopStoreStat> topStores;
  final List<TopDriverStat> topDrivers;
  final SmartAssignmentSummary smartAssignment;
  final double? groupedOrderRate;
  final int groupedOrders;

  AdminAnalyticsModel({
    required this.periodDays,
    required this.totalOrders,
    required this.totalRevenue,
    required this.daily,
    required this.topStores,
    required this.topDrivers,
    required this.smartAssignment,
    this.groupedOrderRate,
    required this.groupedOrders,
  });

  factory AdminAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return AdminAnalyticsModel(
      periodDays: json['period_days'] ?? 14,
      totalOrders: json['total_orders'] ?? 0,
      totalRevenue: (json['total_revenue'] ?? 0).toDouble(),
      daily: (json['daily'] as List? ?? []).map((d) => DailyOrderStat.fromJson(d)).toList(),
      topStores: (json['top_stores'] as List? ?? []).map((s) => TopStoreStat.fromJson(s)).toList(),
      topDrivers: (json['top_drivers'] as List? ?? []).map((d) => TopDriverStat.fromJson(d)).toList(),
      smartAssignment: SmartAssignmentSummary.fromJson(json['smart_assignment'] ?? {}),
      groupedOrderRate: json['grouped_order_rate'] != null ? (json['grouped_order_rate'] as num).toDouble() : null,
      groupedOrders: json['grouped_orders'] ?? 0,
    );
  }
}
