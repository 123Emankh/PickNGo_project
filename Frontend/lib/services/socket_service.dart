// lib/services/socket_service.dart
//
// يغلف اتصال Socket.io لتتبع الطلبات اللحظي: انضمام/مغادرة غرفة طلب معيّن،
// بث موقع السائق (Driver)، والاستماع لتحديثات الموقع وحالة الطلب (Customer/Restaurant/Admin).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../core/constants/api_constants.dart';
import '../data/models/offer_model.dart';
import '../data/models/notification_model.dart';
import 'storage_service.dart';

final socketServiceProvider = Provider<SocketService>((ref) => SocketService());

class DriverLocationEvent {
  final String orderId;
  final double lat;
  final double lng;
  final DateTime? updatedAt;

  DriverLocationEvent({
    required this.orderId,
    required this.lat,
    required this.lng,
    this.updatedAt,
  });

  factory DriverLocationEvent.fromMap(Map data) {
    return DriverLocationEvent(
      orderId: data['order_id'].toString(),
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'].toString())
          : null,
    );
  }
}

class OrderStatusEvent {
  final String orderId;
  final String status;

  OrderStatusEvent({required this.orderId, required this.status});

  factory OrderStatusEvent.fromMap(Map data) {
    return OrderStatusEvent(
      orderId: data['order_id'].toString(),
      status: data['status'].toString(),
    );
  }
}

class DriverStatusEvent {
  final String driverId;
  final String status; // 'Available' | 'Busy' | 'Offline'

  DriverStatusEvent({required this.driverId, required this.status});

  factory DriverStatusEvent.fromMap(Map data) {
    return DriverStatusEvent(
      driverId: data['driver_id'].toString(),
      status: data['status'].toString(),
    );
  }
}

class SocketService {
  final StorageService _storageService = StorageService();
  socket_io.Socket? _socket;

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await _storageService.getToken();
    _socket = socket_io.io(
      ApiConstants.baseUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void joinOrder(String orderId) {
    _socket?.emit('order:join', {'order_id': int.tryParse(orderId) ?? orderId});
  }

  void leaveOrder(String orderId) {
    _socket?.emit('order:leave', {'order_id': int.tryParse(orderId) ?? orderId});
  }

  void emitDriverLocation(String orderId, double lat, double lng) {
    _socket?.emit('driver:location', {
      'order_id': int.tryParse(orderId) ?? orderId,
      'lat': lat,
      'lng': lng,
    });
  }

  void onDriverLocation(void Function(DriverLocationEvent event) callback) {
    _socket?.on('driver:location', (data) {
      if (data is Map) callback(DriverLocationEvent.fromMap(data));
    });
  }

  void onOrderStatus(void Function(OrderStatusEvent event) callback) {
    _socket?.on('order:status', (data) {
      if (data is Map) callback(OrderStatusEvent.fromMap(data));
    });
  }

  void onError(void Function(String message) callback) {
    _socket?.on('order:error', (data) {
      if (data is Map) callback(data['message']?.toString() ?? 'Socket error');
    });
  }

  /// حالة سائق تغيّرت (Available/Busy/Offline) - السيرفر بيبثها لغرفة الأدمن
  /// وغرفة شركة السائق (لو تابع لشركة) تلقائياً، بدون داعي لعمل join يدوي هون.
  void onDriverStatus(void Function(DriverStatusEvent event) callback) {
    _socket?.on('driver:status', (data) {
      if (data is Map) callback(DriverStatusEvent.fromMap(data));
    });
  }

  /// عرض تعيين ذكي (Phase 3 - Smart Assignment) جديد وصل لهاد السائق بالذات -
  /// السيرفر بيبثه لغرفة driver-orders:{driverId} (انضمام تلقائي وقت الاتصال
  /// بدور Driver) بدون داعي لأي join يدوي هون.
  void onOrderOffer(void Function(DeliveryOfferModel offer) callback) {
    _socket?.on('order:offer', (data) {
      if (data is Map) callback(DeliveryOfferModel.fromJson(Map<String, dynamic>.from(data)));
    });
  }

  /// Phase 4 - نظام الإشعارات: إشعار جديد وصل لهاد المستخدم بالذات (بغض
  /// النظر عن الدور) - غرفة notifications:{userId} ينضم لها كل سوكيت تلقائيًا
  /// وقت الاتصال (راجع sockets/index.js)
  void onNotificationNew(void Function(NotificationModel notification) callback) {
    _socket?.on('notification:new', (data) {
      if (data is Map) callback(NotificationModel.fromJson(Map<String, dynamic>.from(data)));
    });
  }

  void offDriverLocation() => _socket?.off('driver:location');
  void offOrderStatus() => _socket?.off('order:status');
  void offError() => _socket?.off('order:error');
  void offDriverStatus() => _socket?.off('driver:status');
  void offOrderOffer() => _socket?.off('order:offer');
  void offNotificationNew() => _socket?.off('notification:new');

  bool get isConnected => _socket?.connected ?? false;
}
