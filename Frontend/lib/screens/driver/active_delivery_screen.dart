// lib/screens/driver/active_delivery_screen.dart
//
// شاشة "التوصيل النشط": تبعث موقع السائق اللحظي عبر Socket.io طول ما الطلب
// PickedUp (بما فيها لما التطبيق يكون بالخلفية)، ولما السائق يضغط "تم التسليم"
// بتوقف البث وتحدّث حالة الطلب لـ Delivered.
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../data/models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/socket_service.dart';
import '../../core/theme/app_themes.dart';
import '../../widgets/detail_app_bar.dart';

class ActiveDeliveryScreen extends ConsumerStatefulWidget {
  final String orderId;

  const ActiveDeliveryScreen({super.key, required this.orderId});

  @override
  ConsumerState<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends ConsumerState<ActiveDeliveryScreen> {
  static const Color brandColor = AppColors.brand;

  final _orderService = OrderService();
  StreamSubscription<Position>? _positionSub;
  // نخزّن socket service وقت initState بدل ما ننادي ref.read() جوا dispose() -
  // لأنه ref ممكن يصير invalid وقت تفكيك شجرة الـ widgets كاملة (StateError حقيقي).
  late final SocketService _socket;

  bool _isTracking = false;
  bool _isCompleting = false;
  String? _permissionError;

  OrderModel? _order;
  bool _loadingOrder = true;
  // ✅ توصية #8 - موقع السائق الحي محليًا (من نفس stream البث)، لرسمه على
  // خريطة المسار بدون انتظار جولة كاملة للسيرفر
  ll.LatLng? _driverPosition;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketServiceProvider);
    _start();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final result = await _orderService.getOrderTracking(widget.orderId);
    if (!mounted) return;
    setState(() {
      _order = result.order;
      _loadingOrder = false;
    });
  }

  LocationSettings _buildLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        intervalDuration: const Duration(seconds: 8),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'جاري توصيل طلبك...',
          notificationTitle: 'PickNGo - توصيل نشط',
          enableWakeLock: true,
        ),
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15);
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  Future<void> _start() async {
    await _socket.connect();
    _socket.joinOrder(widget.orderId);

    final granted = await _ensureLocationPermission();
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _permissionError = 'نحتاج إذن الوصول للموقع (بما فيه أثناء التصغير) لتتبع التوصيل. '
            'يرجى تفعيله من إعدادات الجهاز.';
      });
      return;
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(),
    ).listen((position) {
      _socket.emitDriverLocation(widget.orderId, position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _isTracking = true;
          _driverPosition = ll.LatLng(position.latitude, position.longitude);
        });
      }
    });
  }

  Future<void> _markDelivered() async {
    setState(() => _isCompleting = true);
    final result = await _orderService.updateOrderStatus(
      orderId: widget.orderId,
      status: 'Delivered',
    );
    if (!mounted) return;
    setState(() => _isCompleting = false);

    if (result.success) {
      await _positionSub?.cancel();
      _socket.leaveOrder(widget.orderId);
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isNotEmpty ? result.message : 'تعذر تحديث حالة الطلب',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _socket.leaveOrder(widget.orderId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DetailAppBar(title: 'توصيل نشط'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _order != null ? 'الطلب #${_order!.orderNumber}' : 'الطلب #${widget.orderId}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_loadingOrder)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        )
                      else if (_order != null) ...[
                        _buildRouteMap(_order!),
                        const SizedBox(height: 14),
                        _buildOrderDetailCard(_order!),
                      ],
                      const SizedBox(height: 14),
                      if (_permissionError != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_permissionError!, style: const TextStyle(color: Colors.redAccent)),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () async {
                                  await Geolocator.openAppSettings();
                                },
                                child: const Text('فتح إعدادات التطبيق'),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: brandColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isTracking ? Icons.gps_fixed : Icons.gps_not_fixed,
                                color: brandColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _isTracking
                                      ? 'جاري بث موقعك اللحظي للعميل...'
                                      : 'جاري تفعيل تتبع الموقع...',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isCompleting ? null : _markDelivered,
                  child: _isCompleting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('تم التسليم', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ توصية #8 - خريطة المسار الكامل: لو الطلب جزء من رحلة توصيل مجمّعة،
  // بترسم كل محطات الاستلام (group_stops، بترتيب pickup_sequence) + نقطة
  // التسليم النهائية؛ غير هيك بترجع لعرض متجر واحد → زبون (نفس نمط
  // order_tracking_screen.dart). خط المسار بيبدأ من موقع السائق الحي لو
  // متوفر (Geolocator)، وإلا من أول محطة.
  Marker _routePin(ll.LatLng point, Color color, IconData icon, {String? label}) {
    return Marker(
      point: point,
      width: 44,
      height: 44,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          Icon(icon, color: color, size: 28),
        ],
      ),
    );
  }

  List<ll.LatLng> _routeStopPoints(OrderModel order) {
    final stops = order.groupStops;
    if (stops != null && stops.isNotEmpty) {
      final sorted = [...stops]..sort((a, b) => a.pickupSequence.compareTo(b.pickupSequence));
      return sorted.map((s) => ll.LatLng(s.lat, s.lng)).toList();
    }
    if (order.storeLat != null && order.storeLng != null) {
      return [ll.LatLng(order.storeLat!, order.storeLng!)];
    }
    return [];
  }

  List<Marker> _buildRouteMarkers(OrderModel order) {
    final markers = <Marker>[];
    final stops = order.groupStops;
    if (stops != null && stops.isNotEmpty) {
      final sorted = [...stops]..sort((a, b) => a.pickupSequence.compareTo(b.pickupSequence));
      for (final s in sorted) {
        markers.add(_routePin(ll.LatLng(s.lat, s.lng), Colors.orange, Icons.storefront, label: '${s.pickupSequence}'));
      }
    } else if (order.storeLat != null && order.storeLng != null) {
      markers.add(_routePin(ll.LatLng(order.storeLat!, order.storeLng!), Colors.orange, Icons.storefront));
    }
    if (order.deliveryLat != null && order.deliveryLng != null) {
      markers.add(_routePin(ll.LatLng(order.deliveryLat!, order.deliveryLng!), Colors.redAccent, Icons.location_on));
    }
    if (_driverPosition != null) {
      markers.add(_routePin(_driverPosition!, brandColor, Icons.delivery_dining));
    }
    return markers;
  }

  List<Polyline> _buildRoutePolylines(OrderModel order) {
    final points = <ll.LatLng>[
      ?_driverPosition,
      ..._routeStopPoints(order),
      if (order.deliveryLat != null && order.deliveryLng != null) ll.LatLng(order.deliveryLat!, order.deliveryLng!),
    ];
    if (points.length < 2) return [];
    return [Polyline(points: points, color: brandColor.withValues(alpha: 0.55), strokeWidth: 3.5)];
  }

  ll.LatLng _routeInitialCenter(OrderModel order) {
    if (_driverPosition != null) return _driverPosition!;
    final stops = _routeStopPoints(order);
    if (stops.isNotEmpty) return stops.first;
    if (order.deliveryLat != null && order.deliveryLng != null) {
      return ll.LatLng(order.deliveryLat!, order.deliveryLng!);
    }
    return const ll.LatLng(31.9, 35.2);
  }

  Widget _buildRouteMap(OrderModel order) {
    final hasAnyPoint = _routeStopPoints(order).isNotEmpty ||
        (order.deliveryLat != null && order.deliveryLng != null) ||
        _driverPosition != null;
    if (!hasAnyPoint) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          options: MapOptions(initialCenter: _routeInitialCenter(order), initialZoom: 13),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.pickngo.app',
            ),
            PolylineLayer(polylines: _buildRoutePolylines(order)),
            MarkerLayer(markers: _buildRouteMarkers(order)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetailCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_outlined, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.storeName ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.deliveryAddress,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'طريقة الدفع: ${order.paymentMethod} • الإجمالي: ₪${order.finalAmount.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            ],
          ),
          if (order.items.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${item.quantity}x ${item.name}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
          if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sticky_note_2_outlined, size: 18, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.specialInstructions!,
                    style: TextStyle(color: Colors.orange[900], fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
