// lib/providers/notification_provider.dart
//
// Phase 4 - نظام الإشعارات: حالة إشعارات المستخدم الحالي عبر التطبيق كله
// (badge بأي هيدر + شاشة الإشعارات) - نفس فلسفة favorites_provider.dart
// (تحميل مرة وحدة، تحديث محلي فوري، بث لحظي عبر Socket.io).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref.read(notificationServiceProvider), ref.read(socketServiceProvider));
});

class NotificationState {
  final List<NotificationModel> items;
  final int unreadCount;
  final bool isLoading;

  NotificationState({this.items = const [], this.unreadCount = 0, this.isLoading = false});

  NotificationState copyWith({List<NotificationModel>? items, int? unreadCount, bool? isLoading}) {
    return NotificationState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationService _service;
  final SocketService _socket;
  bool _loaded = false;

  NotificationNotifier(this._service, this._socket) : super(NotificationState());

  /// يجيب القائمة الحقيقية أول مرة بس + يوصل السوكيت ويستمع لإشعارات جديدة
  /// لحظيًا - أي نداء تاني بعدها ما بيعمل شي (idempotent) لأنه ref.read(...)
  /// بينادى من أكتر من هيدر بنفس الوقت.
  Future<void> loadInitial() async {
    if (_loaded) return;
    _loaded = true;
    await refresh();
    await _socket.connect();
    _socket.onNotificationNew((notification) {
      state = state.copyWith(
        items: [notification, ...state.items],
        unreadCount: state.unreadCount + (notification.isRead ? 0 : 1),
      );
    });
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    final result = await _service.getMyNotifications();
    if (result.success) {
      state = state.copyWith(items: result.notifications, unreadCount: result.unreadCount, isLoading: false);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> markRead(String id) async {
    final index = state.items.indexWhere((n) => n.id == id);
    if (index == -1 || state.items[index].isRead) return;

    // ✅ تحديث فوري متفائل (optimistic) - نفس نمط FavoritesNotifier.toggle
    final updated = [...state.items];
    updated[index] = updated[index].copyWith(isRead: true);
    state = state.copyWith(items: updated, unreadCount: (state.unreadCount - 1).clamp(0, 1 << 30));

    await _service.markAsRead(id);
  }

  Future<void> markAllRead() async {
    if (state.unreadCount == 0) return;
    state = state.copyWith(
      items: state.items.map((n) => n.copyWith(isRead: true)).toList(),
      unreadCount: 0,
    );
    await _service.markAllAsRead();
  }

  void reset() {
    _loaded = false;
    _socket.offNotificationNew();
    state = NotificationState();
  }
}
