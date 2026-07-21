// lib/screens/driver/driver_home_screen.dart
//
// لوحة السائق: تفعيل/إيقاف استقبال الطلبات (Driver Availability) + طلبات
// متاحة للقبول (Ready + بدون سائق) + توصيلاتي النشطة (PickedUp) + سجل
// التوصيلات. أول شاشة فعلية لدور Driver بالتطبيق.
//
// ✅ إعادة تصميم بصري (UI/UX فقط) - نفس الـ Providers/Services/Routes/API
// بالضبط. الإضافات الوحيدة على منطق العمل: (1) جلب DriverPerformanceModel
// عبر DriverService.getMyPerformance() الموجودة أصلاً (تُستخدم أصلاً بشاشة
// "أدائي") لعرض نسبة القبول/إجمالي التوصيلات هون كمان، (2) جلب تتبّع الطلب
// النشط عبر OrderService.getOrderTracking() الموجودة أصلاً (تُستخدمها
// active_delivery_screen.dart) لعرض معاينة خريطة مصغّرة، (3) تخزين آخر عرض
// Smart Assignment وصل (نفس الكائن اللي أصلاً بيتعرض بالنافذة المنبثقة) محليًا
// لعرض عدّاد تنازلي حقيقي على بطاقته بقائمة "طلبات متاحة"، و(4) "تجاهل" على
// مستوى الواجهة فقط (Set محلي، بيصفّر مع أي تحديث) - بدون أي نداء API جديد.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../core/theme/app_themes.dart';
import '../../data/models/analytics_model.dart';
import '../../data/models/offer_model.dart';
import '../../data/models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../services/driver_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/driver_drawer.dart';
import '../../widgets/driver_header.dart';
import '../landing/landing_screen.dart';
import 'active_delivery_screen.dart';
import 'group_delivery_screen.dart';
import 'smart_offer_dialog.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  static const Color brandColor = AppColors.brand;

  final _orderService = OrderService();
  final _driverService = DriverService();
  // نخزّن socket service وقت initState بدل ما ننادي ref.read() جوا dispose() -
  // لأنه ref ممكن يصير invalid وقت تفكيك شجرة الـ widgets كاملة (StateError حقيقي).
  late final SocketService _socket;
  Timer? _pingTimer;

  List<OrderModel> _availableOrders = [];
  List<OrderModel> _myOrders = [];
  bool _isLoading = true;
  final Set<String> _acceptingIds = {};
  // ✅ "تجاهل" بصري بس (لا يوجد مفهوم "رفض" لطلب من مجمّع الطلبات المتاحة
  // بالباك إند - عكس عرض Smart Assignment يلي عنده respond حقيقي) - يخفي
  // الكارت من القائمة محليًا، ويرجع يظهر تلقائيًا مع أي _loadAll() جديد.
  final Set<String> _dismissedIds = {};

  DriverAvailabilityStatus _myStatus = DriverAvailabilityStatus.offline;
  bool _statusChanging = false;

  // ✅ Phase 3 - Smart Assignment: نافذة عرض تعيين ذكي معلّق (لو في) - علم
  // بسيط يمنع فتح نافذتين فوق بعض لو وصل حدث تاني أو رجّع fallback نفس العرض
  bool _offerDialogShowing = false;
  // ✅ نفس عرض Smart Assignment المعروض بالنافذة المنبثقة - نخزّنه هون كمان
  // (بدون ما نغيّر سلوك النافذة) عشان نقدر نعرض عدّاده التنازلي الحقيقي على
  // بطاقة الطلب المطابقة بقائمة "طلبات متاحة" لو كانت موجودة فيها.
  DeliveryOfferModel? _pendingOffer;

  // ✅ إحصائيات الأداء (نسبة قبول العروض، إجمالي التوصيلات) - من نفس
  // DriverService.getMyPerformance() المستخدمة أصلاً بشاشة "أدائي"
  DriverPerformanceModel? _performance;

  // ✅ معاينة خريطة مصغّرة لأول توصيلة نشطة - من نفس
  // OrderService.getOrderTracking() المستخدمة أصلاً بشاشة التوصيل النشط
  OrderModel? _activeMapOrder;
  bool _loadingMapOrder = false;

  @override
  void initState() {
    super.initState();
    _myStatus = parseDriverAvailability(ref.read(authProvider).user?.driverStatus);
    _loadAll();
    _connectStatusSocket();
    _checkPendingOffer();
    if (_myStatus != DriverAvailabilityStatus.offline) _startLocationPing();
  }

  Future<void> _connectStatusSocket() async {
    _socket = ref.read(socketServiceProvider);
    await _socket.connect();
    final myId = ref.read(authProvider).user?.userId.toString();
    _socket.onDriverStatus((event) {
      if (!mounted || event.driverId != myId) return;
      setState(() => _myStatus = parseDriverAvailability(event.status));
    });
    // ✅ Phase 3 - Smart Assignment: بث لحظي لعرض تعيين جديد وصل لهاد السائق
    _socket.onOrderOffer((offer) {
      if (!mounted) return;
      setState(() => _pendingOffer = offer);
      _showOfferDialog(offer);
    });
  }

  // ✅ يغطّي حالة إنو تطبيق السائق كان مقفول/غير متصل لما وصل بث order:offer -
  // بيتأكد وقت فتح الشاشة إذا في عرض معلّق أصلًا وينده عليه محليًا
  Future<void> _checkPendingOffer() async {
    final result = await _orderService.getMyPendingOffer();
    if (!mounted || !result.success || result.offer == null) return;
    setState(() => _pendingOffer = result.offer);
    _showOfferDialog(result.offer!);
  }

  void _showOfferDialog(DeliveryOfferModel offer) {
    if (_offerDialogShowing) return;
    _offerDialogShowing = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SmartOfferDialog(
        offer: offer,
        onAccept: () => _respondToOffer(offer, 'accept'),
        onReject: () => _respondToOffer(offer, 'reject'),
      ),
    ).then((_) {
      _offerDialogShowing = false;
      if (mounted) setState(() => _pendingOffer = null);
    });
  }

  // ✅ يرجّع true لو الدايلوغ لازم ينقفل (نجح الرد، أو العرض خلص/انسحب أصلًا)،
  // و false لو لازم يضل مفتوح (خطأ شبكة عابر - نسيب السائق يجرب تاني)
  Future<bool> _respondToOffer(DeliveryOfferModel offer, String action) async {
    final result = await respondToDeliveryOffer(_orderService, offer, action);

    if (!mounted) return true;

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message.isNotEmpty ? result.message : 'تعذر إتمام العملية')),
      );
      // ✅ لو العرض أصلًا خلص وقته أو انسحب (سائق تاني قبله/الـ sweep عالجه)،
      // ما في داعي نخلي النافذة عالقة - بس بالنسبة لأي خطأ تاني (شبكة مثلًا)
      // نسيب السائق يجرب يضغط تاني
      return result.code == 'EXPIRED' || result.code == 'NOT_OFFERED';
    }

    await _loadAll();
    if (!mounted) return true;

    if (action == 'accept') {
      if (offer.isGroup) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GroupDeliveryScreen(groupId: offer.respondTargetId)),
        ).then((_) => _loadAll());
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ActiveDeliveryScreen(orderId: offer.respondTargetId)),
        ).then((_) => _loadAll());
      }
    }
    return true;
  }

  void _startLocationPing() {
    _pingTimer?.cancel();
    _sendLocationPing();
    _pingTimer = Timer.periodic(const Duration(seconds: 45), (_) => _sendLocationPing());
  }

  void _stopLocationPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<void> _sendLocationPing() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      await _driverService.pingLocation(position.latitude, position.longitude);
    } catch (_) {
      // ✅ فشل ping واحد مش خطير - الـ Timer رح يحاول تاني بعد 45 ثانية.
      // لو استمر الانقطاع، النظام بالسيرفر رح يرجّع السائق Offline تلقائيًا.
    }
  }

  Future<void> _toggleOnline(bool goOnline) async {
    setState(() => _statusChanging = true);
    final result = await _driverService.setMyStatus(
      goOnline ? DriverAvailabilityStatus.available : DriverAvailabilityStatus.offline,
    );
    if (!mounted) return;
    setState(() => _statusChanging = false);

    if (result.success && result.status != null) {
      setState(() => _myStatus = result.status!);
      if (goOnline) {
        _startLocationPing();
      } else {
        _stopLocationPing();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message.isNotEmpty ? result.message : 'تعذر تحديث الحالة')),
      );
    }
  }

  @override
  void dispose() {
    _stopLocationPing();
    _socket.offDriverStatus();
    _socket.offOrderOffer();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final ordersFuture = Future.wait([
      _orderService.getAvailableOrders(),
      _orderService.getMyOrders(),
    ]);
    final performanceFuture = _driverService.getMyPerformance();

    final results = await ordersFuture;
    final performance = await performanceFuture;
    if (!mounted) return;
    final available = results[0];
    final mine = results[1];
    setState(() {
      _isLoading = false;
      if (available.success) _availableOrders = available.orders;
      if (mine.success) _myOrders = mine.orders;
      _performance = performance;
      _dismissedIds.clear();
    });
    _loadActiveMapPreview();
  }

  // ✅ أول توصيلة نشطة (فردية أو مجمّعة) - نفس معيار activeMine/activeGroupReps
  // بالـ build(). لو موجودة، نجيب تفاصيل التتبّع الكاملة (فيها الإحداثيات)
  // لعرض معاينة خريطة مصغّرة أعلى قسم "توصيلاتي النشطة".
  OrderModel? _findFirstActiveOrder() {
    for (final o in _myOrders) {
      if (o.status != 'PickedUp') continue;
      if (o.isGrouped && (o.groupStatus == 'Completed' || o.groupStatus == 'Cancelled')) continue;
      return o;
    }
    return null;
  }

  Future<void> _loadActiveMapPreview() async {
    final target = _findFirstActiveOrder();
    if (target == null) {
      if (mounted) setState(() => _activeMapOrder = null);
      return;
    }
    setState(() => _loadingMapOrder = true);
    final result = await _orderService.getOrderTracking(target.id);
    if (!mounted) return;
    setState(() {
      _loadingMapOrder = false;
      _activeMapOrder = result.success ? result.order : null;
    });
  }

  void _dismissOrder(String id) {
    setState(() => _dismissedIds.add(id));
  }

  Future<void> _accept(OrderModel order) async {
    setState(() => _acceptingIds.add(order.id));
    final result = await _orderService.updateOrderStatus(
      orderId: order.id,
      status: 'PickedUp',
    );
    if (!mounted) return;
    setState(() => _acceptingIds.remove(order.id));

    if (result.success) {
      await _loadAll();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ActiveDeliveryScreen(orderId: order.id)),
      ).then((_) => _loadAll());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message.isNotEmpty ? result.message : 'تعذر قبول الطلب'),
        ),
      );
    }
  }

  // ✅ Grouped Delivery: قبول رحلة توصيل مجمّعة كاملة (بدل قبول طلب واحد) -
  // ما بيغيّر حالة أي طلب، بس بيثبّت السائق على الرحلة كاملة
  Future<void> _acceptGroup(OrderModel rep) async {
    final groupId = rep.deliveryGroupId!;
    setState(() => _acceptingIds.add(groupId));
    final result = await _orderService.acceptDeliveryGroup(groupId);
    if (!mounted) return;
    setState(() => _acceptingIds.remove(groupId));

    if (result.success) {
      await _loadAll();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupDeliveryScreen(groupId: groupId)),
      ).then((_) => _loadAll());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message.isNotEmpty ? result.message : 'تعذر قبول المجموعة'),
        ),
      );
    }
  }

  Future<void> _logout() async {
    _stopLocationPing();
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Grouped Delivery: كل الطلبات الأعضاء بنفس المجموعة بترجع كل واحدة
    // بـ groupStores الكاملة (نفس المحتوى) - فمنكتفي بممثل واحد لكل group_id
    // بدل ما نعرض بطاقة مكررة لكل طلب لحاله.
    final availableGroupReps = <String, OrderModel>{};
    final availableSingles = <OrderModel>[];
    for (final o in _availableOrders) {
      if (o.isGrouped) {
        availableGroupReps.putIfAbsent(o.deliveryGroupId!, () => o);
      } else {
        availableSingles.add(o);
      }
    }
    // ✅ "تجاهل" (واجهة فقط) - يفلتر بس، ما بيغيّر أي بيانات فعلية
    final visibleGroupReps = Map<String, OrderModel>.fromEntries(
      availableGroupReps.entries.where((e) => !_dismissedIds.contains(e.key)),
    );
    final visibleSingles = availableSingles.where((o) => !_dismissedIds.contains(o.id)).toList();
    final hadAvailable = availableGroupReps.isNotEmpty || availableSingles.isNotEmpty;
    final hasVisibleAvailable = visibleGroupReps.isNotEmpty || visibleSingles.isNotEmpty;

    final myGrouped = _myOrders.where((o) => o.isGrouped).toList();
    final myUngrouped = _myOrders.where((o) => !o.isGrouped).toList();

    final activeMine = myUngrouped.where((o) => o.status == 'PickedUp').toList();
    final pastMine = myUngrouped
        .where((o) => o.status == 'Delivered' || o.status == 'Cancelled')
        .toList();

    // ✅ حالة الرحلة (groupStatus) من الباك إند هي مصدر الحقيقة لتصنيف
    // نشطة/سابقة - مش لازم نفحص حالة كل طلب عضو لحاله
    final activeGroupReps = <String, OrderModel>{};
    final pastGroupReps = <String, OrderModel>{};
    for (final o in myGrouped) {
      final id = o.deliveryGroupId!;
      if (o.groupStatus == 'Completed' || o.groupStatus == 'Cancelled') {
        pastGroupReps.putIfAbsent(id, () => o);
      } else {
        activeGroupReps.putIfAbsent(id, () => o);
      }
    }

    final now = DateTime.now();
    final todayDelivered = _myOrders.where((o) {
      final t = o.orderTime;
      return o.status == 'Delivered' &&
          t != null &&
          t.year == now.year &&
          t.month == now.month &&
          t.day == now.day;
    }).toList();
    final todayTrips = todayDelivered.length;
    final todayEarnings = todayDelivered.fold<double>(0, (sum, o) => sum + o.deliveryFee);

    // ✅ اتجاه أرباح اليوم مقارنة بالأمس - محسوب من نفس _myOrders المحمّلة
    // أصلاً، بدون أي نداء إضافي
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayEarnings = _myOrders.where((o) {
      final t = o.orderTime;
      return o.status == 'Delivered' &&
          t != null &&
          t.year == yesterday.year &&
          t.month == yesterday.month &&
          t.day == yesterday.day;
    }).fold<double>(0, (sum, o) => sum + o.deliveryFee);
    String? earningsTrend;
    var earningsTrendPositive = true;
    if (yesterdayEarnings > 0) {
      final pct = ((todayEarnings - yesterdayEarnings) / yesterdayEarnings) * 100;
      earningsTrendPositive = pct >= 0;
      earningsTrend = '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}% مقابل الأمس';
    }

    // ✅ نفس نمط أرباح آخر 7 أيام المستخدم بشاشة الأرباح (driver_earnings_screen)
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekEarnings = _myOrders
        .where((o) => o.status == 'Delivered' && o.orderTime != null && o.orderTime!.isAfter(weekAgo))
        .fold<double>(0, (sum, o) => sum + o.deliveryFee);

    final activeCount = activeMine.length + activeGroupReps.length;
    final acceptanceRate = _performance?.smartAssignment.acceptanceRate;
    final weeklyDays = _weeklyDays();
    final weeklySeries = _weeklyEarningsSeries(weeklyDays);
    final user = ref.watch(authProvider).user;

    final content = Column(
      children: [
        LayoutBuilder(
          builder: (context, headerConstraints) {
            final isWide = headerConstraints.maxWidth > 900;
            final padding = isWide ? headerConstraints.maxWidth * 0.06 : 20.0;
            return DriverHeader(isWeb: isWide, padding: padding, onLogout: _logout);
          },
        ),
        Expanded(
          child: SafeArea(
            top: false,
            child: RefreshIndicator(
          onRefresh: _loadAll,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final padding = isWide ? constraints.maxWidth * 0.06 : 20.0;
              final contentWidth = constraints.maxWidth - padding * 2;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusRow(user?.city),
                        const SizedBox(height: 16),
                        _buildStatsGrid(
                          contentWidth.clamp(0, 1100),
                          todayEarnings: todayEarnings,
                          earningsTrend: earningsTrend,
                          earningsTrendPositive: earningsTrendPositive,
                          weekEarnings: weekEarnings,
                          todayTrips: todayTrips,
                          activeCount: activeCount,
                          acceptanceRate: acceptanceRate,
                        ),
                        const SizedBox(height: 20),
                        _buildWeeklyChartCard(weeklySeries, weeklyDays),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else ...[
                          if (activeGroupReps.isNotEmpty || activeMine.isNotEmpty) ...[
                            _sectionTitle('توصيلاتي النشطة', icon: Icons.local_shipping_rounded),
                            const SizedBox(height: 12),
                            if (_activeMapOrder != null || _loadingMapOrder) ...[
                              _buildActiveMapCard(),
                              const SizedBox(height: 12),
                            ],
                            ...activeGroupReps.values
                                .toList()
                                .asMap()
                                .entries
                                .map((e) => _FadeSlideIn(index: e.key, child: _buildGroupCard(e.value, isActive: true))),
                            ...activeMine
                                .asMap()
                                .entries
                                .map((e) => _FadeSlideIn(index: e.key, child: _buildActiveCard(e.value))),
                            const SizedBox(height: 24),
                          ],
                          _sectionTitle('طلبات متاحة', icon: Icons.list_alt_rounded),
                          const SizedBox(height: 12),
                          if (!hasVisibleAvailable)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.inbox_outlined, size: 34, color: Colors.grey[400]),
                                    const SizedBox(height: 10),
                                    Text(
                                      hadAvailable ? 'تم تجاهل كل الطلبات المتاحة - اسحب للتحديث' : 'لا توجد طلبات متاحة حاليًا',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            ...visibleGroupReps.values
                                .toList()
                                .asMap()
                                .entries
                                .map((e) => _FadeSlideIn(index: e.key, child: _buildGroupCard(e.value, isActive: false))),
                            ...visibleSingles
                                .asMap()
                                .entries
                                .map((e) => _buildAvailableCard(e.value, e.key)),
                          ],
                          if (pastGroupReps.isNotEmpty || pastMine.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _sectionTitle('سجل التوصيلات', icon: Icons.history_rounded),
                            const SizedBox(height: 12),
                            ...pastGroupReps.values.map(_buildGroupHistoryCard),
                            ...pastMine.map(_buildHistoryCard),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
            ),
          ),
        ),
      ],
    );

    // ✅ على الشاشات الواسعة (ديسكتوب/ويب) القائمة الجانبية بتصير ثابتة
    // (Row جنب المحتوى) بدل Drawer منبثق - نفس DriverSidebarContent بالضبط
    // (نفس buildDriverNavItems/authProvider)، بس معروضة بشكل مختلف. الموبايل
    // يضل بنفس سلوك الـ Drawer المنبثق تمامًا زي ما كان.
    return LayoutBuilder(
      builder: (context, outer) {
        final isDesktop = outer.maxWidth > 1000;
        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                const SizedBox(width: 264, child: DriverSidebarContent(bordered: true)),
                Expanded(child: content),
              ],
            ),
          );
        }
        return Scaffold(drawer: const DriverDrawer(), body: content);
      },
    );
  }

  // ✅ متسلسلة أرباح آخر 7 أيام (اليوم + الأيام الستة قبله) - محسوبة من
  // نفس _myOrders المحمّلة أصلاً، بدون أي نداء إضافي. تُستخدم لرسم عمود
  // "الأداء الأسبوعي" بشكل بياني حقيقي بدل رقم واحد مجمّع.
  List<DateTime> _weeklyDays() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) => startOfToday.subtract(Duration(days: 6 - i)));
  }

  List<double> _weeklyEarningsSeries(List<DateTime> days) {
    return days.map((day) {
      return _myOrders.where((o) {
        final t = o.orderTime;
        return o.status == 'Delivered' && t != null && t.year == day.year && t.month == day.month && t.day == day.day;
      }).fold<double>(0, (sum, o) => sum + o.deliveryFee);
    }).toList();
  }

  Widget _sectionTitle(String text, {required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 17, color: Colors.grey[700]),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatusRow(String? city) {
    final isBusy = _myStatus == DriverAvailabilityStatus.busy;
    final isOnline = _myStatus != DriverAvailabilityStatus.offline;

    late Color statusColor;
    late String statusLabel;
    late IconData statusIcon;
    switch (_myStatus) {
      case DriverAvailabilityStatus.available:
        statusColor = brandColor;
        statusLabel = 'متاح لاستقبال الطلبات';
        statusIcon = Icons.bolt_rounded;
        break;
      case DriverAvailabilityStatus.busy:
        statusColor = AppColors.accent;
        statusLabel = 'مشغول - طلب شغال حالياً';
        statusIcon = Icons.local_shipping_rounded;
        break;
      case DriverAvailabilityStatus.offline:
        statusColor = Colors.grey;
        statusLabel = 'غير متصل - ما رح توصلك طلبات';
        statusIcon = Icons.power_settings_new_rounded;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: isOnline
                  ? [BoxShadow(color: statusColor.withValues(alpha: 0.55), blurRadius: 6, spreadRadius: 1.2)]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Icon(statusIcon, size: 15, color: statusColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (city != null && city.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.place_outlined, size: 11, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Text(city, style: TextStyle(color: Colors.grey[600], fontSize: 10.5)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_statusChanging)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: isOnline,
                activeThumbColor: brandColor,
                onChanged: isBusy ? null : (v) => _toggleOnline(v),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════ Stats Dashboard ═══════════════════════════

  Widget _buildStatsGrid(
    double maxWidth, {
    required double todayEarnings,
    required String? earningsTrend,
    required bool earningsTrendPositive,
    required double weekEarnings,
    required int todayTrips,
    required int activeCount,
    required double? acceptanceRate,
  }) {
    final tiles = <Widget>[
      _StatCard(
        icon: Icons.payments_outlined,
        iconColor: AppColors.accent,
        value: '₪${todayEarnings.toStringAsFixed(2)}',
        label: 'أرباح اليوم',
        trend: earningsTrend,
        trendPositive: earningsTrendPositive,
      ),
      _StatCard(
        icon: Icons.calendar_view_week_outlined,
        iconColor: AppColors.secondaryBrand,
        value: '₪${weekEarnings.toStringAsFixed(2)}',
        label: 'أرباح الأسبوع',
      ),
      _StatCard(
        icon: Icons.delivery_dining_outlined,
        value: '$todayTrips',
        label: 'توصيلات اليوم',
      ),
      _StatCard(
        icon: Icons.local_shipping_outlined,
        iconColor: AppColors.tertiary,
        value: '$activeCount',
        label: 'طلبات نشطة',
      ),
      if (acceptanceRate != null)
        _StatCard(
          icon: Icons.thumb_up_outlined,
          iconColor: AppColors.success,
          value: '${acceptanceRate.toStringAsFixed(0)}%',
          label: 'نسبة قبول العروض',
        ),
      if (_performance != null)
        _StatCard(
          icon: Icons.emoji_events_outlined,
          iconColor: AppColors.warning,
          value: '${_performance!.completedOrders}',
          label: 'إجمالي التوصيلات',
        ),
    ];

    final columns = maxWidth > 820 ? 4 : (maxWidth > 560 ? 3 : 2);
    const gap = 12.0;
    final safeWidth = maxWidth <= 0 ? 320.0 : maxWidth;
    final tileWidth = (safeWidth - gap * (columns - 1)) / columns;

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final t in tiles) SizedBox(width: tileWidth < 100 ? safeWidth : tileWidth, child: t),
      ],
    );
  }

  // ═══════════════════════════ Weekly performance chart ═══════════════════════════

  static const _arabicWeekdayShort = ['اث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح']; // فهرسها DateTime.weekday - 1

  Widget _buildWeeklyChartCard(List<double> series, List<DateTime> days) {
    final maxVal = series.fold<double>(0, (m, v) => v > m ? v : m);
    final today = DateTime.now();

    return _HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: brandColor, size: 18),
              const SizedBox(width: 8),
              const Text('الأداء الأسبوعي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 20),
          if (maxVal == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('ما في أرباح مسجّلة آخر 7 أيام', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ),
            )
          else
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < series.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: _WeeklyBar(
                          ratio: maxVal > 0 ? series[i] / maxVal : 0,
                          valueLabel: series[i] > 0 ? '₪${series[i].toStringAsFixed(0)}' : '',
                          dayLabel: _arabicWeekdayShort[days[i].weekday - 1],
                          isToday: days[i].year == today.year && days[i].month == today.month && days[i].day == today.day,
                          color: brandColor,
                          delayMs: i * 60,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════ Active delivery map preview ═══════════════════════════

  Widget _buildActiveMapCard() {
    if (_loadingMapOrder) {
      return _HoverCard(
        child: const SizedBox(
          height: 90,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    final order = _activeMapOrder;
    if (order == null) return const SizedBox.shrink();

    // ✅ لأول محطة استلام - نفس المصدر المستخدم لكروت المجموعة (groupStores)
    // أو اسم المتجر للطلب الفردي، الاتنين حقول حقيقية بـ OrderModel
    String pickupLabel(OrderModel o) {
      final stores = o.groupStores;
      if (stores != null && stores.isNotEmpty) {
        final sorted = [...stores]..sort((a, b) => a.pickupSequence.compareTo(b.pickupSequence));
        return sorted.first.name ?? 'المتجر';
      }
      return o.storeName ?? 'المتجر';
    }

    Widget routeRow({required IconData icon, required String label, required String value}) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, size: 7, color: brandColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      );
    }

    final hasAnyPoint = _routeStopPoints(order).isNotEmpty ||
        (order.deliveryLat != null && order.deliveryLng != null);

    return _HoverCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ كارت "التوصيل النشط" الرئيسي - أخضر العلامة التجارية، بنفس
          // أسلوب الأرباح المميّزة بشاشة driver_earnings_screen (خلفية Brand
          // ملوّنة كاملة + رقم كبير أبيض)، مع مسار الاستلام/التسليم الحقيقي
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [brandColor, AppColors.brandDark],
              ),
              borderRadius: hasAnyPoint
                  ? const BorderRadius.vertical(top: Radius.circular(AppRadius.lg))
                  : BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('التوصيل النشط', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            '₪${order.deliveryFee.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: const Text(
                        'قيد التوصيل',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                routeRow(
                  icon: Icons.storefront_rounded,
                  label: 'الاستلام',
                  value: pickupLabel(order),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4.5),
                  child: SizedBox(
                    height: 16,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        3,
                        (_) => Container(width: 2, height: 3, color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                ),
                routeRow(
                  icon: Icons.location_on_rounded,
                  label: 'التسليم',
                  value: order.deliveryAddress,
                ),
              ],
            ),
          ),
          if (hasAnyPoint)
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: SizedBox(
                height: 170,
                width: double.infinity,
                child: IgnorePointer(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _routeInitialCenter(order),
                      initialZoom: 13,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    ),
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
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.eta?.totalRemainingMin != null) ...[
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 15, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'الوصول المتوقع خلال ${order.eta!.totalRemainingMin} دقيقة',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.fullscreen_rounded, size: 18),
                    label: const Text('فتح الخريطة الكاملة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: brandColor,
                      side: BorderSide(color: brandColor),
                    ),
                    onPressed: () {
                      if (order.isGrouped) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => GroupDeliveryScreen(groupId: order.deliveryGroupId!)),
                        ).then((_) => _loadAll());
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ActiveDeliveryScreen(orderId: order.id)),
                        ).then((_) => _loadAll());
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ نفس منطق رسم المسار المستخدم بـ active_delivery_screen.dart، بفرق
  // واحد: بدل ما نعتمد على بث موقع حي (Geolocator stream)، منستخدم
  // driver_current_lat/lng الجاهز من رد GET /:id/tracking نفسه - snapshot
  // وقت التحميل بدل تتبّع لحظي (مناسب لمعاينة بلوحة السائق، مش شاشة التتبّع
  // المخصّصة أصلاً للتتبّع اللحظي).
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

  Marker _routePin(ll.LatLng point, Color color, IconData icon, {String? label}) {
    return Marker(
      point: point,
      width: 38,
      height: 38,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          Icon(icon, color: color, size: 24),
        ],
      ),
    );
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
    if (order.driverCurrentLat != null && order.driverCurrentLng != null) {
      markers.add(_routePin(ll.LatLng(order.driverCurrentLat!, order.driverCurrentLng!), brandColor, Icons.delivery_dining));
    }
    return markers;
  }

  List<Polyline> _buildRoutePolylines(OrderModel order) {
    final points = <ll.LatLng>[
      if (order.driverCurrentLat != null && order.driverCurrentLng != null)
        ll.LatLng(order.driverCurrentLat!, order.driverCurrentLng!),
      ..._routeStopPoints(order),
      if (order.deliveryLat != null && order.deliveryLng != null) ll.LatLng(order.deliveryLat!, order.deliveryLng!),
    ];
    if (points.length < 2) return [];
    return [Polyline(points: points, color: brandColor.withValues(alpha: 0.55), strokeWidth: 3.5)];
  }

  ll.LatLng _routeInitialCenter(OrderModel order) {
    if (order.driverCurrentLat != null && order.driverCurrentLng != null) {
      return ll.LatLng(order.driverCurrentLat!, order.driverCurrentLng!);
    }
    final stops = _routeStopPoints(order);
    if (stops.isNotEmpty) return stops.first;
    if (order.deliveryLat != null && order.deliveryLng != null) {
      return ll.LatLng(order.deliveryLat!, order.deliveryLng!);
    }
    return const ll.LatLng(31.9, 35.2);
  }

  // ═══════════════════════════ Order cards ═══════════════════════════

  Widget _buildAvailableCard(OrderModel order, int index) {
    final isAccepting = _acceptingIds.contains(order.id);
    final matchingOffer =
        (_pendingOffer != null && !_pendingOffer!.isGroup && _pendingOffer!.orderId == order.id) ? _pendingOffer : null;

    return _FadeSlideIn(
      index: index,
      child: _HoverCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: brandColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.storefront_rounded, color: brandColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.storeName ?? order.orderNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(order.orderNumber, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (matchingOffer != null) ...[
                  _CountdownChip(expiresAt: matchingOffer.expiresAt),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '+₪${order.deliveryFee.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 15, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(order.deliveryAddress, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('تجاهل'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Theme.of(context).dividerColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _dismissOrder(order.id),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    onPressed: isAccepting ? null : () => _accept(order),
                    child: isAccepting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('قبول الطلب', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Grouped Delivery: بطاقة "Delivery Group #<id>" وحدة بدل بطاقة منفصلة
  // لكل متجر - rep.groupStores جاهزة مرتبة بترتيب الاستلام من الباك إند
  Widget _buildGroupCard(OrderModel rep, {required bool isActive}) {
    final groupId = rep.deliveryGroupId!;
    final isAccepting = _acceptingIds.contains(groupId);
    final stores = [...(rep.groupStores ?? <GroupStoreModel>[])]
      ..sort((a, b) => a.pickupSequence.compareTo(b.pickupSequence));
    final matchingOffer =
        (!isActive && _pendingOffer != null && _pendingOffer!.isGroup && _pendingOffer!.groupId == groupId)
            ? _pendingOffer
            : null;

    return _HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (isActive ? brandColor : AppColors.accent).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.route_rounded, color: isActive ? brandColor : AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('مجموعة توصيل #$groupId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              if (matchingOffer != null) ...[
                _CountdownChip(expiresAt: matchingOffer.expiresAt),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isActive ? brandColor : AppColors.accent).withValues(alpha: isActive ? 0.1 : 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'جاري التوصيل' : '${stores.length} متاجر',
                  style: TextStyle(
                    color: isActive ? brandColor : AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...stores.map((s) {
            final done = s.orderStatus == 'PickedUp' || s.orderStatus == 'Delivered';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    done ? Icons.check_circle : Icons.storefront_outlined,
                    size: 16,
                    color: done ? brandColor : Colors.grey[500],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${s.pickupSequence}. ${s.name ?? 'متجر'}',
                      style: TextStyle(
                        fontSize: 13,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? Colors.grey[500] : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.person_pin_circle_outlined, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(rep.deliveryAddress, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: isActive
                ? OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: brandColor,
                      side: BorderSide(color: brandColor),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => GroupDeliveryScreen(groupId: groupId)),
                      ).then((_) => _loadAll());
                    },
                    child: const Text('متابعة التوصيل'),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    onPressed: isAccepting ? null : () => _acceptGroup(rep),
                    child: isAccepting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('قبول المجموعة'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHistoryCard(OrderModel rep) {
    final cancelled = rep.groupStatus == 'Cancelled';
    return _HoverCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (cancelled ? Colors.redAccent : brandColor).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(cancelled ? Icons.close_rounded : Icons.check_rounded, size: 15, color: cancelled ? Colors.redAccent : brandColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('مجموعة #${rep.deliveryGroupId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Text(
            cancelled ? 'ملغاة' : 'تم التسليم',
            style: TextStyle(
              color: cancelled ? Colors.redAccent : brandColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(OrderModel order) {
    return _HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: brandColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Icon(Icons.two_wheeler_rounded, color: brandColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'جاري التوصيل',
                  style: TextStyle(color: brandColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, size: 15, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Expanded(child: Text(order.deliveryAddress, style: TextStyle(color: Colors.grey[600], fontSize: 12))),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: brandColor,
                side: BorderSide(color: brandColor),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ActiveDeliveryScreen(orderId: order.id)),
                ).then((_) => _loadAll());
              },
              child: const Text('متابعة التوصيل'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(OrderModel order) {
    final delivered = order.status == 'Delivered';
    return _HoverCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (delivered ? brandColor : Colors.redAccent).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(delivered ? Icons.check_rounded : Icons.close_rounded, size: 15, color: delivered ? brandColor : Colors.redAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Text(
            delivered ? 'تم التسليم' : 'ملغى',
            style: TextStyle(
              color: delivered ? brandColor : Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════ Shared presentational widgets ═══════════════════════════

/// كارت موحّد الشكل (ظل ناعم + Border Radius موحّد) مع رفعة خفيفة عند الـ
/// hover على الويب/الديسكتوب (بدون أي تأثير على الموبايل - MouseRegion ببساطة
/// ما بينفعّل بدون فأرة).
class _HoverCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const _HoverCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: widget.margin,
        transform: _hovering ? Matrix4.translationValues(0, -2, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovering ? 0.08 : 0.04),
              blurRadius: _hovering ? 18 : 10,
              offset: Offset(0, _hovering ? 8 : 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );
  }
}

/// كارت إحصائية مخصّص للوحة السائق (منفصل عن StatTile المشتركة مع لوحات
/// الأدمن/صاحب المتجر عشان تحسينات التصميم هون ما تأثر عليهم).
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String? trend;
  final bool trendPositive;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = AppColors.brand,
    this.trend,
    this.trendPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              if (trend != null)
                Flexible(
                  child: Text(
                    trend!,
                    style: TextStyle(
                      color: trendPositive ? AppColors.success : AppColors.error,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11.5)),
        ],
      ),
    );
  }
}

/// عدّاد تنازلي صغير - يُستخدم فقط لما بطاقة بقائمة "طلبات متاحة" تطابق عرض
/// Smart Assignment حقيقي معلّق لهاد السائق (expiresAt حقيقي من الباك إند،
/// نفس القيمة المعروضة بنافذة SmartOfferDialog).
class _CountdownChip extends StatefulWidget {
  final DateTime expiresAt;
  const _CountdownChip({required this.expiresAt});

  @override
  State<_CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<_CountdownChip> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    final d = widget.expiresAt.difference(DateTime.now());
    if (!mounted) return;
    setState(() => _remaining = d.isNegative ? Duration.zero : d);
    if (d.isNegative) _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _remaining.inSeconds;
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    final urgent = seconds <= 15;
    final color = urgent ? AppColors.error : AppColors.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 12, color: color),
          const SizedBox(width: 3),
          Text('$mm:$ss', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// عمود واحد بمخطط "الأداء الأسبوعي" - ارتفاعه نسبي لأعلى قيمة بالأسبوع
/// (ratio 0-1)، بيتحرّك لارتفاعه الحقيقي بأنيميشن خفيف عند أول رسم.
class _WeeklyBar extends StatelessWidget {
  final double ratio;
  final String valueLabel;
  final String dayLabel;
  final bool isToday;
  final Color color;
  final int delayMs;

  const _WeeklyBar({
    required this.ratio,
    required this.valueLabel,
    required this.dayLabel,
    required this.isToday,
    required this.color,
    this.delayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(valueLabel, style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: ratio.clamp(0, 1)),
          duration: Duration(milliseconds: 500 + delayMs),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => Container(
            height: (t * 78).clamp(4, 78),
            decoration: BoxDecoration(
              color: isToday ? color : color.withValues(alpha: 0.45),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          dayLabel,
          style: TextStyle(
            fontSize: 10.5,
            color: isToday ? color : Colors.grey[600],
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

/// دخول Fade + Slide خفيف للبطاقات (Implicit Animation - بدون AnimationController
/// يدوي ولا أي حزمة إضافية) - بيتكرر مع كل تحديث للقائمة (سحب للتحديث مثلاً).
class _FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  const _FadeSlideIn({required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index.clamp(0, 6) * 55)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
