// lib/screens/admin/admin_dashboard_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/admin_models.dart';
import '../../services/admin_service.dart';
import '../../services/coupon_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/admin_drawer.dart';
import '../../widgets/admin_header.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/stat_tile.dart';
import '../../utils/admin_report.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_themes.dart';
import 'admin_user_detail_screen.dart';
import 'admin_order_detail_screen.dart';
import 'widgets/admin_analytics_tab.dart';
import 'widgets/admin_live_map_tab.dart';
import 'widgets/admin_simulation_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  // ✅ لدعم التنقل المباشر لتبويب معيّن (من AdminDrawer مثلاً)
  final int initialTab;

  const AdminDashboardScreen({super.key, this.initialTab = 0});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const Color brandColor = AppColors.brand;
  static const List<Color> _palette = [
    Color(0xFF16A34A),
    Color(0xFFF97316),
    Color(0xFF3B82F6),
    Color(0xFFA855F7),
    Color(0xFFDC2626),
    Color(0xFF0EA5E9),
    Color(0xFFCA8A04),
  ];

  final _adminService = AdminService();
  final _couponService = CouponService();

  late int _selectedTab =
      widget.initialTab; // 0=Stores 1=Orders 2=Users 3=Categories 4=Companies 5=Coupons 6=Drivers 7=DeliveryGroups 8=Settings 9=LiveMap 10=Simulation

  AdminDashboardStats _stats = AdminDashboardStats.empty();
  List<AdminStoreModel> _stores = [];
  List<AdminUserModel> _users = [];
  List<AdminCategoryModel> _categories = [];
  List<AdminCompanyModel> _companies = [];
  List<CouponModel> _coupons = [];
  List<AdminOrderModel> _orders = [];
  List<AdminDriverModel> _drivers = [];
  List<AdminDeliveryGroupModel> _deliveryGroups = [];
  SystemSettingsModel _settings = SystemSettingsModel.empty();
  bool _settingsControllersReady = false; // ما منبني الـ controllers غير مرة وحدة (أول تحميل)
  bool _isSavingSettings = false;

  bool _isLoading = true;
  // ✅ true بس أول تحميل - بعدها الـ RefreshIndicator بيبيّن مؤشره الخاص فوق
  // المحتوى الموجود بدل ما يشيل الشاشة كلها ويحطّ دائرة تحميل بمكانها
  bool _hasLoadedOnce = false;
  bool _isGeneratingReport = false;
  final Set<String> _busyStoreIds = {};
  final Set<String> _busyCompanyIds = {};
  final List<_ToastData> _toasts = [];

  // ✅ سوكيت خاص باللوحة (بدون Riverpod - هاي الشاشة StatefulWidget عادية)
  // بينضم تلقائيًا لغرفة driver-status:admin وقت الاتصال (دور Admin)
  final SocketService _socket = SocketService();

  // بحث محلي (client-side) لكل تبويب - البيانات كلها متجابة أصلاً بالكامل
  // بـ_loadAll، فما في داعي لـ endpoint فلترة منفصل بهاد الحجم من البيانات.
  final _storeSearchCtrl = TextEditingController();
  final _userSearchCtrl = TextEditingController();
  final _categorySearchCtrl = TextEditingController();
  final _companySearchCtrl = TextEditingController();
  final _orderSearchCtrl = TextEditingController();
  final _driverSearchCtrl = TextEditingController();
  String? _orderStatusFilter; // null = كل الحالات
  DateTime? _orderDateFrom;
  DateTime? _orderDateTo;
  String? _userCategoryFilter; // Customer/Driver/Restaurant/Company/Admin - null = الكل
  String? _userStatusFilter; // Pending/Approved/Rejected/Suspended - null = الكل

  // إعدادات Grouped Delivery (تبويب 8)
  bool _groupedDeliveryEnabled = true;
  bool _autoAssignDriver = true;
  final _maxStoreDistanceCtrl = TextEditingController();
  final _maxDeliveryDistanceCtrl = TextEditingController();
  final _maxTimeBetweenOrdersCtrl = TextEditingController();
  final _maxOrdersPerGroupCtrl = TextEditingController();
  final _maxStoresPerTripCtrl = TextEditingController();
  final _minimumDriverRatingCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
    _connectLiveDriverStatus();
  }

  Future<void> _connectLiveDriverStatus() async {
    await _socket.connect();
    // ✅ السيرفر بيبث driver:status لغرفة الأدمن تلقائياً (join وقت الاتصال
    // بدور Admin) - منحدّث السائق المتأثر بس، بدون إعادة تحميل كامل.
    _socket.onDriverStatus((event) {
      if (!mounted) return;
      final index = _drivers.indexWhere((d) => d.id == event.driverId);
      if (index == -1) return;
      setState(() {
        final updated = [..._drivers];
        updated[index] = updated[index].copyWith(driverStatus: event.status);
        _drivers = updated;
      });
    });
  }

  @override
  void dispose() {
    _storeSearchCtrl.dispose();
    _userSearchCtrl.dispose();
    _categorySearchCtrl.dispose();
    _companySearchCtrl.dispose();
    _orderSearchCtrl.dispose();
    _driverSearchCtrl.dispose();
    _maxStoreDistanceCtrl.dispose();
    _maxDeliveryDistanceCtrl.dispose();
    _maxTimeBetweenOrdersCtrl.dispose();
    _maxOrdersPerGroupCtrl.dispose();
    _maxStoresPerTripCtrl.dispose();
    _minimumDriverRatingCtrl.dispose();
    _socket.offDriverStatus();
    _socket.disconnect();
    super.dispose();
  }

  Future<void> _loadAll() async {
    // ✅ ما منبيّن دائرة التحميل الكبيرة إلا أول مرة - السحب للتحديث بعدها
    // بيبيّن مؤشره الخاص فوق المحتوى الموجود بدل ما يشيل الشاشة كلها
    setState(() => _isLoading = !_hasLoadedOnce);
    final results = await Future.wait([
      _adminService.getDashboardStats(),
      _adminService.getStores(),
      _adminService.getUsers(),
      _adminService.getCategories(),
      _adminService.getDeliveryCompanies(),
      _adminService.getOrders(),
      _adminService.getDrivers(),
      _adminService.getDeliveryGroups(),
      _adminService.getSystemSettings(),
    ]);
    final couponResult = await _couponService.getAllCouponsAdmin();
    if (!mounted) return;
    setState(() {
      _stats = results[0] as AdminDashboardStats;
      _stores = results[1] as List<AdminStoreModel>;
      _users = results[2] as List<AdminUserModel>;
      _categories = results[3] as List<AdminCategoryModel>;
      _companies = results[4] as List<AdminCompanyModel>;
      _orders = results[5] as List<AdminOrderModel>;
      _drivers = results[6] as List<AdminDriverModel>;
      _deliveryGroups = results[7] as List<AdminDeliveryGroupModel>;
      _settings = results[8] as SystemSettingsModel;
      if (couponResult.success) _coupons = couponResult.coupons;
      _isLoading = false;
      _hasLoadedOnce = true;
      // ✅ منبني قيم الحقول مرة وحدة بس (أول تحميل) عشان لا نمسح تعديلات
      // الأدمن الجارية لو صار refresh بالخلفية
      if (!_settingsControllersReady) {
        _groupedDeliveryEnabled = _settings.groupedDeliveryEnabled;
        _autoAssignDriver = _settings.autoAssignDriver;
        // ✅ الباك اند يخزّن المسافة بالكيلومتر (DECIMAL) - بس الأدمن بيدخلها
        // بالمتر (أوضح وأقرب لواقع "100 متر بين متجرين") - تحويل هون بس،
        // القيمة المخزّنة والمرسلة للباك اند تضل كم زي ما هي.
        _maxStoreDistanceCtrl.text = (_settings.maxStoreDistance * 1000).round().toString();
        _maxDeliveryDistanceCtrl.text = (_settings.maxDeliveryDistance * 1000).round().toString();
        _maxTimeBetweenOrdersCtrl.text = _settings.maxTimeBetweenOrders.toString();
        _maxOrdersPerGroupCtrl.text = _settings.maxOrdersPerGroup.toString();
        _maxStoresPerTripCtrl.text = _settings.maxStoresPerTrip.toString();
        _minimumDriverRatingCtrl.text = _settings.minimumDriverRating.toString();
        _settingsControllersReady = true;
      }
    });
  }

  Future<void> _saveSettings() async {
    final locale = Localizations.localeOf(context);
    setState(() => _isSavingSettings = true);
    // ✅ رجوع من متر (المعروض للأدمن) لكيلومتر (المخزّن بالباك اند) - null
    // لو الإدخال مش رقم صحيح، عشان يوصل نفس رسالة تحقق الباك اند العادية
    final maxStoreDistanceMeters = double.tryParse(_maxStoreDistanceCtrl.text.trim());
    final maxDeliveryDistanceMeters = double.tryParse(_maxDeliveryDistanceCtrl.text.trim());
    final result = await _adminService.updateSystemSettings({
      'grouped_delivery_enabled': _groupedDeliveryEnabled,
      'auto_assign_driver': _autoAssignDriver,
      'max_store_distance': maxStoreDistanceMeters != null ? maxStoreDistanceMeters / 1000 : null,
      'max_delivery_distance': maxDeliveryDistanceMeters != null ? maxDeliveryDistanceMeters / 1000 : null,
      'max_time_between_orders': int.tryParse(_maxTimeBetweenOrdersCtrl.text.trim()),
      'max_orders_per_group': int.tryParse(_maxOrdersPerGroupCtrl.text.trim()),
      'max_stores_per_trip': int.tryParse(_maxStoresPerTripCtrl.text.trim()),
      'minimum_driver_rating': double.tryParse(_minimumDriverRatingCtrl.text.trim()),
    });
    if (!mounted) return;
    setState(() => _isSavingSettings = false);
    if (result.success) {
      _showToast(AppLocalizations.t(locale, 'admin_settings_saved'));
      _loadAll();
    } else {
      _showToast(
        result.message.isNotEmpty
            ? result.message
            : AppLocalizations.t(locale, 'admin_settings_save_failed'),
      );
    }
  }

  void _openAdminCouponDialog() {
    showDialog(
      context: context,
      builder: (context) => _AdminCouponFormDialog(
        brandColor: brandColor,
        couponService: _couponService,
        onSuccess: () {
          Navigator.pop(context);
          _showToast('تم إنشاء الكوبون');
          _loadAll();
        },
        onError: (message) => _showToast(message),
      ),
    );
  }

  void _showToast(String message) {
    final toast = _ToastData(message);
    setState(() => _toasts.add(toast));
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _toasts.remove(toast));
    });
  }

  Future<void> _printReport() async {
    setState(() => _isGeneratingReport = true);
    try {
      await printAdminReport(
        stats: _stats,
        stores: _stores,
        users: _users,
        categories: _categories,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      if (mounted) {
        _showToast(
          AppLocalizations.t(
            Localizations.localeOf(context),
            'admin_report_error',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingReport = false);
    }
  }

  Future<void> _approveStore(AdminStoreModel store) async {
    setState(() => _busyStoreIds.add(store.id));
    final result = await _adminService.approveStore(store.id);
    if (!mounted) return;
    setState(() => _busyStoreIds.remove(store.id));
    if (result.success) {
      _showToast(
        AppLocalizations.t(
          Localizations.localeOf(context),
          'admin_store_approved',
        ),
      );
      _loadAll();
    } else {
      _showToast(
        result.message.isNotEmpty
            ? result.message
            : AppLocalizations.t(
                Localizations.localeOf(context),
                'admin_approve_store_error',
              ),
      );
    }
  }

  Future<void> _approveCompany(AdminCompanyModel company) async {
    setState(() => _busyCompanyIds.add(company.id));
    final result = await _adminService.approveCompany(company.id);
    if (!mounted) return;
    setState(() => _busyCompanyIds.remove(company.id));
    if (result.success) {
      _showToast('تمت الموافقة على شركة التوصيل');
      _loadAll();
    } else {
      _showToast(
        result.message.isNotEmpty ? result.message : 'تعذر الموافقة على الشركة',
      );
    }
  }

  Future<void> _rejectCompany(AdminCompanyModel company) async {
    setState(() => _busyCompanyIds.add(company.id));
    final result = await _adminService.rejectCompany(company.id);
    if (!mounted) return;
    setState(() => _busyCompanyIds.remove(company.id));
    if (result.success) {
      _showToast('تم رفض شركة التوصيل');
      _loadAll();
    } else {
      _showToast(
        result.message.isNotEmpty ? result.message : 'تعذر رفض الشركة',
      );
    }
  }

  Future<void> _toggleFeatured(AdminStoreModel store) async {
    setState(() => _busyStoreIds.add(store.id));
    final result = await _adminService.toggleFeatured(store.id, !store.isFeatured);
    if (!mounted) return;
    setState(() => _busyStoreIds.remove(store.id));
    if (result.success) {
      _loadAll();
    } else {
      _showToast(
        result.message.isNotEmpty
            ? result.message
            : AppLocalizations.t(Localizations.localeOf(context), 'admin_toggle_featured_error'),
      );
    }
  }

  Future<void> _confirmDeleteStore(AdminStoreModel store) async {
    final locale = Localizations.localeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.t(locale, 'admin_delete_store_title')),
        content: Text(
          AppLocalizations.t(
            locale,
            'admin_delete_store_confirm',
          ).replaceFirst('{name}', store.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.t(locale, 'admin_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.t(locale, 'admin_delete'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyStoreIds.add(store.id));
    final result = await _adminService.deleteStore(store.id);
    if (!mounted) return;
    setState(() => _busyStoreIds.remove(store.id));
    if (result.success) {
      _showToast(
        AppLocalizations.t(
          Localizations.localeOf(context),
          'admin_store_deleted',
        ),
      );
      _loadAll();
    } else {
      _showToast(
        result.message.isNotEmpty
            ? result.message
            : AppLocalizations.t(
                Localizations.localeOf(context),
                'admin_delete_store_error',
              ),
      );
    }
  }

  // ✅ استكمال: زر "رفض" كان موجود بالباك إند وService (rejectStore) بس بلا
  // أي زر يستدعيه - المتاجر المعلّقة كان ممكن بس توافق أو تنحذف نهائيًا
  Future<void> _confirmRejectStore(AdminStoreModel store) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض المتجر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سبب رفض "${store.name}" (اختياري - بيظهر لصاحب المتجر):'),
            const SizedBox(height: 12),
            CustomTextField(controller: reasonCtrl, label: 'سبب الرفض', hint: 'مثلاً: بيانات ناقصة'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('رفض', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyStoreIds.add(store.id));
    final result = await _adminService.rejectStore(store.id, reason: reasonCtrl.text.trim());
    if (!mounted) return;
    setState(() => _busyStoreIds.remove(store.id));
    if (result.success) {
      _showToast('تم رفض المتجر');
      _loadAll();
    } else {
      _showToast(result.message.isNotEmpty ? result.message : 'تعذر رفض المتجر');
    }
  }

  final Set<String> _busyDriverIds = {};

  // ✅ استكمال إدارة السائقين: Approve/Reject/Suspend/Activate - كانت الحالة
  // (account_status) تترجع من الباك إند بس بلا أي إجراء يغيّرها من هون
  Future<void> _changeDriverStatus(AdminDriverModel driver, String status) async {
    setState(() => _busyDriverIds.add(driver.id));
    final result = await _adminService.updateUserStatus(driver.id, status);
    if (!mounted) return;
    setState(() => _busyDriverIds.remove(driver.id));
    if (result.success) {
      setState(() {
        final index = _drivers.indexWhere((d) => d.id == driver.id);
        if (index != -1) {
          final updated = [..._drivers];
          updated[index] = updated[index].copyWith(accountStatus: status, driverStatus: status == 'Suspended' ? 'Offline' : updated[index].driverStatus);
          _drivers = updated;
        }
      });
      _showToast('تم تحديث حالة السائق');
    } else {
      _showToast(result.message.isNotEmpty ? result.message : 'تعذر تحديث حالة السائق');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminDrawer(),
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWeb = constraints.maxWidth > 900;
                final padding = isWeb ? constraints.maxWidth * 0.06 : 16.0;
                return Row(
                  children: [
                    if (isWeb) const AdminSidebar(),
                    Expanded(child: Column(
                  children: [
                    AdminHeader(isWeb: isWeb, padding: padding),
                    Expanded(
                      child: (_isLoading && !_hasLoadedOnce)
                          ? const Center(child: CircularProgressIndicator())
                          : RefreshIndicator(
                              onRefresh: _loadAll,
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.symmetric(
                                  horizontal: padding,
                                  vertical: 24,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildHeader(),
                                    const SizedBox(height: 24),
                                    _buildStatCards(isWeb),
                                    const SizedBox(height: 20),
                                    _buildGroupedDeliveryCards(isWeb),
                                    const SizedBox(height: 20),
                                    _buildChartsRow(isWeb),
                                    const SizedBox(height: 20),
                                    _buildTabsRow(),
                                    const SizedBox(height: 20),
                                    _buildTabContent(),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                )),
                  ],
                );
              },
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _toasts.map(_buildToast).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final locale = Localizations.localeOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.t(locale, 'admin_title'),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              AppLocalizations.t(locale, 'admin_subtitle'),
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: brandColor,
            side: BorderSide(color: brandColor),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _isGeneratingReport ? null : _printReport,
          icon: _isGeneratingReport
              ? SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: brandColor,
                  ),
                )
              : const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: Text(AppLocalizations.t(locale, 'admin_print_report')),
        ),
      ],
    );
  }

  Widget _buildStatCards(bool isWeb) {
    final locale = Localizations.localeOf(context);
    final cards = [
      StatTile(
        large: true,
        icon: Icons.people_outline,
        iconColor: const Color(0xFF3B82F6),
        value: '${_stats.totalUsers}',
        label: AppLocalizations.t(locale, 'admin_total_users'),
      ),
      StatTile(
        large: true,
        icon: Icons.storefront_outlined,
        iconColor: const Color(0xFFA855F7),
        value: '${_stats.totalStores}',
        label: AppLocalizations.t(locale, 'admin_total_stores'),
      ),
      StatTile(
        large: true,
        icon: Icons.inventory_2_outlined,
        iconColor: const Color(0xFFF97316),
        value: '${_stats.totalOrders}',
        label: AppLocalizations.t(locale, 'admin_total_orders'),
      ),
      StatTile(
        large: true,
        icon: Icons.attach_money,
        iconColor: const Color(0xFF16A34A),
        value: '₪${_stats.revenue.toStringAsFixed(0)}',
        label: AppLocalizations.t(locale, 'admin_revenue'),
      ),
    ];

    if (!isWeb) {
      return Column(
        children: cards
            .map(
              (c) =>
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
            )
            .toList(),
      );
    }
    return Row(
      children: cards
          .map(
            (c) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: c,
              ),
            ),
          )
          .toList(),
    );
  }

  // ✅ Grouped Delivery (Smart Order Clustering) - نفس بطاقة StatTile
  // المستخدمة فوق بالضبط، بس لمقاييس رحلات التوصيل المجمّعة
  Widget _buildGroupedDeliveryCards(bool isWeb) {
    final g = _stats.deliveryGroups;
    final cards = [
      StatTile(
        large: true,
        icon: Icons.merge_type_outlined,
        iconColor: const Color(0xFF16A34A),
        value: '${g.totalGroups}',
        label: 'مجموعات تم إنشاؤها',
      ),
      StatTile(
        large: true,
        icon: Icons.inventory_2_outlined,
        iconColor: const Color(0xFF3B82F6),
        value: '${g.ordersGrouped}',
        label: 'طلبات داخل مجموعات',
      ),
      StatTile(
        large: true,
        icon: Icons.alt_route_outlined,
        iconColor: const Color(0xFFF97316),
        value: '${g.tripsSaved}',
        label: 'رحلات توصيل تم توفيرها',
      ),
      StatTile(
        large: true,
        icon: Icons.schedule_outlined,
        iconColor: const Color(0xFFA855F7),
        value: '${g.timeSavedMinEstimate} د',
        label: 'الوقت التقديري الموفّر',
      ),
    ];

    // ✅ حساب التوفير الحقيقي التقديري (#7) - وقود/تكلفة/CO2، راجع
    // groupingService.getGroupingStats. صف تاني منفصل وواضح إنه تقديري
    // (مش قياس فعلي) عن الأرقام الأساسية فوق.
    final savingsCards = [
      StatTile(
        large: true,
        icon: Icons.local_gas_station_outlined,
        iconColor: const Color(0xFF0EA5E9),
        value: '${g.fuelSavedKmEstimate.toStringAsFixed(1)} كم',
        label: 'وقود موفّر (تقديري)',
      ),
      StatTile(
        large: true,
        icon: Icons.savings_outlined,
        iconColor: const Color(0xFF16A34A),
        value: '${g.costSavedJdEstimate.toStringAsFixed(2)} د.أ',
        label: 'تكلفة موفّرة (تقديري)',
      ),
      StatTile(
        large: true,
        icon: Icons.eco_outlined,
        iconColor: const Color(0xFF22C55E),
        value: '${g.co2SavedKgEstimate.toStringAsFixed(2)} كغم',
        label: 'انبعاثات CO₂ موفّرة (تقديري)',
      ),
    ];

    final section = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'التوصيل المجمّع (Grouped Delivery)',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (!isWeb)
          Column(
            children: cards
                .map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c))
                .toList(),
          )
        else
          Row(
            children: cards
                .map(
                  (c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: c,
                    ),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 12),
        if (!isWeb)
          Column(
            children: savingsCards
                .map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c))
                .toList(),
          )
        else
          Row(
            children: savingsCards
                .map(
                  (c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: c,
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );

    return section;
  }

  Widget _buildChartsRow(bool isWeb) {
    final locale = Localizations.localeOf(context);
    final ordersCard = _ChartCard(
      title: AppLocalizations.t(locale, 'admin_orders_by_status'),
      child: _stats.ordersByStatus.isEmpty
          ? _emptyChartPlaceholder()
          : _OrdersByStatusList(data: _stats.ordersByStatus),
    );
    final categoriesCard = _ChartCard(
      title: AppLocalizations.t(locale, 'admin_stores_by_category'),
      child: _categories.where((c) => c.storeCount > 0).isEmpty
          ? _emptyChartPlaceholder()
          : _CategoryPieChart(categories: _categories, palette: _palette),
    );

    if (!isWeb) {
      return Column(
        children: [ordersCard, const SizedBox(height: 16), categoriesCard],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: ordersCard),
        const SizedBox(width: 16),
        Expanded(child: categoriesCard),
      ],
    );
  }

  Widget _emptyChartPlaceholder() {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        AppLocalizations.t(Localizations.localeOf(context), 'admin_no_data'),
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[400]
              : Colors.grey[600],
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildTabsRow() {
    final locale = Localizations.localeOf(context);
    final tabs = [
      '${AppLocalizations.t(locale, 'admin_tab_stores')} (${_stores.length})',
      '${AppLocalizations.t(locale, 'admin_tab_orders')} (${_orders.length})',
      '${AppLocalizations.t(locale, 'admin_tab_users')} (${_users.length})',
      '${AppLocalizations.t(locale, 'admin_tab_categories')} (${_categories.length})',
      'شركات التوصيل (${_companies.length})',
      'الكوبونات (${_coupons.length})',
      'السائقين (${_drivers.length})',
      'التوصيل المجمّع (${_deliveryGroups.length})',
      AppLocalizations.t(locale, 'admin_tab_delivery_settings'),
      'الخريطة الحية',
      'Simulation',
      'التحليلات',
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: brandColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 4),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).cardColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: brandColor,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildStoresTab();
      case 1:
        return _buildOrdersTab();
      case 2:
        return _buildUsersTab();
      case 3:
        return _buildCategoriesTab();
      case 4:
        return _buildCompaniesTab();
      case 5:
        return _buildAdminCouponsTab();
      case 6:
        return _buildDriversTab();
      case 7:
        return _buildDeliveryGroupsTab();
      case 8:
        return _buildDeliverySettingsTab();
      case 9:
        return const AdminLiveMapTab();
      case 10:
        return const AdminSimulationTab();
      case 11:
        return const AdminAnalyticsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _searchBox(TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: Theme.of(context).cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStoresTab() {
    final query = _storeSearchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _stores
        : _stores.where((s) => s.name.toLowerCase().contains(query)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _searchBox(
          _storeSearchCtrl,
          AppLocalizations.t(
            Localizations.localeOf(context),
            'admin_search_stores',
          ),
        ),
        if (filtered.isEmpty)
          _emptyState(
            AppLocalizations.t(
              Localizations.localeOf(context),
              'admin_no_stores',
            ),
          )
        else
          ...filtered.map(_buildStoreRow),
      ],
    );
  }

  Widget _buildStoreRow(AdminStoreModel store) {
    final isBusy = _busyStoreIds.contains(store.id);
    final isApproved = store.approvalStatus.toLowerCase() == 'approved';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 48,
              height: 48,
              child: store.imageUrl.isNotEmpty
                  ? Image.network(
                      store.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Theme.of(context).dividerColor,
                        child: const Icon(
                          Icons.storefront_outlined,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : Container(
                      color: Theme.of(context).dividerColor,
                      child: const Icon(
                        Icons.storefront_outlined,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (store.category != null) store.category!,
                    store.address,
                  ].join(' • '),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusBadge(store.approvalStatus, isApproved),
          if (!isApproved) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: isBusy ? null : () => _approveStore(store),
              icon: isBusy
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline, size: 16),
              label: Text(
                AppLocalizations.t(
                  Localizations.localeOf(context),
                  'admin_approve',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'رفض',
              icon: const Icon(Icons.close, color: AppColors.error),
              onPressed: isBusy ? null : () => _confirmRejectStore(store),
            ),
          ],
          const SizedBox(width: 8),
          IconButton(
            tooltip: AppLocalizations.t(
              Localizations.localeOf(context),
              store.isFeatured ? 'admin_unfeature_store' : 'admin_feature_store',
            ),
            icon: Icon(
              store.isFeatured ? Icons.star : Icons.star_border,
              color: store.isFeatured ? Colors.amber : Colors.grey,
            ),
            onPressed: isBusy ? null : () => _toggleFeatured(store),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: isBusy ? null : () => _confirmDeleteStore(store),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status, bool isApproved) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isApproved
            ? brandColor.withValues(alpha: 0.1)
            : Theme.of(context).dividerColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isApproved ? brandColor : Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  Widget _buildCompaniesTab() {
    final query = _companySearchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _companies
        : _companies
              .where((c) => c.name.toLowerCase().contains(query))
              .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _searchBox(
          _companySearchCtrl,
          AppLocalizations.t(
            Localizations.localeOf(context),
            'admin_search_companies',
          ),
        ),
        if (filtered.isEmpty)
          _emptyState('لا يوجد شركات توصيل مسجلة')
        else
          ...filtered.map(_buildCompanyRow),
      ],
    );
  }

  Widget _buildCompanyRow(AdminCompanyModel company) {
    final isBusy = _busyCompanyIds.contains(company.id);
    final isApproved = company.status == 'Approved';
    final isRejected = company.status == 'Rejected';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: brandColor.withValues(alpha: 0.1),
            child: Icon(Icons.local_shipping_outlined, color: brandColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    company.email,
                    if (company.city != null) company.city!,
                  ].join(' • '),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusBadge(company.status, isApproved),
          if (!isApproved && !isRejected) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: isBusy ? null : () => _approveCompany(company),
              icon: isBusy
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('موافقة'),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.redAccent),
              onPressed: isBusy ? null : () => _rejectCompany(company),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDriversTab() {
    final query = _driverSearchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _drivers
        : _drivers
            .where((d) =>
                d.fullName.toLowerCase().contains(query) || (d.phone ?? '').contains(query))
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _searchBox(_driverSearchCtrl, 'ابحث بالاسم أو رقم الهاتف...'),
        if (filtered.isEmpty)
          _emptyState('لا يوجد سائقين مسجلين')
        else
          ...filtered.map(_buildDriverRow),
      ],
    );
  }

  Widget _buildDriverRow(AdminDriverModel driver) {
    late Color statusColor;
    late String statusLabel;
    switch (driver.driverStatus) {
      case 'Available':
        statusColor = brandColor;
        statusLabel = 'متاح';
        break;
      case 'Busy':
        statusColor = const Color(0xFFF97316);
        statusLabel = 'مشغول';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = 'غير متصل';
    }

    final accountColor = _userStatusColors[driver.accountStatus] ?? Colors.grey;
    final accountLabel = _userStatusLabels[driver.accountStatus] ?? driver.accountStatus;
    final isBusy = _busyDriverIds.contains(driver.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: brandColor.withValues(alpha: 0.1),
                child: Icon(Icons.two_wheeler_outlined, color: brandColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (driver.vehicleType != null) driver.vehicleType!,
                        driver.companyName ?? 'سائق مستقل',
                        if (driver.phone != null) driver.phone!,
                      ].join(' • '),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${driver.deliveredCount} طلب موصّل', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: accountColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                child: Text(accountLabel, style: TextStyle(color: accountColor, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 10),
              Text(
                driver.rating != null ? '⭐ ${driver.rating!.toStringAsFixed(1)}' : 'التقييم: غير متوفر حاليًا',
                style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
              ),
              const Spacer(),
              if (isBusy)
                const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                if (driver.accountStatus == 'Pending') ...[
                  _driverActionButton('اعتماد', AppColors.success, () => _changeDriverStatus(driver, 'Approved')),
                  const SizedBox(width: 6),
                  _driverActionButton('رفض', AppColors.error, () => _changeDriverStatus(driver, 'Rejected')),
                ] else if (driver.accountStatus == 'Approved') ...[
                  _driverActionButton('تعليق', AppColors.error, () => _changeDriverStatus(driver, 'Suspended')),
                ] else if (driver.accountStatus == 'Suspended') ...[
                  _driverActionButton('تفعيل', AppColors.success, () => _changeDriverStatus(driver, 'Approved')),
                ] else if (driver.accountStatus == 'Rejected') ...[
                  _driverActionButton('اعتماد', AppColors.success, () => _changeDriverStatus(driver, 'Approved')),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _driverActionButton(String label, Color color, VoidCallback onTap) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildAdminCouponsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            onPressed: _openAdminCouponDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'كوبون عام جديد',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_coupons.isEmpty)
          _emptyState('لا يوجد كوبونات مسجلة')
        else
          ..._coupons.map(_buildAdminCouponRow),
      ],
    );
  }

  Widget _buildAdminCouponRow(CouponModel coupon) {
    final discountLabel = coupon.discountType == 'Percentage'
        ? '${coupon.discountValue.toStringAsFixed(0)}%'
        : '₪${coupon.discountValue.toStringAsFixed(2)}';
    final isPlatformWide = coupon.restaurantId == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coupon.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'خصم $discountLabel • ${isPlatformWide ? "عام على كل المنصة" : coupon.storeName ?? "متجر"}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: coupon.isActive
                  ? brandColor.withValues(alpha: 0.1)
                  : Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              coupon.isActive ? 'فعّال' : 'موقوف',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: coupon.isActive ? brandColor : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _orderStatuses = [
    'Pending',
    'Confirmed',
    'Preparing',
    'Ready',
    'PickedUp',
    'Delivered',
    'Cancelled',
    'Refunded',
  ];

  Color _orderStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Confirmed':
      case 'Preparing':
        return const Color(0xFF3B82F6);
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

  Widget _buildOrdersTab() {
    final locale = Localizations.localeOf(context);
    final query = _orderSearchCtrl.text.trim().toLowerCase();
    final filtered = _orders.where((o) {
      final matchesStatus =
          _orderStatusFilter == null || o.status == _orderStatusFilter;
      final matchesQuery =
          query.isEmpty ||
          o.orderNumber.toLowerCase().contains(query) ||
          (o.customerName?.toLowerCase().contains(query) ?? false) ||
          (o.storeName?.toLowerCase().contains(query) ?? false);
      final matchesDate = (_orderDateFrom == null && _orderDateTo == null) ||
          (o.orderTime != null &&
              (_orderDateFrom == null || !o.orderTime!.isBefore(_orderDateFrom!)) &&
              (_orderDateTo == null || o.orderTime!.isBefore(_orderDateTo!.add(const Duration(days: 1)))));
      return matchesStatus && matchesQuery && matchesDate;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _searchBox(
          _orderSearchCtrl,
          AppLocalizations.t(locale, 'admin_search_orders'),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip(AppLocalizations.t(locale, 'admin_status_all'), _orderStatusFilter == null, brandColor,
                  () => setState(() => _orderStatusFilter = null)),
              ..._orderStatuses.map((s) => _filterChip(s, _orderStatusFilter == s, _orderStatusColor(s), () => setState(() => _orderStatusFilter = s))),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _dateFilterButton('من تاريخ', _orderDateFrom, (d) => setState(() => _orderDateFrom = d))),
            const SizedBox(width: 10),
            Expanded(child: _dateFilterButton('إلى تاريخ', _orderDateTo, (d) => setState(() => _orderDateTo = d))),
            if (_orderDateFrom != null || _orderDateTo != null)
              IconButton(
                tooltip: 'إزالة فلتر التاريخ',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() {
                  _orderDateFrom = null;
                  _orderDateTo = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_orders.isEmpty)
          _emptyState(AppLocalizations.t(locale, 'admin_no_orders'))
        else if (filtered.isEmpty)
          _emptyState(AppLocalizations.t(locale, 'admin_no_orders_match'))
        else
          ...filtered.map(_buildOrderRow),
      ],
    );
  }

  Widget _dateFilterButton(String label, DateTime? value, ValueChanged<DateTime?> onPicked) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: value != null ? brandColor : Colors.grey[600],
        side: BorderSide(color: value != null ? brandColor : Theme.of(context).dividerColor),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) onPicked(picked);
      },
      icon: const Icon(Icons.calendar_today_outlined, size: 15),
      label: Text(
        value != null ? '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}' : label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Future<void> _openOrderDetail(AdminOrderModel order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(orderId: order.id)),
    );
    _loadAll();
  }

  Widget _buildOrderRow(AdminOrderModel order) {
    final color = _orderStatusColor(order.status);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openOrderDetail(order),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        order.orderNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (order.isGrouped) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('مجمّع', style: TextStyle(fontSize: 9.5, color: AppColors.accent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (order.storeName != null) order.storeName!,
                      if (order.customerName != null) order.customerName!,
                      if (order.driverName != null) order.driverName!,
                      if (order.driverCompanyName != null) order.driverCompanyName!,
                    ].join(' • '),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₪${order.finalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    order.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_left, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  static const Map<String, String> _userCategoryLabels = {
    'Customer': 'زبائن',
    'Driver': 'سائقين',
    'Restaurant': 'أصحاب متاجر',
    'Company': 'شركات توصيل',
    'Admin': 'أدمن',
  };

  static const Map<String, String> _userStatusLabels = {
    'Approved': 'نشط',
    'Suspended': 'معلّق',
    'Pending': 'بانتظار الموافقة',
    'Rejected': 'مرفوض',
  };

  static const Map<String, Color> _userStatusColors = {
    'Approved': AppColors.success,
    'Suspended': AppColors.error,
    'Pending': AppColors.warning,
    'Rejected': Colors.grey,
  };

  Widget _buildUsersTab() {
    final query = _userSearchCtrl.text.trim().toLowerCase();
    final filtered = _users.where((u) {
      final matchesQuery = query.isEmpty ||
          u.fullName.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query);
      final matchesCategory = _userCategoryFilter == null || u.category == _userCategoryFilter;
      final matchesStatus = _userStatusFilter == null || u.status == _userStatusFilter;
      return matchesQuery && matchesCategory && matchesStatus;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _searchBox(
          _userSearchCtrl,
          AppLocalizations.t(
            Localizations.localeOf(context),
            'admin_search_users',
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip('الكل', _userCategoryFilter == null, brandColor, () => setState(() => _userCategoryFilter = null)),
              ..._userCategoryLabels.entries.map((e) => _filterChip(
                    e.value,
                    _userCategoryFilter == e.key,
                    brandColor,
                    () => setState(() => _userCategoryFilter = e.key),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip('كل الحالات', _userStatusFilter == null, brandColor, () => setState(() => _userStatusFilter = null)),
              ..._userStatusLabels.entries.map((e) => _filterChip(
                    e.value,
                    _userStatusFilter == e.key,
                    _userStatusColors[e.key] ?? Colors.grey,
                    () => setState(() => _userStatusFilter = e.key),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          _emptyState(
            AppLocalizations.t(
              Localizations.localeOf(context),
              'admin_no_users',
            ),
          )
        else
          ...filtered.map(_buildUserRow),
      ],
    );
  }

  // ✅ فلتر شريحة عام (لون + حالة تحديد) - نفس فكرة _orderStatusChip القديمة
  // بس مُعمّمة عشان يعاد استخدامها بتبويب المستخدمين كمان بدل ما تتكرر
  Widget _filterChip(String label, bool isSelected, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUserDetail(AdminUserModel user) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminUserDetailScreen(user: user)),
    );
    if (changed == true) _loadAll();
  }

  Widget _buildUserRow(AdminUserModel user) {
    final isAdmin = user.role == 'Admin';
    final statusColor = _userStatusColors[user.status] ?? Colors.grey;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openUserDetail(user),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: brandColor.withValues(alpha: 0.1),
              child: Icon(Icons.person_outline, color: brandColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    user.email,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  // ✅ Loyalty: رصيد نقاط الزبون - يظهر بس لفئة Customer (باقي
                  // الأدوار رصيدهم دايمًا صفر، عرضه إلهم مجرد ضجيج بصري)
                  if (user.category == 'Customer') ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stars_outlined, size: 12, color: Colors.amber[700]),
                        const SizedBox(width: 3),
                        Text(
                          '${user.loyaltyPoints} نقطة',
                          style: TextStyle(fontSize: 11, color: Colors.amber[800], fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isAdmin
                        ? brandColor.withValues(alpha: 0.1)
                        : Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _userCategoryLabels[user.category] ?? user.role,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isAdmin ? brandColor : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(_userStatusLabels[user.status] ?? user.status,
                        style: TextStyle(fontSize: 10.5, color: statusColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_left, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    final locale = Localizations.localeOf(context);
    final query = _categorySearchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _categories
        : _categories
              .where((c) => c.name.toLowerCase().contains(query))
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _searchBox(
          _categorySearchCtrl,
          AppLocalizations.t(locale, 'admin_search_categories'),
        ),
        if (filtered.isEmpty)
          _emptyState(AppLocalizations.t(locale, 'admin_no_categories'))
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 950
                  ? 3
                  : (constraints.maxWidth > 650 ? 2 : 1);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.6,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final c = filtered[i];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          c.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${c.storeCount} ${AppLocalizations.t(locale, 'admin_stores_word')} • '
                          '${c.productCount} ${AppLocalizations.t(locale, 'admin_products_word')}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  static const Map<String, Color> _groupStatusColors = {
    'Forming': Color(0xFFF97316),
    'Assigned': Color(0xFF3B82F6),
    'Completed': AppColors.brand,
    'Cancelled': AppColors.error,
  };

  static const Map<String, String> _groupStatusLabels = {
    'Forming': 'قيد التشكيل',
    'Assigned': 'معيّنة لسائق',
    'Completed': 'مكتملة',
    'Cancelled': 'ملغاة',
  };

  // ✅ Grouped Delivery (Smart Order Clustering): قسم يعرض كل رحلة توصيل
  // مجمّعة - السائق المُختار، سبب الاختيار، وحالة الرحلة الحالية
  Widget _buildDeliveryGroupsTab() {
    if (_deliveryGroups.isEmpty) {
      return _emptyState('لا توجد رحلات توصيل مجمّعة بعد');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _deliveryGroups.map(_buildDeliveryGroupRow).toList(),
    );
  }

  Widget _buildDeliveryGroupRow(AdminDeliveryGroupModel group) {
    final color = _groupStatusColors[group.status] ?? Colors.grey;
    final reason = group.assignmentReason;
    String? reasonSummary;
    if (reason != null && reason['breakdown'] is List) {
      final breakdown = reason['breakdown'] as List;
      final top = breakdown.isNotEmpty
          ? breakdown.reduce((a, b) => (a['score'] as num) >= (b['score'] as num) ? a : b)
          : null;
      if (top != null) reasonSummary = 'أعلى عامل تأثير: ${top['factor']} (${top['score']})';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('مجموعة #${group.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                child: Text(_groupStatusLabels[group.status] ?? group.status,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'الزبون: ${group.customerName ?? '-'}',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            group.driverName != null
                ? 'السائق: ${group.driverName} ${group.assignmentType != null ? '(${group.assignmentType})' : ''}'
                : 'بانتظار تعيين سائق',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[700], fontWeight: FontWeight.w600),
          ),
          if (reasonSummary != null) ...[
            const SizedBox(height: 4),
            Text(reasonSummary, style: const TextStyle(fontSize: 11.5, color: AppColors.accent, fontWeight: FontWeight.w600)),
          ],
          // ✅ سائق احتياطي (#5) - ثاني أفضل مرشح حاليًا، لو في سائق أساسي
          // بعد. الانتقال التلقائي الفعلي عند انتهاء مهلة العرض موجود أصلًا
          // بالباك اند (sweepExpiredGroupOffers) - هاد بس يعرضه مقدّمًا.
          if (group.backupDriver != null) ...[
            const SizedBox(height: 4),
            Text(
              'سائق احتياطي: ${group.backupDriver!.name}',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 10),
          ...group.stores.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 9,
                          backgroundColor: brandColor.withValues(alpha: 0.12),
                          child: Text('${s.pickupSequence}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: brandColor)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s.storeName ?? 'متجر', style: const TextStyle(fontSize: 12.5))),
                        Text(s.orderStatus, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                    _buildGroupingReasonSection(s),
                  ],
                ),
              )),
          if (group.timeline.isNotEmpty) _buildGroupTimelineSection(group.timeline),
        ],
      ),
    );
  }

  String _timelineEventLabel(AdminGroupTimelineEvent e) {
    switch (e.type) {
      case 'pickup':
        return e.storeName != null ? 'استلام من ${e.storeName}' : 'استلام من متجر';
      default:
        return e.label;
    }
  }

  // ✅ سجل زمني كامل للمجموعة (#10) - مبني بالكامل من بيانات موجودة أصلًا
  // (created_at/assigned_at + status_history لكل طلب عضو)، راجع
  // adminController.buildGroupTimeline
  Widget _buildGroupTimelineSection(List<AdminGroupTimelineEvent> timeline) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('السجل الزمني', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          const SizedBox(height: 6),
          ...timeline.map((e) {
            final at = e.at?.toLocal();
            final timeLabel = at != null
                ? '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'
                : '--:--';
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: brandColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(timeLabel, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFeatures: const [FontFeature.tabularFigures()])),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_timelineEventLabel(e), style: const TextStyle(fontSize: 11.5))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ✅ سبب التجميع (Grouping Reason) - ليش هاد الطلب انضم للمجموعة (مسافات
  // فعلية + القواعد اللي تحققت). فاضي لأول عضو (anchor) - هو ما "انضم" لشي
  Widget _buildGroupingReasonSection(AdminDeliveryGroupStop s) {
    final rules = s.rulesSatisfied;
    if (rules == null || rules.isEmpty) return const SizedBox.shrink();

    final storeMeters = s.storeDistanceKm != null ? (s.storeDistanceKm! * 1000).round() : null;
    final deliveryMeters = s.deliveryDistanceKm != null ? (s.deliveryDistanceKm! * 1000).round() : null;
    final facts = [
      if (storeMeters != null) 'مسافة المتاجر: $storeMeters م',
      if (deliveryMeters != null) 'مسافة التوصيل: $deliveryMeters م',
      if (s.timeDifferenceMinutes != null) 'فارق الوقت: ${s.timeDifferenceMinutes} د',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(right: 26, top: 3, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (facts.isNotEmpty)
            Text(facts, style: TextStyle(fontSize: 10.5, color: Colors.grey[500])),
          const SizedBox(height: 2),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: rules.map((rule) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 11, color: AppColors.accent),
                  const SizedBox(width: 3),
                  Text(_groupingRuleLabel(rule), style: const TextStyle(fontSize: 10.5, color: AppColors.accent)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _groupingRuleLabel(String rule) {
    switch (rule) {
      case 'same_customer':
        return 'نفس الزبون';
      case 'store_distance':
        return 'المتاجر بمسافة مسموحة';
      case 'delivery_distance':
        return 'التوصيل بمسافة مسموحة';
      case 'time_window':
        return 'خلال الوقت المسموح';
      default:
        return rule;
    }
  }

  // ✅ Delivery Management → Grouped Delivery Settings: قواعد التجميع
  // بالباك اند (services/grouping/config.js سابقًا) صارت مخزّنة بجدول
  // system_settings وقابلة للتعديل هون - أي حفظ بينطبق فورًا على أول طلب
  // جديد بدون حاجة لإعادة نشر الباك اند
  Widget _buildDeliverySettingsTab() {
    final locale = Localizations.localeOf(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: brandColor,
                  value: _groupedDeliveryEnabled,
                  title: Text(AppLocalizations.t(locale, 'admin_settings_grouped_enabled')),
                  onChanged: (v) => setState(() => _groupedDeliveryEnabled = v),
                ),
                const Divider(),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _maxStoreDistanceCtrl,
                  label: AppLocalizations.t(locale, 'admin_settings_max_store_distance'),
                  hint: '100',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _maxDeliveryDistanceCtrl,
                  label: AppLocalizations.t(locale, 'admin_settings_max_delivery_distance'),
                  hint: '100',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _maxTimeBetweenOrdersCtrl,
                  label: AppLocalizations.t(locale, 'admin_settings_max_time_between_orders'),
                  hint: '10',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _maxOrdersPerGroupCtrl,
                  label: AppLocalizations.t(locale, 'admin_settings_max_orders_per_group'),
                  hint: '4',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _maxStoresPerTripCtrl,
                  label: AppLocalizations.t(locale, 'admin_settings_max_stores_per_trip'),
                  hint: '4',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _minimumDriverRatingCtrl,
                  label: AppLocalizations.t(locale, 'admin_settings_minimum_driver_rating'),
                  hint: '0',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    AppLocalizations.t(locale, 'admin_settings_rating_not_active'),
                    style: TextStyle(fontSize: 11.5, color: Colors.grey[500], fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: brandColor,
                  value: _autoAssignDriver,
                  title: Text(AppLocalizations.t(locale, 'admin_settings_auto_assign')),
                  subtitle: Text(
                    AppLocalizations.t(locale, 'admin_settings_auto_assign_desc'),
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  onChanged: (v) => setState(() => _autoAssignDriver = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _isSavingSettings ? null : _saveSettings,
              child: _isSavingSettings
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      AppLocalizations.t(locale, 'admin_settings_save'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
          _buildSettingsStatsSection(),
        ],
      ),
    );
  }

  // ✅ 📊 Current Statistics - يوضح للأدمن أثر إعدادات Grouped Delivery
  // الحالية على الطلبات الفعلية مباشرة، مش بس أرقام يعدّلها بالعمى. مبني
  // بالكامل من getGroupingStats (نفس مصدر بطاقات الداشبورد الرئيسية) +
  // القيم المحفوظة حاليًا بـ SystemSettings.
  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSettingsStatsSection() {
    final g = _stats.deliveryGroups;
    final currentDistanceM = (_settings.maxStoreDistance * 1000).round();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 18, color: brandColor),
              const SizedBox(width: 8),
              const Text('الإحصائيات الحالية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'أثر إعدادات التجميع الحالية على الطلبات الفعلية',
            style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 6),
          _statRow('رحلات مجمّعة اليوم', '${g.groupsCreatedToday}'),
          _statRow('رحلات تم توفيرها (إجمالًا)', '${g.tripsSaved}'),
          _statRow('الوقت التقديري الموفّر', '${g.timeSavedMinEstimate} دقيقة'),
          _statRow('متوسط عدد المتاجر بالرحلة', g.avgOrdersPerGroup.toStringAsFixed(1)),
          const Divider(),
          const SizedBox(height: 6),
          _statRow('إعداد المسافة الحالي', '$currentDistanceM م'),
          _statRow('نافذة الوقت الحالية', '${_settings.maxTimeBetweenOrders} دقيقة'),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildToast(_ToastData toast) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        toast.message,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ToastData {
  final String message;
  _ToastData(this.message);
}


class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _OrdersByStatusList extends StatelessWidget {
  final List<AdminOrdersByStatus> data;

  const _OrdersByStatusList({required this.data});

  static const Map<String, Color> _statusColors = {
    'Pending': Color(0xFFF97316),
    'Confirmed': Color(0xFF3B82F6),
    'Preparing': Color(0xFF3B82F6),
    'Ready': Color(0xFFA855F7),
    'PickedUp': Color(0xFFA855F7),
    'Delivered': Color(0xFF16A34A),
    'Cancelled': Color(0xFFDC2626),
    'Refunded': Color(0xFFDC2626),
  };

  @override
  Widget build(BuildContext context) {
    final maxCount = data.map((d) => d.count).fold<int>(0, math.max);
    return Column(
      children: data.map((d) {
        final color = _statusColors[d.status] ?? Colors.grey;
        final ratio = maxCount == 0 ? 0.0 : d.count / maxCount;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  d.status,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 10,
                    backgroundColor: Theme.of(context).dividerColor,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${d.count}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final List<AdminCategoryModel> categories;
  final List<Color> palette;

  const _CategoryPieChart({required this.categories, required this.palette});

  @override
  Widget build(BuildContext context) {
    final withStores = categories.where((c) => c.storeCount > 0).toList();
    final total = withStores.fold<int>(0, (sum, c) => sum + c.storeCount);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: CustomPaint(
            painter: _PieChartPainter(
              values: withStores.map((c) => c.storeCount).toList(),
              colors: List.generate(
                withStores.length,
                (i) => palette[i % palette.length],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(withStores.length, (i) {
              final c = withStores[i];
              final percent = total == 0
                  ? 0
                  : (c.storeCount / total * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: palette[i % palette.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${c.name} (${c.storeCount})',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<int> values;
  final List<Color> colors;

  _PieChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    double startAngle = -math.pi / 2;

    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * math.pi;
      final paint = Paint()..color = colors[i];
      canvas.drawArc(rect, startAngle, sweep, true, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}

// ============================================================
// Add Platform-Wide Coupon Dialog (الأدمن فقط - restaurant_id بيضل فاضي = عام)
// ============================================================
class _AdminCouponFormDialog extends StatefulWidget {
  final Color brandColor;
  final CouponService couponService;
  final VoidCallback onSuccess;
  final ValueChanged<String> onError;

  const _AdminCouponFormDialog({
    required this.brandColor,
    required this.couponService,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_AdminCouponFormDialog> createState() => _AdminCouponFormDialogState();
}

class _AdminCouponFormDialogState extends State<_AdminCouponFormDialog> {
  final _codeCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _minOrderCtrl = TextEditingController();
  final _maxDiscountCtrl = TextEditingController();
  final _usageLimitCtrl = TextEditingController();
  final _usageLimitPerCustomerCtrl = TextEditingController(text: '1');
  String _discountType = 'Percentage';
  bool _isSubmitting = false;

  bool get _isValid =>
      _codeCtrl.text.trim().isNotEmpty &&
      double.tryParse(_valueCtrl.text.trim()) != null;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _valueCtrl.dispose();
    _minOrderCtrl.dispose();
    _maxDiscountCtrl.dispose();
    _usageLimitCtrl.dispose();
    _usageLimitPerCustomerCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() => _isSubmitting = true);

    final result = await widget.couponService.createCoupon({
      'code': _codeCtrl.text.trim().toUpperCase(),
      'discount_type': _discountType,
      'discount_value': double.parse(_valueCtrl.text.trim()),
      'min_order_amount': double.tryParse(_minOrderCtrl.text.trim()) ?? 0,
      'max_discount_amount': double.tryParse(_maxDiscountCtrl.text.trim()),
      'usage_limit': int.tryParse(_usageLimitCtrl.text.trim()),
      'usage_limit_per_customer':
          int.tryParse(_usageLimitPerCustomerCtrl.text.trim()) ?? 1,
      // restaurant_id مقصود مش مبعوت هون - يضل فاضي بالباك إند يعني كوبون عام
    });

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      widget.onSuccess();
    } else {
      widget.onError(
        result.message.isNotEmpty ? result.message : 'تعذر إنشاء الكوبون',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'كوبون عام جديد',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _codeCtrl,
                  label: 'كود الكوبون',
                  hint: 'PLATFORM10',
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _discountType,
                  decoration: InputDecoration(
                    labelText: 'نوع الخصم',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Percentage',
                      child: Text('نسبة مئوية %'),
                    ),
                    DropdownMenuItem(
                      value: 'Fixed',
                      child: Text('مبلغ ثابت ₪'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _discountType = v ?? 'Percentage'),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _valueCtrl,
                  label: _discountType == 'Percentage'
                      ? 'نسبة الخصم %'
                      : 'مبلغ الخصم ₪',
                  hint: _discountType == 'Percentage' ? '10' : '5',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _minOrderCtrl,
                  label: 'أقل قيمة طلب (اختياري)',
                  hint: '0',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                if (_discountType == 'Percentage') ...[
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _maxDiscountCtrl,
                    label: 'أقصى مبلغ خصم (اختياري)',
                    hint: 'بدون حد',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _usageLimitCtrl,
                        label: 'الحد الأقصى للاستخدام (اختياري)',
                        hint: 'بدون حد',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: _usageLimitPerCustomerCtrl,
                        label: 'مرات لكل عميل',
                        hint: '1',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isValid
                          ? widget.brandColor
                          : widget.brandColor.withValues(alpha: 0.4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    onPressed: (_isValid && !_isSubmitting) ? _submit : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'إنشاء الكوبون',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
