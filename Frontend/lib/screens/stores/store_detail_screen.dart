// lib/screens/stores/store_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/store_model.dart';
import '../../data/models/product_model.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/review_service.dart';
import '../../widgets/login_required_dialog.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/product_card.dart';
import '../../core/i18n/app_localizations.dart';
import 'product_detail_screen.dart';

class StoreDetailScreen extends ConsumerWidget {
  final StoreModel store;
  final bool isGuest; // ضيف (مش مسجل دخول) ولا مستخدم مسجل

  const StoreDetailScreen({
    super.key,
    required this.store,
    this.isGuest = false,
  });

  static const Color brandColor = AppColors.brand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ نجيب موقع الزبون الحالي (نفس المصدر الموحّد لكل الشاشات) عشان
    // distance_km يرجع صحيح بغض النظر من وين المستخدم دخل الشاشة - حتى لو
    // الـ store الممرر بالكونستركتور ما كان عنده موقع أصلًا (مثلًا جاي من
    // قائمة بدون فلتر موقع).
    final userPos = ref.watch(userLocationProvider).valueOrNull;
    final detailAsync = ref.watch(
      storeDetailProvider(
        StoreDetailParams(
          store.id,
          lat: userPos?.latitude,
          lng: userPos?.longitude,
        ),
      ),
    );
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final categoryName =
        ({for (final c in categories) c.id: c.name})[store.categoryId] ?? '';
    final products = detailAsync.valueOrNull?.products ?? [];

    if (!isGuest) {
      ref.read(favoritesProvider.notifier).loadInitial();
    }

    return MainLayout(
      isGuest: isGuest,
      builder: (context, isWeb, padding, width) {
        int crossAxisCount = width > 950 ? 4 : (width > 650 ? 3 : 2);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStoreHeader(
                context,
                ref,
                categoryName,
                padding,
              ),
              Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: padding,
                                vertical: 24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.t(
                                      Localizations.localeOf(context),
                                      'storedetail_menu_title',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  detailAsync.isLoading
                                      ? const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 40,
                                          ),
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        )
                                      : products.isEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 40,
                                          ),
                                          child: Center(
                                            child: Text(
                                              AppLocalizations.t(
                                                Localizations.localeOf(context),
                                                'storedetail_no_products',
                                              ),
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ),
                                        )
                                      : GridView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: crossAxisCount,
                                                crossAxisSpacing: 16,
                                                mainAxisSpacing: 16,
                                                childAspectRatio: 0.76,
                                              ),
                                          itemCount: products.length,
                                          itemBuilder: (context, index) {
                                            final product = products[index];
                                            return ProductCard(
                                              product: product,
                                              isGuest: isGuest,
                                              onTap: () => _openProductDetail(
                                                context,
                                                product,
                                              ),
                                              onAddToCart: () {
                                                if (isGuest) {
                                                  showLoginRequiredDialog(
                                                    context,
                                                  );
                                                  return;
                                                }
                                                if (product
                                                    .variants
                                                    .isNotEmpty) {
                                                  _openProductDetail(
                                                    context,
                                                    product,
                                                  );
                                                  return;
                                                }
                                                ref
                                                    .read(
                                                      cartProvider.notifier,
                                                    )
                                                    .addProduct(
                                                      product,
                                                      store.name,
                                                    );
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      AppLocalizations.t(
                                                        Localizations.localeOf(
                                                          context,
                                                        ),
                                                        'storedetail_added_to_cart',
                                                      ).replaceFirst(
                                                        '{item}',
                                                        product.name,
                                                      ),
                                                    ),
                                                    duration: const Duration(
                                                      seconds: 1,
                                                    ),
                                                    behavior:
                                                        SnackBarBehavior.floating,
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                ],
                              ),
                            ),
                            _buildAboutSection(
                              context,
                              padding,
                              detailAsync.valueOrNull?.store ?? store,
                            ),
                            _buildLocationSection(
                              context,
                              padding,
                              detailAsync.valueOrNull?.store,
                            ),
              _buildReviewsSection(context, padding),
            ],
          ),
        );
      },
    );
  }

  void _openProductDetail(BuildContext context, ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          product: product,
          storeName: store.name,
          isGuest: isGuest,
        ),
      ),
    );
  }

  Widget _buildAboutSection(
    BuildContext context,
    double padding,
    StoreModel s,
  ) {
    final locale = Localizations.localeOf(context);
    final hasHours =
        s.openingTime != null &&
        s.openingTime!.isNotEmpty &&
        s.closingTime != null &&
        s.closingTime!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.description.isNotEmpty) ...[
              Text(
                s.description,
                style: const TextStyle(fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 12),
            ],
            _infoRow(
              Icons.location_on_outlined,
              [
                s.address,
                if (s.city.isNotEmpty) s.city,
              ].where((v) => v.isNotEmpty).join(' - '),
            ),
            if (s.phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.phone_outlined, s.phone),
            ],
            if (hasHours) ...[
              const SizedBox(height: 8),
              _infoRow(
                Icons.access_time,
                '${s.openingTime} - ${s.closingTime}',
              ),
            ],
            if (s.minimumOrder > 0) ...[
              const SizedBox(height: 8),
              _infoRow(
                Icons.shopping_bag_outlined,
                '${AppLocalizations.t(locale, 'storesetup_field_min_order')}: ₪${s.minimumOrder.toStringAsFixed(0)}',
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (s.supportsDelivery)
                  _capabilityChip(
                    context,
                    Icons.delivery_dining_outlined,
                    'توصيل متاح',
                  ),
                if (s.supportsPickup)
                  _capabilityChip(
                    context,
                    Icons.storefront_outlined,
                    'استلام من المتجر',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _capabilityChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: brandColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: brandColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: brandColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(
    BuildContext context,
    double padding,
    StoreModel? freshStore,
  ) {
    final locale = Localizations.localeOf(context);
    if (store.latitude == null || store.longitude == null) {
      return const SizedBox.shrink();
    }
    final point = LatLng(store.latitude!, store.longitude!);
    // ✅ freshStore جاي من storeDetailProvider (بموقع الزبون الحالي الفعلي)
    // فمسافته أدق من store.distanceKm يلي ممكن يكون null أو قديم لو الشاشة
    // انفتحت من سياق ما كان فيه موقع وقتها.
    final distanceKm = freshStore?.distanceKm ?? store.distanceKm;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.t(locale, 'storedetail_location_title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (distanceKm != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.social_distance_outlined,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.t(
                    locale,
                    'storedetail_distance_label',
                  ).replaceFirst('{km}', distanceKm.toStringAsFixed(1)),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 10),
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  store.deliveryTime,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 180,
              child: IgnorePointer(
                child: FlutterMap(
                  options: MapOptions(initialCenter: point, initialZoom: 14),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.pickngo.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.redAccent,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      _StoreFullMapScreen(storeName: store.name, point: point),
                ),
              );
            },
            icon: const Icon(Icons.map_outlined, size: 18),
            label: Text(
              AppLocalizations.t(locale, 'storedetail_view_full_map'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(BuildContext context, double padding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'التقييمات',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          FutureBuilder<ReviewListResult>(
            future: ReviewService().getStoreReviews(store.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final reviews = snapshot.data?.reviews ?? [];
              if (reviews.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'لا توجد تقييمات بعد',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                );
              }
              return Column(
                children: reviews.map((review) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              review.customerName ?? 'مستخدم',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < review.rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (review.comment != null &&
                            review.comment!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            review.comment!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStoreHeader(
    BuildContext context,
    WidgetRef ref,
    String categoryName,
    double padding,
  ) {
    final isFavorited =
        !isGuest && ref.watch(favoritesProvider).contains(store.id);

    return Stack(
      children: [
        Image.network(
          store.imageUrl,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          // ✅ خلفية بديلة غامقة (بدل رمادي فاتح) - لو الصورة فشلت تحمّل، النص
          // والأيقونات البيضاء فوقها (اسم المتجر، التقييم...) لازم تضل مقروءة.
          errorBuilder: (context, error, stackTrace) => Container(
            height: 220,
            width: double.infinity,
            color: Colors.grey[700],
            child: Icon(
              Icons.storefront_outlined,
              color: Colors.grey[400],
              size: 48,
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: padding,
          child: SafeArea(
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: padding,
          child: SafeArea(
            child: InkWell(
              onTap: () {
                if (isGuest) {
                  showLoginRequiredDialog(context);
                  return;
                }
                ref.read(favoritesProvider.notifier).toggle(store.id);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: isFavorited ? Colors.redAccent : Colors.black87,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
            decoration: BoxDecoration(
              // ✅ الظل بيبلّش أغمق وما بيوصل شفاف كامل بالأعلى - عشان النص
              // الأبيض يضل مقروء فوق أي صورة (فاتحة أو غامقة) مش بس صور غامقة.
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.75),
                  Colors.black.withValues(alpha: 0.15),
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    categoryName,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  store.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 2),
                    Text(
                      '${store.averageRating}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      ' (${store.totalReviews})',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.access_time,
                      color: Colors.white.withValues(alpha: 0.88),
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      store.deliveryTime,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.delivery_dining_outlined,
                      color: Colors.white.withValues(alpha: 0.88),
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      store.deliveryFee,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// شاشة خارطة كاملة لموقع متجر واحد (تُفتح من زر "عرض على الخريطة بالكامل")
class _StoreFullMapScreen extends StatelessWidget {
  final String storeName;
  final LatLng point;

  const _StoreFullMapScreen({required this.storeName, required this.point});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(storeName),
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        elevation: 0,
      ),
      body: FlutterMap(
        options: MapOptions(initialCenter: point, initialZoom: 15),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.pickngo.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: point,
                width: 44,
                height: 44,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.redAccent,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
