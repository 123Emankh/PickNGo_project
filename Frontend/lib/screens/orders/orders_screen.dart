// lib/screens/orders/orders_screen.dart
//
// "My Orders" - بتجيب طلبات المستخدم الحالي من /api/orders/my.
// الباك إند بيرجع نتيجة مختلفة حسب الدور تلقائياً:
// Customer -> طلباته هو، Restaurant -> طلبات محله، Driver -> طلباته يلي وصّلها.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/order_model.dart';
import '../../data/models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/order_service.dart';
import '../../services/review_service.dart';
import '../../services/store_service.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/app_card.dart';
import '../../core/constants/api_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_themes.dart';
import '../cart/cart_screen.dart';
import '../stores/store_detail_screen.dart';
import 'order_details_dialog.dart';
import 'order_tracking_screen.dart';
import 'review_dialog.dart';

const _trackableStatuses = {'Confirmed', 'Preparing', 'Ready', 'PickedUp'};

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  static const Color brandColor = AppColors.brand;

  final OrderService _orderService = OrderService();
  final ReviewService _reviewService = ReviewService();
  final StoreService _storeService = StoreService();
  bool _isLoading = true;
  String? _errorMessage;
  List<OrderModel> _orders = [];
  final Map<String, ReviewModel?> _reviewsByOrderId = {};
  // ✅ orderId -> جاري تحميل تفاصيل المتجر (لفتح صفحته أو لإعادة الطلب) -
  // تعطيل مضاعفة الضغط + عرض مؤشر تحميل صغير بدل ما نغيّر شكل الشاشة كلها
  final Set<String> _navigatingStoreIds = {};
  final Set<String> _reorderingOrderIds = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _orderService.getMyOrders();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success) {
        _orders = result.orders;
      } else {
        _errorMessage = result.message;
      }
    });

    // التقييمات معناها بس للزبون (صاحب الطلب) - نفس تحقق الملكية يلي الباك إند بيعمله
    if (ref.read(authProvider).user?.role == 'Customer') {
      _loadReviewsForDeliveredOrders();
    }
  }

  Future<void> _loadReviewsForDeliveredOrders() async {
    final deliveredOrderIds = _orders
        .where((o) => o.status == 'Delivered')
        .map((o) => o.id)
        .toList();
    if (deliveredOrderIds.isEmpty) return;

    // ✅ كان نداء شبكة منفصل لكل طلب مسلّم بحلقة for متسلسلة (N+1) - هلق
    // نداء واحد بس لكل الطلبات المسلّمة دفعة وحدة. الرد بيرجّع مفتاح بس
    // للطلبات يلي فعلاً عندها تقييم - لازم نحط null صراحة للباقي (مش نتجاهلها)
    // لأن UI تحت بيستخدم containsKey (مش القيمة) عشان يقرر يعرض زر "قيّم
    // الطلب" أصلًا، بغض النظر لو في تقييم موجود أو لأ.
    final reviews = await _reviewService.getMyReviewsForOrders(deliveredOrderIds);
    if (!mounted) return;
    setState(() {
      for (final id in deliveredOrderIds) {
        _reviewsByOrderId[id] = reviews[id];
      }
    });
  }

  Future<void> _openReviewDialog(OrderModel order) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ReviewDialog(
        orderId: order.id,
        existingReview: _reviewsByOrderId[order.id],
      ),
    );
    if (saved == true) {
      final result = await _reviewService.getReviewForOrder(order.id);
      if (!mounted) return;
      if (result.success) {
        setState(() => _reviewsByOrderId[order.id] = result.review);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  ProductModel? _findProductById(List<ProductModel> products, String productId) {
    for (final p in products) {
      if (p.id == productId) return p;
    }
    return null;
  }

  // ✅ اسم/صورة المتجر بكارد الطلب قابلين للضغط - بننادي نفس شاشة تفاصيل
  // المتجر المستخدمة من قائمة المتاجر (StoreDetailScreen) بدل ما ننشئ شاشة
  // جديدة. لازم نجيب StoreModel كامل أول (مش بس store_id) لأن الشاشة
  // بتطلبه، ولو المتجر صار غير متاح (اتحذف/اترفض) منعرض رسالة بدل كراش.
  Future<void> _openStoreDetail(OrderModel order) async {
    final storeId = order.storeId;
    if (storeId == null || storeId.isEmpty) {
      _showSnack(AppLocalizations.t(Localizations.localeOf(context), 'orders_store_info_unavailable'));
      return;
    }
    if (_navigatingStoreIds.contains(order.id)) return;

    setState(() => _navigatingStoreIds.add(order.id));
    final result = await _storeService.getStoreDetail(storeId);
    if (!mounted) return;
    setState(() => _navigatingStoreIds.remove(order.id));

    if (!result.success || result.store == null) {
      _showSnack(AppLocalizations.t(Localizations.localeOf(context), 'orders_store_unavailable'));
      return;
    }

    // ✅ Navigator.push عادي (بدون await على النتيجة) - لما نرجع بـ pop
    // كل حالة الشاشة (قائمة الطلبات، التقييمات المحمّلة) بتضل زي ما هي
    // بدون أي إعادة تحميل - نفس سلوك بقية الشاشات بهاد المشروع.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StoreDetailScreen(store: result.store!)),
    );
  }

  // ✅ "إعادة الطلب": بما إن OrderItemModel يحمل بس لقطة مختصرة (اسم/كمية/سعر
  // وقت الطلب) بدون تفاصيل الحجم/الإضافات الأصلية، أفضل جهد ممكن هو نجيب
  // منتجات المتجر الحالية ونضيف كل منتج لسا موجود ومتوفر للسلة بنفس الكمية.
  // أي منتج اتحذف أو صار غير متوفر منتخطاه ومنبلّغ المستخدم بالعدد بدل كراش.
  Future<void> _reorderOrder(OrderModel order) async {
    final storeId = order.storeId;
    if (storeId == null || storeId.isEmpty || order.items.isEmpty) {
      _showSnack(AppLocalizations.t(Localizations.localeOf(context), 'orders_reorder_failed'));
      return;
    }
    if (_reorderingOrderIds.contains(order.id)) return;

    setState(() => _reorderingOrderIds.add(order.id));
    final result = await _storeService.getStoreDetail(storeId);
    if (!mounted) return;
    setState(() => _reorderingOrderIds.remove(order.id));

    if (!result.success || result.store == null) {
      _showSnack(AppLocalizations.t(Localizations.localeOf(context), 'orders_reorder_store_unavailable'));
      return;
    }

    final store = result.store!;
    var addedCount = 0;
    var skippedCount = 0;
    for (final item in order.items) {
      final product = _findProductById(result.products, item.productId);
      if (product == null || !product.inStock || !product.isActive) {
        skippedCount++;
        continue;
      }
      ref.read(cartProvider.notifier).addProduct(product, store.name, quantity: item.quantity);
      addedCount++;
    }

    if (!mounted) return;

    final locale = Localizations.localeOf(context);
    if (addedCount == 0) {
      _showSnack(AppLocalizations.t(locale, 'orders_reorder_items_unavailable'));
      return;
    }

    final message = skippedCount > 0
        ? AppLocalizations.t(locale, 'orders_reorder_added_message')
            .replaceFirst('{count}', '$addedCount')
            .replaceFirst('{skipped}', '$skippedCount')
        : AppLocalizations.t(locale, 'orders_reorder_added_all');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: AppLocalizations.t(locale, 'orders_view_cart'),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
          },
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return AppColors.warning;
      case 'Confirmed':
      case 'Preparing':
        return AppColors.secondaryBrand;
      case 'Ready':
      case 'PickedUp':
        return AppColors.accent;
      case 'Delivered':
        return brandColor;
      case 'Cancelled':
      case 'Refunded':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      builder: (context, isWeb, padding, width) {
        return RefreshIndicator(
          onRefresh: _loadOrders,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: padding,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.t(
                      Localizations.localeOf(context),
                      'orders_title',
                    ),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_errorMessage != null)
                    _buildErrorState(context)
                  else if (_orders.isEmpty)
                    _buildEmptyState(context)
                  else
                    ..._orders.map(_buildOrderCard),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Text(_errorMessage!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadOrders,
              child: Text(
                AppLocalizations.t(
                  Localizations.localeOf(context),
                  'orders_retry',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 72,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.t(
                Localizations.localeOf(context),
                'orders_empty_title',
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.t(
                Localizations.localeOf(context),
                'orders_empty_subtitle',
              ),
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreAvatar(String? storeImage, {bool loading = false}) {
    if (loading) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Padding(
          padding: EdgeInsets.all(7),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final url = ApiConstants.resolveImageUrl(storeImage);
    return ClipOval(
      child: Container(
        width: 32,
        height: 32,
        color: Theme.of(context).dividerColor,
        child: url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.storefront_outlined, size: 18, color: Colors.grey),
              )
            : const Icon(Icons.storefront_outlined, size: 18, color: Colors.grey),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final color = _statusColor(order.status);
    final visibleItems = order.items.take(2).toList();
    final extraItemsCount = order.items.length - visibleItems.length;

    final locale = Localizations.localeOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: InkWell(
                  onTap: order.storeId != null ? () => _openStoreDetail(order) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      if (order.storeName != null) ...[
                        _buildStoreAvatar(
                          order.storeImage,
                          loading: _navigatingStoreIds.contains(order.id),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (order.storeName != null)
                              Text(
                                order.storeName!,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            if ((order.storeCity ?? order.storeAddress) != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 12, color: Colors.grey[500]),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        order.storeCity ?? order.storeAddress!,
                                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              order.orderNumber,
                              style: TextStyle(color: Colors.grey[600], fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                  order.status,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (order.orderTime != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('d MMM y, h:mm a', 'en_US').format(order.orderTime!.toLocal()),
                  style: TextStyle(color: Colors.grey[600], fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          ...visibleItems.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${item.quantity}x ${item.name}',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ),
          if (extraItemsCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                AppLocalizations.t(locale, 'orders_extra_items_more')
                    .replaceFirst('{count}', '$extraItemsCount'),
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.paymentMethod,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              Text(
                '₪${order.finalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => OrderDetailsDialog(order: order),
              ),
              icon: const Icon(Icons.visibility_outlined, size: 17),
              label: Text(AppLocalizations.t(locale, 'orders_view_details')),
            ),
          ),
          if (_trackableStatuses.contains(order.status)) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: brandColor,
                  side: const BorderSide(color: brandColor),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderTrackingScreen(orderId: order.id),
                    ),
                  );
                },
                icon: const Icon(Icons.map_outlined, size: 18),
                label: Text(AppLocalizations.t(locale, 'orders_track_order')),
              ),
            ),
          ],
          if (order.status == 'Delivered') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: brandColor,
                  side: const BorderSide(color: brandColor),
                ),
                onPressed: _reorderingOrderIds.contains(order.id) ? null : () => _reorderOrder(order),
                icon: _reorderingOrderIds.contains(order.id)
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: brandColor),
                      )
                    : const Icon(Icons.replay, size: 18),
                label: Text(AppLocalizations.t(locale, 'orders_reorder')),
              ),
            ),
          ],
          if (order.storeId != null ||
              (order.status == 'Delivered' && _reviewsByOrderId.containsKey(order.id))) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (order.storeId != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[800],
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      onPressed: _navigatingStoreIds.contains(order.id) ? null : () => _openStoreDetail(order),
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: Text(AppLocalizations.t(locale, 'orders_view_store')),
                    ),
                  ),
                if (order.storeId != null &&
                    order.status == 'Delivered' &&
                    _reviewsByOrderId.containsKey(order.id))
                  const SizedBox(width: 10),
                if (order.status == 'Delivered' && _reviewsByOrderId.containsKey(order.id))
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber[800],
                        side: BorderSide(color: Colors.amber.shade200),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      ),
                      onPressed: () => _openReviewDialog(order),
                      child: _reviewsByOrderId[order.id] != null
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...List.generate(
                                  5,
                                  (i) => Icon(
                                    i < _reviewsByOrderId[order.id]!.rating
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 14,
                                    color: Colors.amber[800],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    AppLocalizations.t(locale, 'orders_edit_review'),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_border, size: 18),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    AppLocalizations.t(locale, 'orders_rate_order'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
              ],
            ),
          ],
        ],
        ),
      ),
    );
  }
}
