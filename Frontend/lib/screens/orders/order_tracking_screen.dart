// lib/screens/orders/order_tracking_screen.dart
//
// شاشة تتبّع لحظي كاملة لطلب واحد: خريطة توضح المتجر/السائق/الزبون بخط
// سير، بطاقة السائق (صورة، اسم، شركته، اتصال مباشر)، و Story timeline
// لمراحل الطلب بالوقت الفعلي (للمراحل يلي خلصت) والوقت المتوقع (للجايات).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../services/socket_service.dart';
import '../../core/theme/app_themes.dart';
import '../../widgets/main_layout.dart';

const List<String> _kOrderStages = ['Pending', 'Confirmed', 'Preparing', 'Ready', 'PickedUp', 'Delivered'];

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  static const Color brandColor = AppColors.brand;

  final _orderService = OrderService();
  final MapController _mapController = MapController();
  // نخزّن الـ socket service وقت initState بدل ما ننادي ref.read() جوا
  // dispose() - لأنه ref ممكن يصير invalid وقت تفكيك شجرة الـ widgets كاملة
  // (مثلاً hot restart أو إغلاق التطبيق)، وهاد كان يسبب StateError حقيقي.
  late final SocketService _socket;

  OrderModel? _order;
  bool _isLoading = true;
  String? _error;
  LatLng? _driverPosition;
  String _status = 'Pending';
  bool _driverPhotoFailed = false;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketServiceProvider);
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _orderService.getOrderTracking(widget.orderId);
    if (!mounted) return;

    if (!result.success || result.order == null) {
      setState(() {
        _isLoading = false;
        _error = result.message.isNotEmpty ? result.message : 'تعذر تحميل بيانات التتبع';
      });
      return;
    }

    final order = result.order!;
    setState(() {
      _order = order;
      _status = order.status;
      _isLoading = false;
      if (order.driverCurrentLat != null && order.driverCurrentLng != null) {
        _driverPosition = LatLng(order.driverCurrentLat!, order.driverCurrentLng!);
      }
      _driverPhotoFailed = false;
    });

    await _socket.connect();
    _socket.joinOrder(widget.orderId);

    _socket.onDriverLocation((event) {
      if (event.orderId != widget.orderId || !mounted) return;
      setState(() => _driverPosition = LatLng(event.lat, event.lng));
      _mapController.move(_driverPosition!, _mapController.camera.zoom);
    });

    _socket.onOrderStatus((event) {
      if (event.orderId != widget.orderId || !mounted) return;
      setState(() => _status = event.status);
      // ✅ نعيد تحميل بيانات التتبع كاملة لما الحالة تتغير عشان ناخد status_history/eta المحدّثين
      _load();
    });
  }

  @override
  void dispose() {
    _socket.offDriverLocation();
    _socket.offOrderStatus();
    _socket.leaveOrder(widget.orderId);
    super.dispose();
  }

  Future<void> _callDriver(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    bool launched = false;
    try {
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri);
      }
    } catch (_) {
      launched = false;
    }
    if (!mounted || launched) return;
    // ✅ بعض المنصات (خصوصًا الويب على ديسكتوب) ما عندها معالج tel: مسجّل -
    // منرجع للمستخدم رقم الهاتف بدل ما الزر يبين معطّل بصمت
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('لا يمكن فتح تطبيق الاتصال تلقائيًا - رقم السائق: $phone')),
    );
  }

  LatLng _initialTarget() {
    if (_driverPosition != null) return _driverPosition!;
    if (_order?.storeLat != null && _order?.storeLng != null) {
      return LatLng(_order!.storeLat!, _order!.storeLng!);
    }
    if (_order?.deliveryLat != null && _order?.deliveryLng != null) {
      return LatLng(_order!.deliveryLat!, _order!.deliveryLng!);
    }
    return const LatLng(31.9, 35.2);
  }

  Marker _pinMarker(LatLng point, Color color, IconData icon) {
    return Marker(
      point: point,
      width: 40,
      height: 40,
      child: Icon(icon, color: color, size: 36),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    final order = _order;
    if (order == null) return markers;

    if (order.storeLat != null && order.storeLng != null) {
      markers.add(_pinMarker(LatLng(order.storeLat!, order.storeLng!), Colors.orange, Icons.storefront));
    }
    if (order.deliveryLat != null && order.deliveryLng != null) {
      markers.add(_pinMarker(LatLng(order.deliveryLat!, order.deliveryLng!), Colors.redAccent, Icons.location_on));
    }
    if (_driverPosition != null) {
      markers.add(_pinMarker(_driverPosition!, brandColor, Icons.delivery_dining));
    }
    return markers;
  }

  List<Polyline> _buildRoute() {
    final order = _order;
    if (order == null) return [];
    final storePoint =
        (order.storeLat != null && order.storeLng != null) ? LatLng(order.storeLat!, order.storeLng!) : null;
    final customerPoint =
        (order.deliveryLat != null && order.deliveryLng != null) ? LatLng(order.deliveryLat!, order.deliveryLng!) : null;

    // ✅ لما السائق يصير طريقه فعليًا، الخط المهم هو "الباقي من الرحلة"
    // (موقعه الحالي → الزبون) مش خط ثابت من المتجر - غير هيك، خط توقعي
    // بسيط من المتجر للزبون قبل ما يتحرك السائق أصلاً.
    final points = _driverPosition != null
        ? [_driverPosition!, ?customerPoint]
        : [?storePoint, ?customerPoint];

    if (points.length < 2) return [];
    return [
      Polyline(points: points, color: brandColor.withValues(alpha: 0.55), strokeWidth: 3.5),
    ];
  }

  String _statusLabel(String status) {
    const labels = {
      'Pending': 'بانتظار تأكيد المتجر',
      'Confirmed': 'تم تأكيد الطلب',
      'Preparing': 'جاري التحضير',
      'Ready': 'جاهز - بانتظار سائق',
      'PickedUp': 'السائق في الطريق إليك',
      'Delivered': 'تم التسليم',
      'Cancelled': 'ملغى',
      'Refunded': 'مسترجع',
    };
    return labels[status] ?? status;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Confirmed':
      case 'Preparing':
        return Colors.blue;
      case 'Ready':
      case 'PickedUp':
        return const Color(0xFFA855F7);
      case 'Delivered':
        return brandColor;
      case 'Cancelled':
      case 'Refunded':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCustomer = ref.watch(authProvider).user?.role == 'Customer';

    // ✅ MainLayout/AppHeader مبني خصيصًا للزبون - لوحات Admin/Driver/Business
    // (وهاي الشاشة بيوصلها Driver أيضًا أثناء التوصيل) لازم تضل بنفس
    // AppBar+Drawer الحالي تمامًا بدون أي تغيير.
    if (isCustomer) {
      return MainLayout(
        builder: (context, isWeb, padding, width) => _buildBody(context, showTitle: true),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        title: Text(_order != null ? 'تتبع ${_order!.orderNumber}' : 'تتبع الطلب'),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context, {bool showTitle = false}) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: TextStyle(color: Colors.grey[600])),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showTitle)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Text(
                            _order != null ? 'تتبع ${_order!.orderNumber}' : 'تتبع الطلب',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        color: _statusColor(_status).withValues(alpha: 0.08),
                        child: Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, color: _statusColor(_status)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _statusLabel(_status),
                                style: TextStyle(color: _statusColor(_status), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 260,
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(initialCenter: _initialTarget(), initialZoom: 14),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.pickngo.app',
                            ),
                            PolylineLayer(polylines: _buildRoute()),
                            MarkerLayer(markers: _buildMarkers()),
                          ],
                        ),
                      ),
                      if (_order?.eta != null) _buildEtaCard(),
                      if (_order?.driverId != null) _buildDriverCard(),
                      _buildTimeline(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
  }

  Widget _buildEtaCard() {
    final eta = _order!.eta!;
    final arrival = eta.estimatedDeliveryAt;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brandColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: brandColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الوصول المتوقع خلال ${eta.totalRemainingMin} دقيقة',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (arrival != null)
                  Text(
                    'حوالي الساعة ${TimeOfDay.fromDateTime(arrival.toLocal()).format(context)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                Text(
                  eta.basedOnHistory
                      ? 'مبني على متوسط ${eta.historySampleSize} طلب سابق لنفس المتجر'
                      : 'تقدير مبدئي (لا يوجد سجل كافٍ لهذا المتجر بعد)',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                if (eta.driverActiveLoad > 0)
                  Text(
                    'قد يتأخر قليلاً - السائق يعمل حاليًا على ${eta.driverActiveLoad} طلب آخر',
                    style: TextStyle(color: Colors.orange[700], fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard() {
    final order = _order!;
    final hasPhoto = order.driverPhoto != null && order.driverPhoto!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: brandColor.withValues(alpha: 0.1),
            backgroundImage: (hasPhoto && !_driverPhotoFailed) ? NetworkImage(order.driverPhoto!) : null,
            onBackgroundImageError: (hasPhoto && !_driverPhotoFailed)
                ? (_, _) => setState(() => _driverPhotoFailed = true)
                : null,
            child: (!hasPhoto || _driverPhotoFailed) ? Icon(Icons.person, color: brandColor, size: 26) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.driverName ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (order.driverVehicleType != null && order.driverVehicleType!.isNotEmpty) order.driverVehicleType!,
                    if (order.driverCompanyName != null && order.driverCompanyName!.isNotEmpty) order.driverCompanyName!,
                  ].join(' • '),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          if (order.driverPhone != null && order.driverPhone!.isNotEmpty)
            InkWell(
              onTap: () => _callDriver(order.driverPhone!),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: brandColor, shape: BoxShape.circle),
                child: const Icon(Icons.call, color: Colors.white, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final order = _order;
    if (order == null) return const SizedBox.shrink();

    if (_status == 'Cancelled' || _status == 'Refunded') {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text(_statusLabel(_status), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final historyByStatus = <String, DateTime?>{};
    for (final entry in order.statusHistory) {
      historyByStatus[entry.status] = entry.at;
    }

    final currentIndex = _kOrderStages.indexOf(_status).clamp(0, _kOrderStages.length - 1);
    final durationByStage = <String, int>{
      'Preparing': order.eta?.preparingMin ?? 0,
      'Ready': order.eta?.pickupMin ?? 0,
      'PickedUp': order.eta?.deliveryMin ?? 0,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('مراحل الطلب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          ...List.generate(_kOrderStages.length, (i) {
            final stage = _kOrderStages[i];
            final isDone = i < currentIndex || (i == currentIndex && _status == 'Delivered');
            final isCurrent = i == currentIndex && _status != 'Delivered';
            final isLast = i == _kOrderStages.length - 1;
            final at = historyByStatus[stage];
            final estimateMin = durationByStage[stage];

            return _timelineRow(
              label: _statusLabel(stage),
              isDone: isDone,
              isCurrent: isCurrent,
              isLast: isLast,
              time: at != null ? TimeOfDay.fromDateTime(at.toLocal()).format(context) : null,
              estimateMin: (!isDone && estimateMin != null && estimateMin > 0) ? estimateMin : null,
            );
          }),
        ],
      ),
    );
  }

  Widget _timelineRow({
    required String label,
    required bool isDone,
    required bool isCurrent,
    required bool isLast,
    String? time,
    int? estimateMin,
  }) {
    final Color dotColor = isDone || isCurrent ? brandColor : Colors.grey.shade300;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? brandColor : Colors.white,
                  border: Border.all(color: dotColor, width: 2),
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : isCurrent
                        ? Padding(
                            padding: const EdgeInsets.all(5),
                            child: CircularProgressIndicator(strokeWidth: 2, color: brandColor),
                          )
                        : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: isDone ? brandColor : Colors.grey.shade300),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13,
                      color: isDone || isCurrent
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : Colors.grey[500],
                    ),
                  ),
                  if (time != null)
                    Text(time, style: TextStyle(color: Colors.grey[500], fontSize: 12))
                  else if (estimateMin != null)
                    Text('~$estimateMin د', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
