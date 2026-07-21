// lib/services/driver_service.dart
//
// خدمات السائق الذاتية: تفعيل/إيقاف استقبال الطلبات (Available/Offline)،
// وping دوري لموقعه الحالي - المصدر يلي بيخلي Driver Availability حقيقية
// بكل النظام (لوحة الشركة/الأدمن ولاحقًا التوزيع الذكي).
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../data/models/analytics_model.dart';
import 'api_service.dart';

/// حالة السائق كما يعرضها النظام - نفس التسمية بالباك إند
enum DriverAvailabilityStatus { available, busy, offline }

DriverAvailabilityStatus parseDriverAvailability(String? value) {
  switch (value) {
    case 'Available':
      return DriverAvailabilityStatus.available;
    case 'Busy':
      return DriverAvailabilityStatus.busy;
    default:
      return DriverAvailabilityStatus.offline;
  }
}

class DriverActionResult {
  final bool success;
  final String message;
  final DriverAvailabilityStatus? status;

  DriverActionResult({required this.success, this.message = '', this.status});
}

class DriverService {
  final ApiService _apiService = ApiService();

  /// السائق بيفعّل/يوقف استقبال الطلبات يدوياً - Busy محجوزة للنظام بس
  Future<DriverActionResult> setMyStatus(DriverAvailabilityStatus status) async {
    if (status == DriverAvailabilityStatus.busy) {
      return DriverActionResult(success: false, message: 'Busy status is system-controlled');
    }
    try {
      final response = await _apiService.patch(
        ApiConstants.driverStatus,
        data: {'status': status == DriverAvailabilityStatus.available ? 'Available' : 'Offline'},
      );
      final data = response.data;
      return DriverActionResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        status: parseDriverAvailability(data['status']),
      );
    } catch (e) {
      if (kDebugMode) print('setMyStatus error: $e');
      return DriverActionResult(success: false, message: 'Network error while updating status');
    }
  }

  /// ping دوري لموقع السائق الحالي - لازم يستمر يترسل بانتظام وهو Available/Busy
  /// وإلا النظام بيعتبره منقطع الاتصال ويرجّعه Offline تلقائياً
  Future<bool> pingLocation(double lat, double lng) async {
    try {
      final response = await _apiService.post(
        ApiConstants.driverLocationPing,
        data: {'lat': lat, 'lng': lng},
      );
      return response.data['success'] ?? false;
    } catch (e) {
      if (kDebugMode) print('pingLocation error: $e');
      return false;
    }
  }

  /// تحليلات أدائي (متوسط وقت التوصيل، نسب قبول/رفض عروض التعيين الذكي،
  /// عدد الطلبات المكتملة، معدّل الالتزام) - شاشة "أدائي" بتطبيق السائق
  Future<DriverPerformanceModel?> getMyPerformance() async {
    try {
      final response = await _apiService.get(ApiConstants.driverPerformance);
      final data = response.data;
      if (data['success'] == true && data['performance'] != null) {
        return DriverPerformanceModel.fromJson(data['performance']);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('getMyPerformance error: $e');
      return null;
    }
  }
}
