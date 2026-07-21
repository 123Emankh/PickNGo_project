// lib/services/company_service.dart
//
// يربط الفرونت مع /api/company: قائمة شركات التوصيل المعتمدة (تستخدم وقت
// تسجيل سائق جديد)، وإدارة كاملة لسجل سائقي الشركة (لوحة تحكم صاحب الشركة):
// السجل المعتمد، طلبات الانضمام، قبول/رفض، إزالة، وتفعيل/إيقاف.
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import 'api_service.dart';

class DeliveryCompanyModel {
  final String id;
  final String name;
  final String? city;
  final String? region;

  DeliveryCompanyModel({required this.id, required this.name, this.city, this.region});

  factory DeliveryCompanyModel.fromJson(Map<String, dynamic> json) {
    return DeliveryCompanyModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      city: json['city'],
      region: json['region'],
    );
  }
}

/// حالة السائق اللحظية بلوحة الشركة
enum DriverAvailability { available, busy, offline }

DriverAvailability parseDriverAvailability(String? value) {
  switch (value) {
    case 'Available':
      return DriverAvailability.available;
    case 'Busy':
      return DriverAvailability.busy;
    default:
      return DriverAvailability.offline;
  }
}

class CompanyRosterDriverModel {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? vehicleType;
  final bool isActive;
  final String status;
  final int deliveredCount;
  final double earnings;
  final DriverAvailability availability;

  CompanyRosterDriverModel({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.vehicleType,
    required this.isActive,
    required this.status,
    required this.deliveredCount,
    required this.earnings,
    required this.availability,
  });

  factory CompanyRosterDriverModel.fromJson(Map<String, dynamic> json) {
    return CompanyRosterDriverModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      vehicleType: json['vehicle_type'],
      isActive: json['is_active'] ?? true,
      status: json['status'] ?? 'Approved',
      deliveredCount: json['delivered_count'] ?? 0,
      earnings: (json['earnings'] ?? 0).toDouble(),
      availability: parseDriverAvailability(json['driver_status']),
    );
  }

  CompanyRosterDriverModel copyWith({bool? isActive, DriverAvailability? availability}) {
    return CompanyRosterDriverModel(
      id: id,
      fullName: fullName,
      phone: phone,
      email: email,
      vehicleType: vehicleType,
      isActive: isActive ?? this.isActive,
      status: status,
      deliveredCount: deliveredCount,
      earnings: earnings,
      availability: availability ?? this.availability,
    );
  }
}

class CompanyJoinRequestModel {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? vehicleType;

  CompanyJoinRequestModel({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.vehicleType,
  });

  factory CompanyJoinRequestModel.fromJson(Map<String, dynamic> json) {
    return CompanyJoinRequestModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      vehicleType: json['vehicle_type'],
    );
  }
}

class CompanyListResult {
  final bool success;
  final String message;
  final List<DeliveryCompanyModel> companies;

  CompanyListResult({required this.success, this.message = '', this.companies = const []});
}

class CompanyRosterResult {
  final bool success;
  final String message;
  final List<CompanyRosterDriverModel> roster;

  CompanyRosterResult({required this.success, this.message = '', this.roster = const []});
}

class CompanyJoinRequestsResult {
  final bool success;
  final String message;
  final List<CompanyJoinRequestModel> requests;

  CompanyJoinRequestsResult({required this.success, this.message = '', this.requests = const []});
}

class CompanyActionResult {
  final bool success;
  final String message;

  CompanyActionResult({required this.success, this.message = ''});
}

class CompanyService {
  final ApiService _apiService = ApiService();

  /// قائمة شركات التوصيل المعتمدة فقط - عامة، تستخدم بشاشة اختيار الشركة وقت التسجيل
  Future<CompanyListResult> getApprovedCompanies() async {
    try {
      final response = await _apiService.get(ApiConstants.companyList);
      final data = response.data;
      if (data['success'] == true && data['companies'] != null) {
        return CompanyListResult(
          success: true,
          companies: (data['companies'] as List)
              .map((c) => DeliveryCompanyModel.fromJson(c))
              .toList(),
        );
      }
      return CompanyListResult(success: true, companies: []);
    } catch (e) {
      if (kDebugMode) print('getApprovedCompanies error: $e');
      return CompanyListResult(success: false, message: 'Network error while fetching delivery companies');
    }
  }

  /// سجل السائقين المعتمدين (Approved) التابعين لشركتي - محمي، لصاحب حساب الشركة فقط
  Future<CompanyRosterResult> getMyRoster() async {
    try {
      final response = await _apiService.get(ApiConstants.companyRoster);
      final data = response.data;
      if (data['success'] == true && data['roster'] != null) {
        return CompanyRosterResult(
          success: true,
          roster: (data['roster'] as List)
              .map((d) => CompanyRosterDriverModel.fromJson(d))
              .toList(),
        );
      }
      return CompanyRosterResult(success: true, roster: []);
    } catch (e) {
      if (kDebugMode) print('getMyRoster error: $e');
      return CompanyRosterResult(success: false, message: 'Network error while fetching company roster');
    }
  }

  /// طلبات الانضمام (Pending) لشركتي
  Future<CompanyJoinRequestsResult> getJoinRequests() async {
    try {
      final response = await _apiService.get(ApiConstants.companyJoinRequests);
      final data = response.data;
      if (data['success'] == true && data['requests'] != null) {
        return CompanyJoinRequestsResult(
          success: true,
          requests: (data['requests'] as List)
              .map((d) => CompanyJoinRequestModel.fromJson(d))
              .toList(),
        );
      }
      return CompanyJoinRequestsResult(success: true, requests: []);
    } catch (e) {
      if (kDebugMode) print('getJoinRequests error: $e');
      return CompanyJoinRequestsResult(success: false, message: 'Network error while fetching join requests');
    }
  }

  Future<CompanyActionResult> approveJoinRequest(String driverId) async {
    try {
      final response = await _apiService.post(ApiConstants.companyApproveJoinRequest(driverId));
      final data = response.data;
      return CompanyActionResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('approveJoinRequest error: $e');
      return CompanyActionResult(success: false, message: 'Network error while approving join request');
    }
  }

  Future<CompanyActionResult> rejectJoinRequest(String driverId) async {
    try {
      final response = await _apiService.post(ApiConstants.companyRejectJoinRequest(driverId));
      final data = response.data;
      return CompanyActionResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('rejectJoinRequest error: $e');
      return CompanyActionResult(success: false, message: 'Network error while rejecting join request');
    }
  }

  Future<CompanyActionResult> removeDriver(String driverId) async {
    try {
      final response = await _apiService.delete(ApiConstants.companyRemoveDriver(driverId));
      final data = response.data;
      return CompanyActionResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('removeDriver error: $e');
      return CompanyActionResult(success: false, message: 'Network error while removing driver');
    }
  }

  Future<CompanyActionResult> setDriverActive(String driverId, bool isActive) async {
    try {
      final response = await _apiService.patch(
        ApiConstants.companySetDriverActive(driverId),
        data: {'is_active': isActive},
      );
      final data = response.data;
      return CompanyActionResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('setDriverActive error: $e');
      return CompanyActionResult(success: false, message: 'Network error while updating driver status');
    }
  }
}
