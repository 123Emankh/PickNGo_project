// lib/data/models/notification_model.dart
//
// Phase 4 - نظام الإشعارات: يمثل صف إشعار زي ما بيرجعه الباك إند من
// notificationService.formatNotification() - نفس الشكل بالضبط يجي من
// GET /api/notifications ومن حدث السوكيت notification:new.

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // OrderStatus | NewOrder | SmartAssignmentOffer | UserStatus | AdminApproval | NewReview | LoyaltyEarned
  final String? relatedType; // Order | DeliveryGroup | Restaurant | User | null
  final String? relatedId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.relatedType,
    this.relatedId,
    required this.isRead,
    required this.createdAt,
  });

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      title: title,
      body: body,
      type: type,
      relatedType: relatedType,
      relatedId: relatedId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? '',
      relatedType: json['related_type'],
      relatedId: json['related_id']?.toString(),
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
