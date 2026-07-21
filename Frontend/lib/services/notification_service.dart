// lib/services/notification_service.dart
//
// Phase 4 - نظام الإشعارات: يربط الفرونت مع /api/notifications - قائمة
// إشعاراتي (الأحدث فالأقدم + عدد غير المقروء)، تعليم إشعار كمقروء، وتعليم الكل.
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../data/models/notification_model.dart';
import 'api_service.dart';

class NotificationsResult {
  final bool success;
  final String message;
  final List<NotificationModel> notifications;
  final int unreadCount;

  NotificationsResult({
    required this.success,
    this.message = '',
    this.notifications = const [],
    this.unreadCount = 0,
  });
}

class NotificationActionResult {
  final bool success;
  final String message;

  NotificationActionResult({required this.success, this.message = ''});
}

class NotificationService {
  final ApiService _apiService = ApiService();

  Future<NotificationsResult> getMyNotifications() async {
    try {
      final response = await _apiService.get(ApiConstants.notifications);
      final data = response.data;
      if (data['success'] == true) {
        return NotificationsResult(
          success: true,
          notifications: (data['notifications'] as List? ?? [])
              .map((n) => NotificationModel.fromJson(n))
              .toList(),
          unreadCount: data['unread_count'] ?? 0,
        );
      }
      return NotificationsResult(success: false);
    } catch (e) {
      if (kDebugMode) print('getMyNotifications error: $e');
      return NotificationsResult(success: false, message: 'Network error while fetching notifications');
    }
  }

  Future<NotificationActionResult> markAsRead(String id) async {
    try {
      final response = await _apiService.patch(ApiConstants.notificationRead(id));
      final data = response.data;
      return NotificationActionResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('markAsRead error: $e');
      return NotificationActionResult(success: false, message: 'Network error while updating notification');
    }
  }

  Future<NotificationActionResult> markAllAsRead() async {
    try {
      final response = await _apiService.patch(ApiConstants.notificationReadAll);
      final data = response.data;
      return NotificationActionResult(success: data['success'] ?? false, message: data['message'] ?? '');
    } catch (e) {
      if (kDebugMode) print('markAllAsRead error: $e');
      return NotificationActionResult(success: false, message: 'Network error while updating notifications');
    }
  }
}
