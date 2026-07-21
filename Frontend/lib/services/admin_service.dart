// lib/services/admin_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../data/models/admin_models.dart';
import '../data/models/analytics_model.dart';
import 'api_service.dart';

class AdminResult {
  final bool success;
  final String message;

  AdminResult({required this.success, this.message = ''});
}

class AdminService {
  final ApiService _apiService = ApiService();

  Future<AdminDashboardStats> getDashboardStats() async {
    try {
      final response = await _apiService.get(ApiConstants.adminDashboard);
      if (response.data['success'] == true) {
        return AdminDashboardStats.fromJson(response.data);
      }
      return AdminDashboardStats.empty();
    } catch (e) {
      if (kDebugMode) print('getDashboardStats error: $e');
      return AdminDashboardStats.empty();
    }
  }

  Future<List<AdminStoreModel>> getStores() async {
    try {
      final response = await _apiService.get(ApiConstants.adminStores);
      final data = response.data;
      if (data['success'] == true && data['stores'] != null) {
        return (data['stores'] as List)
            .map((s) => AdminStoreModel.fromJson(s))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getStores error: $e');
      return [];
    }
  }

  Future<AdminResult> approveStore(String storeId) async {
    try {
      final response = await _apiService.put(ApiConstants.adminApproveStore(storeId));
      final data = response.data;
      return AdminResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('approveStore error: $e');
      return AdminResult(success: false, message: 'Network error while approving store');
    }
  }

  Future<AdminResult> rejectStore(String storeId, {String? reason}) async {
    try {
      final response = await _apiService.put(
        ApiConstants.adminRejectStore(storeId),
        data: {'reason': reason},
      );
      final data = response.data;
      return AdminResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('rejectStore error: $e');
      return AdminResult(success: false, message: 'Network error while rejecting store');
    }
  }

  Future<AdminResult> toggleFeatured(String storeId, bool isFeatured) async {
    try {
      final response = await _apiService.patch(
        ApiConstants.adminToggleFeaturedStore(storeId),
        data: {'is_featured': isFeatured},
      );
      final data = response.data;
      return AdminResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('toggleFeatured error: $e');
      return AdminResult(success: false, message: 'Network error while updating featured flag');
    }
  }

  Future<AdminResult> deleteStore(String storeId) async {
    try {
      final response = await _apiService.delete(ApiConstants.adminDeleteStore(storeId));
      final data = response.data;
      return AdminResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('deleteStore error: $e');
      return AdminResult(success: false, message: 'Network error while deleting store');
    }
  }

  Future<List<AdminCompanyModel>> getDeliveryCompanies() async {
    try {
      final response = await _apiService.get(ApiConstants.adminCompanies);
      final data = response.data;
      if (data['success'] == true && data['companies'] != null) {
        return (data['companies'] as List)
            .map((c) => AdminCompanyModel.fromJson(c))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getDeliveryCompanies error: $e');
      return [];
    }
  }

  Future<List<AdminDriverModel>> getDrivers() async {
    try {
      final response = await _apiService.get(ApiConstants.adminDrivers);
      final data = response.data;
      if (data['success'] == true && data['drivers'] != null) {
        return (data['drivers'] as List)
            .map((d) => AdminDriverModel.fromJson(d))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getDrivers error: $e');
      return [];
    }
  }

  Future<AdminResult> approveCompany(String companyId) async {
    try {
      final response = await _apiService.put(ApiConstants.adminApproveCompany(companyId));
      final data = response.data;
      return AdminResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('approveCompany error: $e');
      return AdminResult(success: false, message: 'Network error while approving delivery company');
    }
  }

  Future<AdminResult> rejectCompany(String companyId) async {
    try {
      final response = await _apiService.put(ApiConstants.adminRejectCompany(companyId));
      final data = response.data;
      return AdminResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('rejectCompany error: $e');
      return AdminResult(success: false, message: 'Network error while rejecting delivery company');
    }
  }

  Future<List<AdminOrderModel>> getOrders({String? status}) async {
    try {
      final response = await _apiService.get(
        ApiConstants.adminOrders,
        queryParameters: status != null ? {'status': status} : null,
      );
      final data = response.data;
      if (data['success'] == true && data['orders'] != null) {
        return (data['orders'] as List)
            .map((o) => AdminOrderModel.fromJson(o))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getOrders error: $e');
      return [];
    }
  }

  Future<List<AdminUserModel>> getUsers() async {
    try {
      final response = await _apiService.get(ApiConstants.adminUsers);
      final data = response.data;
      if (data['success'] == true && data['users'] != null) {
        return (data['users'] as List)
            .map((u) => AdminUserModel.fromJson(u))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getUsers error: $e');
      return [];
    }
  }

  Future<List<AdminCategoryModel>> getCategories() async {
    try {
      final response = await _apiService.get(ApiConstants.adminCategories);
      final data = response.data;
      if (data['success'] == true && data['categories'] != null) {
        return (data['categories'] as List)
            .map((c) => AdminCategoryModel.fromJson(c))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getCategories error: $e');
      return [];
    }
  }

  /// تعديل حالة أي مستخدم (Approved/Suspended/Pending/Rejected) - نقطة
  /// الوصول العامة الوحيدة، تشتغل لأي دور (زبون/سائق/صاحب متجر/شركة)
  Future<AdminResult> updateUserStatus(String userId, String status) async {
    try {
      final response = await _apiService.patch(
        ApiConstants.adminUserStatus(userId),
        data: {'status': status},
      );
      final data = response.data;
      return AdminResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('updateUserStatus error: $e');
      return AdminResult(success: false, message: 'Network error while updating user status');
    }
  }

  Future<AdminOrderDetailModel?> getOrderDetail(String orderId) async {
    try {
      final response = await _apiService.get(ApiConstants.adminOrderDetail(orderId));
      final data = response.data;
      if (data['success'] == true && data['order'] != null) {
        return AdminOrderDetailModel.fromJson(data['order']);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('getOrderDetail error: $e');
      return null;
    }
  }

  Future<List<AdminDeliveryGroupModel>> getDeliveryGroups() async {
    try {
      final response = await _apiService.get(ApiConstants.adminDeliveryGroups);
      final data = response.data;
      if (data['success'] == true && data['groups'] != null) {
        return (data['groups'] as List)
            .map((g) => AdminDeliveryGroupModel.fromJson(g))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getDeliveryGroups error: $e');
      return [];
    }
  }

  Future<SystemSettingsModel> getSystemSettings() async {
    try {
      final response = await _apiService.get(ApiConstants.adminSettings);
      if (response.data['success'] == true && response.data['settings'] != null) {
        return SystemSettingsModel.fromJson(response.data['settings']);
      }
      return SystemSettingsModel.empty();
    } catch (e) {
      if (kDebugMode) print('getSystemSettings error: $e');
      return SystemSettingsModel.empty();
    }
  }

  Future<AdminResult> updateSystemSettings(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.put(ApiConstants.adminSettings, data: data);
      final body = response.data;
      return AdminResult(success: body['success'] ?? false, message: body['message'] ?? '');
    } on DioException catch (e) {
      // ✅ رسائل التحقق (مثلاً "distance cannot be negative") بترجع بجسم
      // رد الـ 400 من الباك اند - منعرضها للمستخدم بدل رسالة عامة
      final serverMessage = e.response?.data is Map ? e.response?.data['message'] : null;
      if (kDebugMode) print('updateSystemSettings error: $e');
      return AdminResult(
        success: false,
        message: serverMessage ?? 'Network error while updating settings',
      );
    } catch (e) {
      if (kDebugMode) print('updateSystemSettings error: $e');
      return AdminResult(success: false, message: 'Network error while updating settings');
    }
  }

  // ✅ خريطة تفاعلية حية (#2)
  Future<AdminLiveMapData> getLiveMapData() async {
    try {
      final response = await _apiService.get(ApiConstants.adminLiveMap);
      if (response.data['success'] == true) {
        return AdminLiveMapData.fromJson(response.data);
      }
      return AdminLiveMapData.empty();
    } catch (e) {
      if (kDebugMode) print('getLiveMapData error: $e');
      return AdminLiveMapData.empty();
    }
  }

  // ✅ Delivery Simulation (#6)
  Future<GroupingSimulationResult?> simulateGrouping({
    required double storeALat,
    required double storeALng,
    required double storeBLat,
    required double storeBLng,
    required double customerLat,
    required double customerLng,
    required double timeDifferenceMinutes,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.adminSimulateGrouping,
        data: {
          'store_a': {'lat': storeALat, 'lng': storeALng},
          'store_b': {'lat': storeBLat, 'lng': storeBLng},
          'customer_a': {'lat': customerLat, 'lng': customerLng},
          'time_difference_minutes': timeDifferenceMinutes,
        },
      );
      if (response.data['success'] == true && response.data['simulation'] != null) {
        return GroupingSimulationResult.fromJson(response.data['simulation']);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('simulateGrouping error: $e');
      return null;
    }
  }

  // ✅ لوحة التحليلات الرئيسية: طلبات يومية، إيرادات، أنشط المتاجر، أفضل
  // السائقين، نجاح التعيين الذكي، نسبة الطلبات المجمّعة
  Future<AdminAnalyticsModel?> getAnalyticsDashboard({int days = 14}) async {
    try {
      final response = await _apiService.get(
        ApiConstants.adminAnalytics,
        queryParameters: {'days': days},
      );
      if (response.data['success'] == true && response.data['analytics'] != null) {
        return AdminAnalyticsModel.fromJson(response.data['analytics']);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('getAnalyticsDashboard error: $e');
      return null;
    }
  }

  // ✅ تحليلات أداء سائق معيّن (شاشة تفاصيل السائق)
  Future<DriverPerformanceModel?> getDriverPerformance(String driverId) async {
    try {
      final response = await _apiService.get(ApiConstants.adminDriverPerformance(driverId));
      if (response.data['success'] == true && response.data['performance'] != null) {
        return DriverPerformanceModel.fromJson(response.data['performance']);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('getDriverPerformance error: $e');
      return null;
    }
  }

  // ✅ تحليلات متجر معيّن (شاشة تفاصيل المتجر)
  Future<StoreAnalyticsModel?> getStoreAnalytics(String storeId) async {
    try {
      final response = await _apiService.get(ApiConstants.adminStoreAnalytics(storeId));
      if (response.data['success'] == true && response.data['analytics'] != null) {
        return StoreAnalyticsModel.fromJson(response.data['analytics']);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('getStoreAnalytics error: $e');
      return null;
    }
  }
}
