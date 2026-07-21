// lib/screens/driver/group_delivery_screen.dart
//
// Grouped Delivery (Smart Order Clustering): شاشة "التوصيل النشط" لرحلة
// توصيل مجمّعة - بدل ما السائق يشوف عدة طلبات منفصلة، بيشوف رحلة وحدة فيها
// أكتر من متجر بترتيب استلام واضح، وبعدين تسليم واحد للعميل. نفس منطق بث
// الموقع اللحظي المستخدم بـ active_delivery_screen.dart (Socket.io per-order
// room) بس مكرر لكل طلب عضو بالمجموعة.
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/socket_service.dart';
import '../../core/theme/app_themes.dart';
import '../../widgets/detail_app_bar.dart';

class GroupDeliveryScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDeliveryScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDeliveryScreen> createState() => _GroupDeliveryScreenState();
}

class _GroupDeliveryScreenState extends ConsumerState<GroupDeliveryScreen> {
  static const Color brandColor = AppColors.brand;

  final _orderService = OrderService();
  StreamSubscription<Position>? _positionSub;
  late final SocketService _socket;

  DeliveryGroupDetailModel? _group;
  bool _isLoading = true;
  bool _isTracking = false;
  String? _permissionError;
  final Set<String> _busyOrderIds = {};
  bool _isCompletingDelivery = false;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketServiceProvider);
    _loadGroup();
    _startLocationTracking();
  }

  Future<void> _loadGroup() async {
    setState(() => _isLoading = true);
    final result = await _orderService.getDeliveryGroupDetail(widget.groupId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success) _group = result.group;
    });
    if (result.success && result.group != null) {
      for (final store in result.group!.stores) {
        _socket.joinOrder(store.orderId);
      }
    }
  }

  LocationSettings _buildLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        intervalDuration: const Duration(seconds: 8),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'جاري توصيل مجموعة طلبات...',
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

  Future<void> _startLocationTracking() async {
    await _socket.connect();

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
      // ✅ بث نفس الموقع اللحظي لكل طلب عضو بالمجموعة (كل واحد إله غرفة
      // تتبّع مستقلة بالسيرفر - راجع orderTrackingHandler.js)
      final stores = _group?.stores ?? [];
      for (final store in stores) {
        _socket.emitDriverLocation(store.orderId, position.latitude, position.longitude);
      }
      if (mounted) setState(() => _isTracking = true);
    });
  }

  Future<void> _markPickedUp(GroupStoreModel store) async {
    setState(() => _busyOrderIds.add(store.orderId));
    final result = await _orderService.updateOrderStatus(orderId: store.orderId, status: 'PickedUp');
    if (!mounted) return;
    setState(() => _busyOrderIds.remove(store.orderId));

    if (result.success) {
      await _loadGroup();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message.isNotEmpty ? result.message : 'تعذر تحديث حالة الاستلام')),
      );
    }
  }

  Future<void> _markDelivered() async {
    final stores = _group?.stores ?? [];
    final anyNotDelivered = stores.firstWhere(
      (s) => s.orderStatus != 'Delivered',
      orElse: () => stores.first,
    );

    setState(() => _isCompletingDelivery = true);
    final result = await _orderService.updateOrderStatus(orderId: anyNotDelivered.orderId, status: 'Delivered');
    if (!mounted) return;
    setState(() => _isCompletingDelivery = false);

    if (result.success) {
      await _positionSub?.cancel();
      for (final store in stores) {
        _socket.leaveOrder(store.orderId);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message.isNotEmpty ? result.message : 'تعذر تحديث حالة الطلب')),
      );
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    for (final store in _group?.stores ?? <GroupStoreModel>[]) {
      _socket.leaveOrder(store.orderId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stores = [...(_group?.stores ?? <GroupStoreModel>[])]
      ..sort((a, b) => a.pickupSequence.compareTo(b.pickupSequence));
    final allPickedUp = stores.isNotEmpty &&
        stores.every((s) => s.orderStatus == 'PickedUp' || s.orderStatus == 'Delivered');

    return Scaffold(
      appBar: DetailAppBar(title: 'مجموعة توصيل #${widget.groupId}'),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _group == null
                ? const Center(child: Text('تعذر تحميل تفاصيل المجموعة'))
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                  onPressed: () async => Geolocator.openAppSettings(),
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
                                        ? 'جاري بث موقعك اللحظي للعملاء...'
                                        : 'جاري تفعيل تتبع الموقع...',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                        const Text('ترتيب الاستلام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView(
                            children: [
                              ...stores.map(_buildStoreTile),
                              const SizedBox(height: 12),
                              _buildDropoffTile(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: (allPickedUp && !_isCompletingDelivery) ? _markDelivered : null,
                            child: _isCompletingDelivery
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    allPickedUp ? 'تم التسليم للعميل' : 'استلم من كل المتاجر أولاً',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildStoreTile(GroupStoreModel store) {
    final done = store.orderStatus == 'PickedUp' || store.orderStatus == 'Delivered';
    final isBusy = _busyOrderIds.contains(store.orderId);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: (done ? brandColor : Colors.grey).withValues(alpha: 0.12),
            child: done
                ? Icon(Icons.check, size: 16, color: brandColor)
                : Text('${store.pickupSequence}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.name ?? 'متجر', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                if (store.address != null)
                  Text(store.address!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          if (!done)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isBusy ? null : () => _markPickedUp(store),
              child: isBusy
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('استلمت', style: TextStyle(fontSize: 12)),
            )
          else
            Text('تم الاستلام', style: TextStyle(color: brandColor, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDropoffTile() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brandColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.person_pin_circle_outlined, color: brandColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('التسليم للعميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                if (_group?.deliveryAddress != null)
                  Text(_group!.deliveryAddress!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
