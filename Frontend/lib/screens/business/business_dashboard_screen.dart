// lib/screens/business/business_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/order_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/store_model.dart';
import '../../providers/store_provider.dart';
import '../../services/company_service.dart';
import '../../services/coupon_service.dart';
import '../../services/order_service.dart';
import '../../services/store_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/location_picker_map.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/vendor_drawer.dart';
import '../../widgets/vendor_header.dart';
import '../../widgets/vendor_sidebar.dart';
import '../stores/store_detail_screen.dart';
import 'store_analytics_tab.dart';
import 'store_setup_screen.dart';

class BusinessDashboardScreen extends ConsumerStatefulWidget {
  // ✅ لدعم التنقل المباشر لتبويب معيّن (من VendorDrawer مثلاً) بدل ما نبلش
  // دايمًا من تبويب Orders
  final int initialTab;
  final bool autoOpenAddProduct;

  const BusinessDashboardScreen({
    super.key,
    this.initialTab = 0,
    this.autoOpenAddProduct = false,
  });

  @override
  ConsumerState<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState
    extends ConsumerState<BusinessDashboardScreen> {
  static const Color brandColor = Color(0xFF1B835A);

  late int _selectedTab = widget.initialTab; // 0 = Orders, 1 = Products, 2 = Coupons, 3 = Settings

  final _orderService = OrderService();
  final _storeService = StoreService();
  final _couponService = CouponService();

  List<OrderModel> _orders = [];
  List<ProductModel> _products = [];
  List<CouponModel> _coupons = [];
  bool _isLoadingOrders = true;
  bool _isLoadingProducts = true;
  bool _isLoadingCoupons = true;
  bool _storeCheckDone = false; // بيصير true بعد أول استدعاء لـ fetchMyStore

  // نظام Toast بسيط يظهر بأسفل يمين الشاشة (متل التصميم بالويب)
  final List<_ToastData> _toasts = [];

  // بحث بشريط الهيدر (عرض الويب فقط) - بيفلتر تبويبي الطلبات والمنتجات حسب
  // رقم الطلب/اسم المنتج، بدون ما يأثر على الأعداد الظاهرة بتبويبات الـ tabs.
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<OrderModel> get _filteredOrders {
    if (_searchQuery.isEmpty) return _orders;
    return _orders
        .where(
          (o) =>
              o.orderNumber.toLowerCase().contains(_searchQuery) ||
              o.items.any((i) => i.name.toLowerCase().contains(_searchQuery)),
        )
        .toList();
  }

  List<ProductModel> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products
        .where((p) => p.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(storeProvider.notifier).fetchMyStore();
      if (!mounted) return;
      setState(() => _storeCheckDone = true);
      _loadOrders();
      _loadProducts();
      _loadCoupons();
      // ✅ جاي من VendorDrawer بنية "إضافة منتج مباشرة" - نفتح الـ dialog
      // تلقائيًا بعد ما يتحمّل المتجر
      final store = ref.read(storeProvider).store;
      if (widget.autoOpenAddProduct && store != null) {
        _openProductDialog(store);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoadingOrders = true);
    final result = await _orderService.getMyOrders();
    if (!mounted) return;
    setState(() {
      _isLoadingOrders = false;
      if (result.success) _orders = result.orders;
    });
  }

  Future<void> _loadProducts() async {
    final storeId = ref.read(storeProvider).store?.id;
    if (storeId == null) return;
    setState(() => _isLoadingProducts = true);
    final products = await _storeService.getStoreProducts(storeId);
    if (!mounted) return;
    setState(() {
      _products = products;
      _isLoadingProducts = false;
    });
  }

  Future<void> _loadCoupons() async {
    setState(() => _isLoadingCoupons = true);
    final result = await _couponService.getMyCoupons();
    if (!mounted) return;
    setState(() {
      _isLoadingCoupons = false;
      if (result.success) _coupons = result.coupons;
    });
  }

  Future<void> _toggleCouponActive(CouponModel coupon) async {
    final result = await _couponService.updateCoupon(coupon.id, {'is_active': !coupon.isActive});
    if (!mounted) return;
    if (result.success) {
      _loadCoupons();
    } else {
      _showToast(result.message.isNotEmpty ? result.message : 'تعذر تحديث الكوبون');
    }
  }

  void _openCouponDialog() {
    showDialog(
      context: context,
      builder: (context) => _CouponFormDialog(
        brandColor: brandColor,
        couponService: _couponService,
        onSuccess: () {
          Navigator.pop(context);
          _showToast('تم إنشاء الكوبون');
          _loadCoupons();
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

  @override
  Widget build(BuildContext context) {
    final storeState = ref.watch(storeProvider);
    final store = storeState.store;

    return Scaffold(
      // ✅ الـ Drawer يضل موجود لعرض الموبايل/التابلت - بعرض الويب الـ
      // VendorSidebar الثابتة بالأسفل بتحل محله بصريًا.
      drawer: const VendorDrawer(),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWeb = constraints.maxWidth > 900;
              final headerPadding = isWeb ? constraints.maxWidth * 0.06 : 20.0;
              final content = !_storeCheckDone && store == null
                  ? const Center(child: CircularProgressIndicator())
                  : store == null
                  ? _buildNoStoreYet()
                  : LayoutBuilder(
                      builder: (context, innerConstraints) {
                        final padding = isWeb
                            ? innerConstraints.maxWidth * 0.06
                            : 20.0;
                        return SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: padding,
                            vertical: 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatCards(store),
                              const SizedBox(height: 20),
                              _buildTabsRow(),
                              const SizedBox(height: 20),
                              _buildTabContent(store),
                            ],
                          ),
                        );
                      },
                    );
              return SafeArea(
                child: Row(
                  children: [
                    if (isWeb) const VendorSidebar(),
                    Expanded(
                      child: Column(
                        children: [
                          if (store != null)
                            VendorHeader(
                              isWeb: isWeb,
                              padding: headerPadding,
                              store: store,
                              searchController: _searchCtrl,
                            ),
                          Expanded(child: content),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Toasts أسفل يمين الشاشة
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _toasts.map((t) => _buildToast(t)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ما في متجر لسا: بندعو صاحب الحساب لتهيئة متجره الأول
  // ============================================================
  Widget _buildNoStoreYet() {
    final locale = Localizations.localeOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: brandColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.storefront, color: brandColor, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.t(locale, 'bizdash_no_store_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.t(locale, 'bizdash_no_store_desc'),
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 220,
              child: CustomButton(
                text: AppLocalizations.t(locale, 'bizdash_create_store'),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StoreSetupScreen()),
                  );
                  if (!mounted) return;
                  ref.read(storeProvider.notifier).fetchMyStore();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 4 كروت الإحصائيات
  // ============================================================
  Widget _buildStatCards(StoreModel store) {
    final locale = Localizations.localeOf(context);
    final totalOrders = _orders.length;
    final revenue = _orders.fold<double>(0, (sum, o) => sum + (o.finalAmount));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final cards = [
          StatTile(
            large: true,
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFF3B82F6),
            value: '$totalOrders',
            label: AppLocalizations.t(locale, 'bizdash_total_orders'),
          ),
          StatTile(
            large: true,
            icon: Icons.attach_money,
            iconColor: const Color(0xFF16A34A),
            value: '₪${revenue.toStringAsFixed(2)}',
            label: AppLocalizations.t(locale, 'bizdash_revenue'),
          ),
          StatTile(
            large: true,
            icon: Icons.shopping_bag_outlined,
            iconColor: const Color(0xFFA855F7),
            value: '${_products.length}',
            label: AppLocalizations.t(locale, 'bizdash_products'),
          ),
          StatTile(
            large: true,
            icon: Icons.star_outline,
            iconColor: const Color(0xFFF97316),
            value: store.averageRating.toStringAsFixed(1),
            label: AppLocalizations.t(locale, 'bizdash_rating'),
          ),
        ];

        if (isNarrow) {
          return Column(
            children: cards
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: c,
                  ),
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
      },
    );
  }

  // ============================================================
  // تبويبات Orders / Products / Settings (شكل Pill)
  // ============================================================
  Widget _buildTabsRow() {
    final locale = Localizations.localeOf(context);
    final tabs = [
      '${AppLocalizations.t(locale, 'bizdash_tab_orders')} (${_orders.length})',
      '${AppLocalizations.t(locale, 'bizdash_tab_products')} (${_products.length})',
      'الكوبونات (${_coupons.length})',
      AppLocalizations.t(locale, 'bizdash_tab_settings'),
      'التحليلات',
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    // ✅ خلفية صريحة (مش dividerColor اللي بيبين شبه شفاف/باهت) + حدّ واضح -
    // عشان الشريط يبين كصندوق واحد محدد بدل خلفية غامضة.
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : AppColors.lightSurfaceLow;
    final unselectedTextColor = isDark ? Colors.white70 : const Color(0xFF44494F);

    // ✅ Align + SingleChildScrollView(horizontal) بدل ما نعتمد بس على
    // Row(mainAxisSize.min) - بيضمن إن الشريط يلف حول محتواه بالضبط (مش
    // يتمدد لعرض الشاشة كامل) وما بيطفح لو الشاشة ضيقة و5 تبويبات.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(tabs.length, (index) {
              final isSelected = _selectedTab == index;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).cardColor
                          : Colors.transparent,
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
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : unselectedTextColor,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(StoreModel store) {
    switch (_selectedTab) {
      case 0:
        return _OrdersTabContent(
          orders: _filteredOrders,
          isLoading: _isLoadingOrders,
          brandColor: brandColor,
          orderService: _orderService,
          onChanged: () {
            _loadOrders();
          },
          onToast: _showToast,
          onOpenSettings: () => setState(() => _selectedTab = 3),
          onPreviewStore: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => StoreDetailScreen(store: store)),
          ),
          isSearchFiltered: _searchQuery.isNotEmpty,
        );
      case 1:
        return _buildProductsTab(store);
      case 2:
        return _buildCouponsTab();
      case 3:
        return _SettingsForm(
          store: store,
          storeService: _storeService,
          brandColor: brandColor,
          onSaved: () {
            _showToast(
              AppLocalizations.t(
                Localizations.localeOf(context),
                'bizdash_store_updated',
              ),
            );
            ref.read(storeProvider.notifier).fetchMyStore();
          },
        );
      case 4:
        return const StoreAnalyticsTabContent();
      default:
        return const SizedBox.shrink();
    }
  }

  // ============================================================
  // Products tab
  // ============================================================
  Widget _buildProductsTab(StoreModel store) {
    final locale = Localizations.localeOf(context);
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
            onPressed: () => _openProductDialog(store),
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              AppLocalizations.t(locale, 'bizdash_add_product'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_isLoadingProducts)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 80),
            child: Center(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  children: [
                    TextSpan(
                      text: AppLocalizations.t(
                        locale,
                        'bizdash_no_products_prefix',
                      ),
                    ),
                    TextSpan(
                      text: AppLocalizations.t(
                        locale,
                        'bizdash_no_products_link',
                      ),
                      style: TextStyle(
                        color: brandColor,
                        fontWeight: FontWeight.w600,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => _openProductDialog(store),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (_filteredProducts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 80),
            child: Center(
              child: Text(
                AppLocalizations.t(locale, 'bizdash_no_search_results'),
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 950
                  ? 4
                  : (constraints.maxWidth > 650 ? 3 : 2);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.78,
                ),
                itemCount: _filteredProducts.length,
                itemBuilder: (context, i) {
                  final p = _filteredProducts[i];
                  return _ProductCard(
                    product: p,
                    brandColor: brandColor,
                    onEdit: () => _openProductDialog(store, existing: p),
                    onDelete: () => _confirmDeleteProduct(store, p),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  // ============================================================
  // Coupons tab
  // ============================================================
  Widget _buildCouponsTab() {
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            onPressed: _openCouponDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إضافة كوبون', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 24),
        if (_isLoadingCoupons)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_coupons.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 80),
            child: Center(
              child: Text('لا يوجد كوبونات بعد', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            ),
          )
        else
          ..._coupons.map(_buildCouponRow),
      ],
    );
  }

  Widget _buildCouponRow(CouponModel coupon) {
    final discountLabel = coupon.discountType == 'Percentage'
        ? '${coupon.discountValue.toStringAsFixed(0)}%'
        : '₪${coupon.discountValue.toStringAsFixed(2)}';
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
                Text(coupon.code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  'خصم $discountLabel • استُخدم ${coupon.usedCount}${coupon.usageLimit != null ? '/${coupon.usageLimit}' : ''} مرة',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: coupon.isActive,
            activeThumbColor: brandColor,
            onChanged: (_) => _toggleCouponActive(coupon),
          ),
        ],
      ),
    );
  }

  void _openProductDialog(StoreModel store, {ProductModel? existing}) {
    final locale = Localizations.localeOf(context);
    showDialog(
      context: context,
      builder: (context) => _ProductFormDialog(
        storeId: store.id,
        existing: existing,
        brandColor: brandColor,
        storeService: _storeService,
        onSuccess: (isEdit) {
          Navigator.pop(context);
          _showToast(
            isEdit
                ? AppLocalizations.t(locale, 'bizdash_product_updated')
                : AppLocalizations.t(locale, 'bizdash_product_added'),
          );
          _loadProducts();
        },
        onError: (message) {
          _showToast(message);
        },
      ),
    );
  }

  Future<void> _confirmDeleteProduct(
    StoreModel store,
    ProductModel product,
  ) async {
    final locale = Localizations.localeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.t(locale, 'bizdash_delete_product_title')),
        content: Text(
          '${AppLocalizations.t(locale, 'bizdash_delete_product_confirm_prefix')}'
          '"${product.name}"'
          '${AppLocalizations.t(locale, 'bizdash_delete_product_confirm_suffix')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.t(locale, 'bizdash_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.t(locale, 'bizdash_delete'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await _storeService.deleteProduct(
      storeId: store.id,
      productId: product.id,
    );
    if (!mounted) return;
    if (result.success) {
      _showToast(AppLocalizations.t(locale, 'bizdash_product_deleted'));
      _loadProducts();
    } else {
      _showToast(
        result.message.isNotEmpty
            ? result.message
            : AppLocalizations.t(locale, 'bizdash_delete_failed'),
      );
    }
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

// ============================================================
// Orders tab: إدارة الطلبات بآلة الحالة الكاملة
// Pending → Confirmed → Preparing → Ready → (PickedUp → Delivered
// خطوتين الأخيرتين تبع السائق، مو صاحب المتجر) + إمكانية الإلغاء
// ============================================================
class _OrdersTabContent extends StatefulWidget {
  final List<OrderModel> orders;
  final bool isLoading;
  final Color brandColor;
  final OrderService orderService;
  final VoidCallback onChanged;
  final ValueChanged<String> onToast;
  final VoidCallback onOpenSettings;
  final VoidCallback onPreviewStore;
  // ✅ true لو المستخدم كاتب بحث وفلترته طلعت فاضية - منفرّق بينها وبين
  // "ما في طلبات إطلاقًا" عشان ما نعرض دعوة لتفعيل المتجر بالغلط.
  final bool isSearchFiltered;

  const _OrdersTabContent({
    required this.orders,
    required this.isLoading,
    required this.brandColor,
    required this.orderService,
    required this.onChanged,
    required this.onToast,
    required this.onOpenSettings,
    required this.onPreviewStore,
    this.isSearchFiltered = false,
  });

  @override
  State<_OrdersTabContent> createState() => _OrdersTabContentState();
}

class _OrdersTabContentState extends State<_OrdersTabContent> {
  final Set<String> _updatingIds = {};

  // الحالة التالية اللي صاحب المتجر بيقدر يحرّك الطلب إلها
  static const Map<String, String> _nextStatus = {
    'Pending': 'Confirmed',
    'Confirmed': 'Preparing',
    'Preparing': 'Ready',
  };

  String? _nextActionLabel(String status) {
    final locale = Localizations.localeOf(context);
    final labels = {
      'Pending': AppLocalizations.t(locale, 'bizdash_action_confirm_order'),
      'Confirmed': AppLocalizations.t(locale, 'bizdash_action_start_preparing'),
      'Preparing': AppLocalizations.t(locale, 'bizdash_action_mark_ready'),
    };
    return labels[status];
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFF97316); // برتقالي
      case 'Confirmed':
      case 'Preparing':
        return const Color(0xFF3B82F6); // أزرق
      case 'Ready':
      case 'PickedUp':
        return const Color(0xFFA855F7); // بنفسجي
      case 'Delivered':
        return widget.brandColor;
      case 'Cancelled':
      case 'Refunded':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    final locale = Localizations.localeOf(context);
    final labels = {
      'Pending': AppLocalizations.t(locale, 'bizdash_status_pending'),
      'Confirmed': AppLocalizations.t(locale, 'bizdash_status_confirmed'),
      'Preparing': AppLocalizations.t(locale, 'bizdash_status_preparing'),
      'Ready': AppLocalizations.t(locale, 'bizdash_status_ready'),
      'PickedUp': AppLocalizations.t(locale, 'bizdash_status_pickedup'),
      'Delivered': AppLocalizations.t(locale, 'bizdash_status_delivered'),
      'Cancelled': AppLocalizations.t(locale, 'bizdash_status_cancelled'),
      'Refunded': AppLocalizations.t(locale, 'bizdash_status_refunded'),
    };
    return labels[status] ?? status;
  }

  Future<void> _updateStatus(OrderModel order, String newStatus) async {
    final locale = Localizations.localeOf(context);
    setState(() => _updatingIds.add(order.id));
    final result = await widget.orderService.updateOrderStatus(
      orderId: order.id,
      status: newStatus,
    );
    if (!mounted) return;
    setState(() => _updatingIds.remove(order.id));

    if (result.success) {
      widget.onToast(
        newStatus == 'Cancelled'
            ? AppLocalizations.t(locale, 'bizdash_order_cancelled')
            : '${AppLocalizations.t(locale, 'bizdash_order_marked_as_prefix')}${_statusLabel(newStatus)}',
      );
      widget.onChanged();
    } else {
      widget.onToast(
        result.message.isNotEmpty
            ? result.message
            : AppLocalizations.t(locale, 'bizdash_could_not_update_order'),
      );
    }
  }

  Future<void> _confirmCancel(OrderModel order) async {
    final locale = Localizations.localeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.t(locale, 'bizdash_cancel_order_title')),
        content: Text(
          '${AppLocalizations.t(locale, 'bizdash_cancel_order_confirm_prefix')}'
          '${order.orderNumber}'
          '${AppLocalizations.t(locale, 'bizdash_cancel_order_confirm_suffix')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.t(locale, 'bizdash_back')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.t(locale, 'bizdash_yes_cancel'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _updateStatus(order, 'Cancelled');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.orders.isEmpty && widget.isSearchFiltered) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 100),
        child: Center(
          child: Text(
            AppLocalizations.t(
              Localizations.localeOf(context),
              'bizdash_no_search_results',
            ),
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
      );
    }

    if (widget.orders.isEmpty) {
      final locale = Localizations.localeOf(context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: widget.brandColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.storefront_outlined,
                  size: 44,
                  color: widget.brandColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.t(locale, 'bizdash_no_orders_yet'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(
                  AppLocalizations.t(locale, 'bizdash_no_orders_desc'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: widget.onOpenSettings,
                    child: Text(
                      AppLocalizations.t(locale, 'bizdash_store_settings'),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.brandColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: widget.onPreviewStore,
                    child: Text(
                      AppLocalizations.t(locale, 'bizdash_preview_store'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final activeStatuses = {
      'Pending',
      'Confirmed',
      'Preparing',
      'Ready',
      'PickedUp',
    };
    final active = widget.orders
        .where((o) => activeStatuses.contains(o.status))
        .toList();
    final past = widget.orders
        .where((o) => !activeStatuses.contains(o.status))
        .toList();

    final locale = Localizations.localeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active.isNotEmpty) ...[
          Text(
            AppLocalizations.t(locale, 'bizdash_active_orders'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...active.map(_buildOrderCard),
        ],
        if (past.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            AppLocalizations.t(locale, 'bizdash_order_history'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...past.map(_buildOrderCard),
        ],
      ],
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final locale = Localizations.localeOf(context);
    final color = _statusColor(order.status);
    final isUpdating = _updatingIds.contains(order.id);
    final nextStatus = _nextStatus[order.status];
    final canCancel = !{
      'Delivered',
      'Cancelled',
      'Refunded',
      'PickedUp',
    }.contains(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.orderNumber,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(order.status),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${item.quantity}x ${item.name}',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.deliveryAddress,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'ملاحظة: ${order.specialInstructions}',
              style: TextStyle(color: Colors.orange[800], fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₪${order.finalAmount.toStringAsFixed(2)} • ${order.paymentMethod}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Row(
                children: [
                  if (canCancel)
                    TextButton(
                      onPressed: isUpdating
                          ? null
                          : () => _confirmCancel(order),
                      child: Text(
                        AppLocalizations.t(locale, 'bizdash_cancel'),
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  if (nextStatus != null) ...[
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.brandColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: isUpdating
                          ? null
                          : () => _updateStatus(order, nextStatus),
                      child: isUpdating
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _nextActionLabel(order.status) ??
                                  AppLocalizations.t(locale, 'bizdash_update'),
                            ),
                    ),
                  ] else if (order.status == 'Ready' ||
                      order.status == 'PickedUp') ...[
                    Text(
                      order.status == 'Ready'
                          ? AppLocalizations.t(locale, 'bizdash_waiting_driver')
                          : AppLocalizations.t(locale, 'bizdash_on_way_driver'),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// ============================================================
// Product card (شكل الصورة 6)
// ============================================================
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final Color brandColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.brandColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.5,
            child: product.imageUrl.isNotEmpty
                ? Image.network(product.imageUrl, fit: BoxFit.cover)
                : Container(
                    color: Theme.of(context).dividerColor,
                    child: const Icon(Icons.image_outlined, color: Colors.grey),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (product.inStock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: brandColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          AppLocalizations.t(locale, 'bizdash_in_stock'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          AppLocalizations.t(locale, 'bizdash_out_of_stock'),
                          style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodyLarge?.color),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '₪${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).textTheme.bodyLarge?.color,
                          side: BorderSide(color: Theme.of(context).dividerColor),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: Text(
                          AppLocalizations.t(locale, 'bizdash_edit'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(color: Colors.red.shade100),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onDelete,
                      child: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Add / Edit Product Dialog (شكل الصورة 5 و 7/8)
// ============================================================
/// حالة صف "مجموعة مواصفات مخصصة" واحدة داخل نموذج المنتج - اسم المجموعة،
/// نوع الاختيار (واحد/أكتر)، هل إجبارية، وقائمة صفوف قيمها (اسم + سعر اختياري).
class _OptionGroupRow {
  final TextEditingController nameCtrl;
  String selectionMode; // 'single' أو 'multiple'
  bool isRequired;
  final List<(TextEditingController, TextEditingController)> valueRows;

  _OptionGroupRow({
    required this.nameCtrl,
    this.selectionMode = 'single',
    this.isRequired = false,
    List<(TextEditingController, TextEditingController)>? valueRows,
  }) : valueRows = valueRows ?? [];

  void dispose() {
    nameCtrl.dispose();
    for (final row in valueRows) {
      row.$1.dispose();
      row.$2.dispose();
    }
  }
}

class _ProductFormDialog extends StatefulWidget {
  final String storeId;
  final ProductModel? existing;
  final Color brandColor;
  final StoreService storeService;
  final ValueChanged<bool> onSuccess; // true = edit, false = add
  final ValueChanged<String> onError;

  const _ProductFormDialog({
    required this.storeId,
    required this.existing,
    required this.brandColor,
    required this.storeService,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _imageCtrl;
  late TextEditingController _extraImagesCtrl;
  bool _inStock = true;
  bool _isFeatured = false;
  bool _isSubmitting = false;

  // كل صف = (تحكم اسم الحجم، تحكم سعره) - Small/Medium/Large وهيك
  final List<(TextEditingController, TextEditingController)> _variantRows = [];

  // كل صف = (تحكم اسم الإضافة، تحكم سعرها) - Extra Cheese +$1.50 وهيك
  final List<(TextEditingController, TextEditingController)> _addonRows = [];

  // كل صف = تحكم نص الطلب الخاص - No Onions وهيك
  final List<TextEditingController> _exclusionRows = [];

  // مجموعات مواصفات مخصصة يحددها صاحب المحل (نوع الخبز، اللون...) - كل
  // مجموعة إلها اسم، نوع اختيار، هل إجبارية، وقائمة قيم بأسعار اختيارية
  final List<_OptionGroupRow> _optionGroupRows = [];

  bool get _isEdit => widget.existing != null;

  bool get _isValid =>
      _nameCtrl.text.trim().isNotEmpty &&
      double.tryParse(_priceCtrl.text.trim()) != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _priceCtrl = TextEditingController(text: p?.price.toString() ?? '');
    _imageCtrl = TextEditingController(text: p?.imageUrl ?? '');
    _extraImagesCtrl = TextEditingController(text: (p?.images ?? []).join('\n'));
    _inStock = p?.inStock ?? true;
    _isFeatured = p?.isFeatured ?? false;

    for (final v in p?.variants ?? []) {
      _variantRows.add((
        TextEditingController(text: v.label),
        TextEditingController(text: v.price.toString()),
      ));
    }

    for (final a in p?.addons ?? []) {
      _addonRows.add((
        TextEditingController(text: a.name),
        TextEditingController(text: a.price.toString()),
      ));
    }

    for (final e in p?.exclusions ?? []) {
      _exclusionRows.add(TextEditingController(text: e.label));
    }

    for (final g in p?.optionGroups ?? []) {
      final row = _OptionGroupRow(
        nameCtrl: TextEditingController(text: g.name),
        selectionMode: g.selectionMode,
        isRequired: g.isRequired,
      );
      for (final v in g.values) {
        row.valueRows.add((
          TextEditingController(text: v.label),
          TextEditingController(text: v.price.toString()),
        ));
      }
      _optionGroupRows.add(row);
    }

    for (final c in [_nameCtrl, _descCtrl, _priceCtrl, _imageCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _imageCtrl.dispose();
    _extraImagesCtrl.dispose();
    for (final row in _variantRows) {
      row.$1.dispose();
      row.$2.dispose();
    }
    for (final row in _addonRows) {
      row.$1.dispose();
      row.$2.dispose();
    }
    for (final ctrl in _exclusionRows) {
      ctrl.dispose();
    }
    for (final row in _optionGroupRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addVariantRow() {
    setState(() {
      _variantRows.add((TextEditingController(), TextEditingController()));
    });
  }

  void _removeVariantRow(int index) {
    setState(() {
      _variantRows[index].$1.dispose();
      _variantRows[index].$2.dispose();
      _variantRows.removeAt(index);
    });
  }

  void _addAddonRow() {
    setState(() {
      _addonRows.add((TextEditingController(), TextEditingController()));
    });
  }

  void _removeAddonRow(int index) {
    setState(() {
      _addonRows[index].$1.dispose();
      _addonRows[index].$2.dispose();
      _addonRows.removeAt(index);
    });
  }

  void _addExclusionRow() {
    setState(() {
      _exclusionRows.add(TextEditingController());
    });
  }

  void _removeExclusionRow(int index) {
    setState(() {
      _exclusionRows[index].dispose();
      _exclusionRows.removeAt(index);
    });
  }

  void _addOptionGroup() {
    setState(() {
      final row = _OptionGroupRow(nameCtrl: TextEditingController());
      row.valueRows.add((TextEditingController(), TextEditingController()));
      _optionGroupRows.add(row);
    });
  }

  void _removeOptionGroup(int index) {
    setState(() {
      _optionGroupRows[index].dispose();
      _optionGroupRows.removeAt(index);
    });
  }

  void _addOptionValueRow(int groupIndex) {
    setState(() {
      _optionGroupRows[groupIndex].valueRows.add((TextEditingController(), TextEditingController()));
    });
  }

  void _removeOptionValueRow(int groupIndex, int valueIndex) {
    setState(() {
      final row = _optionGroupRows[groupIndex].valueRows[valueIndex];
      row.$1.dispose();
      row.$2.dispose();
      _optionGroupRows[groupIndex].valueRows.removeAt(valueIndex);
    });
  }

  Future<void> _submit() async {
    if (!_isValid) return;
    final locale = Localizations.localeOf(context);
    setState(() => _isSubmitting = true);

    final price = double.parse(_priceCtrl.text.trim());
    final images = _extraImagesCtrl.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final variants = _variantRows
        .where((row) => row.$1.text.trim().isNotEmpty && double.tryParse(row.$2.text.trim()) != null)
        .map((row) => {
              'label': row.$1.text.trim(),
              'price': double.parse(row.$2.text.trim()),
            })
        .toList();
    final addons = _addonRows
        .where((row) => row.$1.text.trim().isNotEmpty && double.tryParse(row.$2.text.trim()) != null)
        .map((row) => {
              'name': row.$1.text.trim(),
              'price': double.parse(row.$2.text.trim()),
            })
        .toList();
    final exclusions = _exclusionRows
        .map((ctrl) => ctrl.text.trim())
        .where((label) => label.isNotEmpty)
        .toList();
    final optionGroups = _optionGroupRows
        .map((g) => {
              'name': g.nameCtrl.text.trim(),
              'selection_mode': g.selectionMode,
              'is_required': g.isRequired,
              'values': g.valueRows
                  .where((row) => row.$1.text.trim().isNotEmpty)
                  .map((row) => {
                        'label': row.$1.text.trim(),
                        'price': double.tryParse(row.$2.text.trim()) ?? 0,
                      })
                  .toList(),
            })
        .where((g) => (g['name'] as String).isNotEmpty && (g['values'] as List).isNotEmpty)
        .toList();

    final result = _isEdit
        ? await widget.storeService.updateProduct(
            storeId: widget.storeId,
            productId: widget.existing!.id,
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            price: price,
            imageUrl: _imageCtrl.text.trim(),
            inStock: _inStock,
            images: images,
            variants: variants,
            addons: addons,
            exclusions: exclusions,
            optionGroups: optionGroups,
            isFeatured: _isFeatured,
          )
        : await widget.storeService.addProduct(
            storeId: widget.storeId,
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            price: price,
            imageUrl: _imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim(),
            images: images,
            variants: variants,
            addons: addons,
            exclusions: exclusions,
            optionGroups: optionGroups,
            isFeatured: _isFeatured,
          );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      widget.onSuccess(_isEdit);
    } else {
      widget.onError(
        result.message.isNotEmpty
            ? result.message
            : AppLocalizations.t(locale, 'bizdash_something_wrong'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEdit
                        ? AppLocalizations.t(locale, 'bizdash_edit_product')
                        : AppLocalizations.t(locale, 'bizdash_add_product'),
                    style: const TextStyle(
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
                controller: _nameCtrl,
                label: AppLocalizations.t(locale, 'bizdash_field_name'),
                hint: AppLocalizations.t(locale, 'bizdash_hint_product_name'),
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: _descCtrl,
                label: AppLocalizations.t(locale, 'bizdash_field_description'),
                hint: '',
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: _priceCtrl,
                label: AppLocalizations.t(locale, 'bizdash_field_price'),
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: _imageCtrl,
                label: AppLocalizations.t(locale, 'bizdash_field_image_url'),
                hint: 'https://...',
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: _extraImagesCtrl,
                label: AppLocalizations.t(locale, 'bizdash_field_extra_images'),
                hint: 'https://...\nhttps://...',
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              Text(
                AppLocalizations.t(locale, 'bizdash_field_variants'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ..._variantRows.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: CustomTextField(
                          controller: row.$1,
                          label: '',
                          hint: AppLocalizations.t(locale, 'bizdash_hint_variant_label'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: CustomTextField(
                          controller: row.$2,
                          label: '',
                          hint: '0.00',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                        onPressed: () => _removeVariantRow(index),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _addVariantRow,
                icon: const Icon(Icons.add, size: 16),
                label: Text(AppLocalizations.t(locale, 'bizdash_add_variant')),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.t(locale, 'bizdash_field_addons'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ..._addonRows.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: CustomTextField(
                          controller: row.$1,
                          label: '',
                          hint: AppLocalizations.t(locale, 'bizdash_hint_addon_name'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: CustomTextField(
                          controller: row.$2,
                          label: '',
                          hint: '0.00',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                        onPressed: () => _removeAddonRow(index),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _addAddonRow,
                icon: const Icon(Icons.add, size: 16),
                label: Text(AppLocalizations.t(locale, 'bizdash_add_addon')),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.t(locale, 'bizdash_field_exclusions'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ..._exclusionRows.asMap().entries.map((entry) {
                final index = entry.key;
                final ctrl = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: ctrl,
                          label: '',
                          hint: AppLocalizations.t(locale, 'bizdash_hint_exclusion_label'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                        onPressed: () => _removeExclusionRow(index),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _addExclusionRow,
                icon: const Icon(Icons.add, size: 16),
                label: Text(AppLocalizations.t(locale, 'bizdash_add_exclusion')),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.t(locale, 'bizdash_field_option_groups'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ..._optionGroupRows.asMap().entries.map((entry) {
                final groupIndex = entry.key;
                final group = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: group.nameCtrl,
                              label: '',
                              hint: AppLocalizations.t(locale, 'bizdash_hint_option_group_name'),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                            onPressed: () => _removeOptionGroup(groupIndex),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text(
                              AppLocalizations.t(locale, 'bizdash_option_mode_single'),
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: group.selectionMode == 'single',
                            onSelected: (_) => setState(() => group.selectionMode = 'single'),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: Text(
                              AppLocalizations.t(locale, 'bizdash_option_mode_multiple'),
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: group.selectionMode == 'multiple',
                            onSelected: (_) => setState(() => group.selectionMode = 'multiple'),
                          ),
                          const Spacer(),
                          Checkbox(
                            value: group.isRequired,
                            activeColor: widget.brandColor,
                            onChanged: (v) => setState(() => group.isRequired = v ?? false),
                          ),
                          Text(
                            AppLocalizations.t(locale, 'bizdash_option_required'),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...group.valueRows.asMap().entries.map((valueEntry) {
                        final valueIndex = valueEntry.key;
                        final row = valueEntry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: CustomTextField(
                                  controller: row.$1,
                                  label: '',
                                  hint: AppLocalizations.t(locale, 'bizdash_hint_option_value_label'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: CustomTextField(
                                  controller: row.$2,
                                  label: '',
                                  hint: '0.00',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                                onPressed: () => _removeOptionValueRow(groupIndex, valueIndex),
                              ),
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(
                        onPressed: () => _addOptionValueRow(groupIndex),
                        icon: const Icon(Icons.add, size: 14),
                        label: Text(
                          AppLocalizations.t(locale, 'bizdash_add_option_value'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _addOptionGroup,
                icon: const Icon(Icons.add, size: 16),
                label: Text(AppLocalizations.t(locale, 'bizdash_add_option_group')),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Checkbox(
                    value: _inStock,
                    activeColor: widget.brandColor,
                    onChanged: (v) => setState(() => _inStock = v ?? true),
                  ),
                  Text(
                    AppLocalizations.t(locale, 'bizdash_in_stock'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  Checkbox(
                    value: _isFeatured,
                    activeColor: widget.brandColor,
                    onChanged: (v) => setState(() => _isFeatured = v ?? false),
                  ),
                  Text(
                    AppLocalizations.t(locale, 'bizdash_featured_product'),
                    style: const TextStyle(fontSize: 13),
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
                      : Text(
                          _isEdit
                              ? AppLocalizations.t(
                                  locale,
                                  'bizdash_update_product',
                                )
                              : AppLocalizations.t(
                                  locale,
                                  'bizdash_add_product',
                                ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
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

// ============================================================
// Settings tab (شكل الصورة 3 و 4)
// ============================================================
class _SettingsForm extends StatefulWidget {
  final StoreModel store;
  final StoreService storeService;
  final Color brandColor;
  final VoidCallback onSaved;

  const _SettingsForm({
    required this.store,
    required this.storeService,
    required this.brandColor,
    required this.onSaved,
  });

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  late TextEditingController _descCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _openingTimeCtrl;
  late TextEditingController _closingTimeCtrl;
  late TextEditingController _imageCtrl;

  // ✅ رسوم التوصيل حسب المنطقة + الحد الأدنى للطلب + وقت التحضير - كلها
  // مدعومة الآن بالكامل بـ StoreModel/storeController (تُحفظ وترجع صح بعد الحفظ)
  late TextEditingController _insideCtrl;
  late TextEditingController _outsideCtrl;
  late TextEditingController _occupiedCtrl;
  late TextEditingController _minOrderCtrl;
  late TextEditingController _prepTimeCtrl;
  String? _selectedCity;
  bool _supportsDelivery = true;
  bool _supportsPickup = false;

  // ✅ Phase 3 - Smart Assignment: شركة توصيل مفضّلة (اختياري) + نوع مركبة
  // مطلوب (اختياري) - راجع assignment/factors.js بالباك إند
  String? _preferredCompanyId;
  String? _requiredVehicleType;
  List<DeliveryCompanyModel> _companies = [];
  bool _loadingCompanies = true;
  static const List<String> _vehicleTypeOptions = ['Bicycle', 'Motorcycle', 'Car', 'Van'];

  // ✅ تعديل الموقع الدقيق على الخريطة (نفس LocationPickerMap المستخدمة
  // بفورم إنشاء المتجر) - null لحد ما صاحب المتجر يضغط دبوس جديد، فبنبعت
  // فقط الموقع الأصلي المخزّن (ما منغيّر شي إذا ما لمس الخارطة).
  LatLng? _pickedLocation;

  bool _isSaving = false;

  final List<String> _cities = const [
    'رام الله والبيرة',
    'نابلس',
    'الخليل',
    'جنين',
    'طولكرم',
    'قلقيلية',
    'بيت لحم',
    'أريحا',
    'سلفيت',
    'طوباس',
    'غزة',
    'خان يونس',
    'رفح',
    'دير البلح',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.store;
    _descCtrl = TextEditingController(text: s.description);
    _addressCtrl = TextEditingController(text: s.address);
    _phoneCtrl = TextEditingController(text: s.phone);
    _emailCtrl = TextEditingController(text: s.email);
    _openingTimeCtrl = TextEditingController(text: s.openingTime ?? '');
    _closingTimeCtrl = TextEditingController(text: s.closingTime ?? '');
    _imageCtrl = TextEditingController(text: s.imageUrl);

    _insideCtrl = TextEditingController(text: _fmt(s.deliveryFeeInsideCity));
    _outsideCtrl = TextEditingController(text: _fmt(s.deliveryFeeOutsideCity));
    _occupiedCtrl = TextEditingController(text: _fmt(s.deliveryFeeOccupiedAreas));
    _minOrderCtrl = TextEditingController(text: _fmt(s.minimumOrder));
    _prepTimeCtrl = TextEditingController(text: s.prepTimeMinutes.toString());
    _selectedCity = s.city.isNotEmpty ? s.city : null;
    _supportsDelivery = s.supportsDelivery;
    _supportsPickup = s.supportsPickup;
    _preferredCompanyId = s.preferredCompanyId;
    _requiredVehicleType = s.requiredVehicleType;

    _loadCompanies();
  }

  String _fmt(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  Future<void> _loadCompanies() async {
    final result = await CompanyService().getApprovedCompanies();
    if (!mounted) return;
    setState(() {
      if (result.success) _companies = result.companies;
      _loadingCompanies = false;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _descCtrl,
      _addressCtrl,
      _phoneCtrl,
      _emailCtrl,
      _openingTimeCtrl,
      _closingTimeCtrl,
      _imageCtrl,
      _insideCtrl,
      _outsideCtrl,
      _occupiedCtrl,
      _minOrderCtrl,
      _prepTimeCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final locale = Localizations.localeOf(context);
    setState(() => _isSaving = true);

    final result = await widget.storeService.updateMyStore({
      'description': _descCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'opening_time': _openingTimeCtrl.text.trim(),
      'closing_time': _closingTimeCtrl.text.trim(),
      'image_url': _imageCtrl.text.trim(),
      'city': _selectedCity,
      'delivery_fee_inside_city': double.tryParse(_insideCtrl.text) ?? 10,
      'delivery_fee_outside_city': double.tryParse(_outsideCtrl.text) ?? 20,
      'delivery_fee_occupied_areas': double.tryParse(_occupiedCtrl.text) ?? 70,
      'minimum_order': double.tryParse(_minOrderCtrl.text) ?? 0,
      'prep_time_minutes': int.tryParse(_prepTimeCtrl.text) ?? 10,
      'supports_delivery': _supportsDelivery,
      'supports_pickup': _supportsPickup,
      'preferred_company_id': _preferredCompanyId,
      'required_vehicle_type': _requiredVehicleType,
      // ✅ منبعت الموقع الجديد بس لو صاحب المتجر فعليًا لمس الخارطة - غير
      // هيك منسيب location_lat/lng متل ما هي (updateMyStore بالباك إند بيتجاهل
      // مفتاح غير موجود بالـ body ويحافظ على القيمة القديمة)
      if (_pickedLocation != null) 'location_lat': _pickedLocation!.latitude,
      if (_pickedLocation != null) 'location_lng': _pickedLocation!.longitude,
    });

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.success) {
      widget.onSaved();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isNotEmpty
                ? result.message
                : AppLocalizations.t(locale, 'bizdash_save_failed'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isPending = widget.store.approvalStatus.toLowerCase() == 'pending';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // رأس صغير فيه اسم المتجر وحالته
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time,
                  color: Colors.orange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.store.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      AppLocalizations.t(locale, 'bizdash_pending_admin_approval'),
                      style: TextStyle(color: widget.brandColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isPending)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF3FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    AppLocalizations.t(locale, 'bizdash_status_pending'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextField(
                controller: _descCtrl,
                label: AppLocalizations.t(locale, 'bizdash_field_description'),
                hint: '',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _twoCol(
                CustomTextField(
                  controller: _addressCtrl,
                  label: AppLocalizations.t(locale, 'bizdash_field_address'),
                  hint: AppLocalizations.t(locale, 'bizdash_hint_street_city'),
                ),
                CustomTextField(
                  controller: _phoneCtrl,
                  label: AppLocalizations.t(locale, 'bizdash_field_phone'),
                  hint: '+970...',
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(height: 16),
              _twoCol(
                CustomTextField(
                  controller: _emailCtrl,
                  label: AppLocalizations.t(locale, 'bizdash_field_email'),
                  hint: 'store@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                CustomTextField(
                  controller: _imageCtrl,
                  label: AppLocalizations.t(locale, 'bizdash_field_image_url'),
                  hint: 'https://...',
                ),
              ),
              const SizedBox(height: 16),
              _twoCol(
                CustomTextField(
                  controller: _openingTimeCtrl,
                  label: AppLocalizations.t(locale, 'bizdash_field_opening_time'),
                  hint: AppLocalizations.t(locale, 'bizdash_hint_opening_time'),
                ),
                CustomTextField(
                  controller: _closingTimeCtrl,
                  label: AppLocalizations.t(locale, 'bizdash_field_closing_time'),
                  hint: AppLocalizations.t(locale, 'bizdash_hint_closing_time'),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.t(locale, 'bizdash_delivery_area_pricing'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.t(locale, 'bizdash_delivery_area_desc'),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  AppLocalizations.t(locale, 'bizdash_store_location_city'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              _CityDropdown(
                hint: AppLocalizations.t(locale, 'bizdash_select_city'),
                value: _selectedCity,
                items: _cities,
                brandColor: widget.brandColor,
                onChanged: (val) => setState(() => _selectedCity = val),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  AppLocalizations.t(locale, 'bizdash_field_map_location'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              LocationPickerMap(
                initialCenter: _pickedLocation ??
                    (widget.store.latitude != null && widget.store.longitude != null
                        ? LatLng(widget.store.latitude!, widget.store.longitude!)
                        : const LatLng(31.95, 35.2)),
                onLocationSelected: (point) => setState(() => _pickedLocation = point),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _insideCtrl,
                      label: AppLocalizations.t(locale, 'bizdash_fee_inside_city'),
                      hint: '10',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _outsideCtrl,
                      label: AppLocalizations.t(locale, 'bizdash_fee_outside_city'),
                      hint: '20',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _occupiedCtrl,
                      label: AppLocalizations.t(locale, 'bizdash_fee_occupied'),
                      hint: '70',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Switch(
                    value: _supportsDelivery,
                    activeThumbColor: widget.brandColor,
                    onChanged: (v) => setState(() => _supportsDelivery = v),
                  ),
                  Text(
                    AppLocalizations.t(locale, 'bizdash_supports_delivery'),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 20),
                  Switch(
                    value: _supportsPickup,
                    activeThumbColor: widget.brandColor,
                    onChanged: (v) => setState(() => _supportsPickup = v),
                  ),
                  Text(
                    AppLocalizations.t(locale, 'bizdash_supports_pickup'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _twoCol(
                CustomTextField(
                  controller: _minOrderCtrl,
                  label: AppLocalizations.t(locale, 'storesetup_field_min_order'),
                  hint: '0',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                CustomTextField(
                  controller: _prepTimeCtrl,
                  label: AppLocalizations.t(locale, 'storesetup_field_prep_time'),
                  hint: '30',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'التعيين الذكي للسائقين',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'اختياري - لو حددتها، محرك التعيين الذكي بياخدها بعين الاعتبار عند اختيار سائق لطلباتك',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 14),
              _twoCol(
                _loadingCompanies
                    ? const SizedBox(
                        height: 48,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : DropdownButtonFormField<String?>(
                        initialValue: _preferredCompanyId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'شركة توصيل مفضّلة',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('بدون تفضيل')),
                          ..._companies.map(
                            (c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
                          ),
                        ],
                        onChanged: (v) => setState(() => _preferredCompanyId = v),
                      ),
                DropdownButtonFormField<String?>(
                  initialValue: _requiredVehicleType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'نوع مركبة مطلوب',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('أي نوع مركبة')),
                    ..._vehicleTypeOptions.map(
                      (v) => DropdownMenuItem<String?>(value: v, child: Text(v)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _requiredVehicleType = v),
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: AppLocalizations.t(locale, 'bizdash_save_changes'),
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _twoCol(Widget field1, Widget field2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field1),
        const SizedBox(width: 16),
        Expanded(child: field2),
      ],
    );
  }
}

// ============================================================
// Custom dropdown مرسوم بالكامل بـ Flutter (بدون <select> أصلي)
// ============================================================
class _CityDropdown extends StatefulWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final Color brandColor;
  final ValueChanged<String?> onChanged;

  const _CityDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.brandColor,
    required this.onChanged,
  });

  @override
  State<_CityDropdown> createState() => _CityDropdownState();
}

class _CityDropdownState extends State<_CityDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggle() => _isOpen ? _close() : _open();

  void _open() {
    final box = context.findRenderObject() as RenderBox;
    final size = box.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 6),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(10),
                color: Theme.of(context).cardColor,
                child: Container(
                  width: size.width,
                  constraints: const BoxConstraints(maxHeight: 260),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final isSelected = item == widget.value;
                      return InkWell(
                        onTap: () {
                          widget.onChanged(item);
                          _close();
                        },
                        child: Container(
                          width: double.infinity,
                          color: isSelected
                              ? widget.brandColor
                              : Theme.of(context).cardColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _close() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isOpen = false);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggle,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isOpen ? widget.brandColor : Theme.of(context).dividerColor,
              width: _isOpen ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.value ?? widget.hint,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.value != null
                        ? Theme.of(context).textTheme.bodyLarge?.color
                        : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600]),
                  ),
                ),
              ),
              Icon(
                _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Add Coupon Dialog (لصاحب المتجر - الكوبون بينحط تلقائيًا لمتجره هو بس)
// ============================================================
class _CouponFormDialog extends StatefulWidget {
  final Color brandColor;
  final CouponService couponService;
  final VoidCallback onSuccess;
  final ValueChanged<String> onError;

  const _CouponFormDialog({
    required this.brandColor,
    required this.couponService,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_CouponFormDialog> createState() => _CouponFormDialogState();
}

class _CouponFormDialogState extends State<_CouponFormDialog> {
  final _codeCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _minOrderCtrl = TextEditingController();
  final _maxDiscountCtrl = TextEditingController();
  final _usageLimitCtrl = TextEditingController();
  final _usageLimitPerCustomerCtrl = TextEditingController(text: '1');
  String _discountType = 'Percentage';
  bool _isSubmitting = false;

  bool get _isValid =>
      _codeCtrl.text.trim().isNotEmpty && double.tryParse(_valueCtrl.text.trim()) != null;

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
      'usage_limit_per_customer': int.tryParse(_usageLimitPerCustomerCtrl.text.trim()) ?? 1,
    });

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      widget.onSuccess();
    } else {
      widget.onError(result.message.isNotEmpty ? result.message : 'تعذر إنشاء الكوبون');
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
                    const Text('إضافة كوبون', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 8),
                CustomTextField(controller: _codeCtrl, label: 'كود الكوبون', hint: 'SAVE10'),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _discountType,
                  decoration: InputDecoration(
                    labelText: 'نوع الخصم',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Percentage', child: Text('نسبة مئوية %')),
                    DropdownMenuItem(value: 'Fixed', child: Text('مبلغ ثابت ₪')),
                  ],
                  onChanged: (v) => setState(() => _discountType = v ?? 'Percentage'),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _valueCtrl,
                  label: _discountType == 'Percentage' ? 'نسبة الخصم %' : 'مبلغ الخصم ₪',
                  hint: _discountType == 'Percentage' ? '10' : '5',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _minOrderCtrl,
                  label: 'أقل قيمة طلب (اختياري)',
                  hint: '0',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                if (_discountType == 'Percentage') ...[
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _maxDiscountCtrl,
                    label: 'أقصى مبلغ خصم (اختياري)',
                    hint: 'بدون حد',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      backgroundColor: _isValid ? widget.brandColor : widget.brandColor.withValues(alpha: 0.4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
                    onPressed: (_isValid && !_isSubmitting) ? _submit : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('إنشاء الكوبون', style: TextStyle(fontWeight: FontWeight.bold)),
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
