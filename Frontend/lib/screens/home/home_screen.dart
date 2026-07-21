import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/category_model.dart';
import '../../data/models/store_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/order_model.dart';
import '../../data/models/recommendation_model.dart';
import '../../core/theme/app_themes.dart';
import '../../providers/cart_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/store_provider.dart';
import '../../services/store_service.dart';
import '../../services/order_service.dart';
import '../../services/recommendation_service.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/store_card.dart';
import '../../widgets/product_card.dart';
import '../../widgets/store_promo_card.dart';
import '../../widgets/promo_banner_carousel.dart';
import '../../widgets/home_shortcut_cards.dart';
import '../../widgets/active_order_banner.dart';
import '../../widgets/home_skeleton.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/hover_lift.dart';
import '../stores/stores_screen.dart';
import '../stores/store_detail_screen.dart';
import '../stores/product_detail_screen.dart';
import '../../core/i18n/app_localizations.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;
  List<CategoryModel> _categories = [];
  List<StoreModel> _stores = [];
  List<StoreModel> _featuredStores = [];
  List<ProductModel> _products = [];
  List<OrderModel> _orders = [];
  List<RecommendedStore> _recommendedStores = [];
  List<RecommendedProduct> _recommendedProducts = [];
  List<StoreModel> _mostOrderedStores = [];
  List<ProductModel> _latestProducts = [];

  // نفس فكرة catMap بكود الـ React: نجيب اسم الفئة من الـ ID وقت العرض
  Map<String, String> _catMap = {};

  double? _lat;
  double? _lng;

  final Color brandColor = AppColors.brand;

  @override
  void initState() {
    super.initState();
    ref.read(favoritesProvider.notifier).loadInitial();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    final storeService = ref.read(storeServiceProvider);
    // ✅ userLocationProvider موحّد لكل الشاشات (Home/Stores/StoreDetail) -
    // نفس فلسفة "نسأل مرة وحدة، فالباك بدون موقع لو رفض/فشل" السابقة، بس
    // هلق مصدرها مشترك بدل ما تتكرر بكل شاشة.
    final position = await ref.read(userLocationProvider.future);
    _lat = position?.latitude;
    _lng = position?.longitude;

    final results = await Future.wait([
      storeService.getCategories(),
      storeService.listStoresPaged(
        sortBy: _lat != null ? 'distance' : 'popularity',
        lat: _lat,
        lng: _lng,
        limit: 8,
      ),
      storeService.listStoresPaged(
        featuredOnly: true,
        lat: _lat,
        lng: _lng,
        limit: 8,
      ),
      storeService.getPopularProducts(limit: 8),
      OrderService().getMyOrders(),
      RecommendationService().getRecommendedStores(
        lat: _lat,
        lng: _lng,
        limit: 6,
      ),
      RecommendationService().getRecommendedProducts(limit: 6),
      storeService.listStoresPaged(sortBy: 'most_ordered', limit: 8),
      storeService.getNewArrivals(limit: 8),
    ]);

    _categories = results[0] as List<CategoryModel>;
    _stores = (results[1] as StoresPageResult).stores;
    _featuredStores = (results[2] as StoresPageResult).stores;
    _products = results[3] as List<ProductModel>;
    _orders = (results[4] as OrdersListResult).orders;
    _recommendedStores = results[5] as List<RecommendedStore>;
    _recommendedProducts = results[6] as List<RecommendedProduct>;
    _mostOrderedStores = (results[7] as StoresPageResult).stores;
    _latestProducts = results[8] as List<ProductModel>;
    _catMap = {for (final c in _categories) c.id: c.name};

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ✅ كل قسم رئيسي ببني بتأخير متدرّج بسيط (staggered) عبر FadeSlideIn -
  // عشان المحتوى يحس أنه "يظهر" تدريجيًا أول ما يجهز بدل ما يطلع كله دفعة
  // وحدة، بدون أي تأخير فعلي بجلب البيانات (كلها محمّلة أصلًا وقت هاد الاستدعاء).
  Widget _staggered(int index, Widget child) {
    return FadeSlideIn(
      delay: Duration(milliseconds: 60 * index),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MainLayout(
        activeNavId: 'home',
        builder: (context, isWeb, padding, width) => HomeSkeleton(
          padding: padding,
          crossAxisCount: StoreCard.gridColumnsForWidth(width),
        ),
      );
    }

    return MainLayout(
      activeNavId: 'home',
      builder: (context, isWeb, paddingPercent, width) {
        int i = 0;
        return Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // 1) العروض السريعة
                  _staggered(i++, HomeShortcutCards(padding: paddingPercent)),
                  const SizedBox(height: 8),
                  // 2) Hero Banner
                  _staggered(i++, _buildHeroSection(isWeb, paddingPercent)),
                  _staggered(i++, _buildFeaturesStrip(isWeb, paddingPercent)),
                  // 3) أقرب المتاجر
                  _staggered(
                    i++,
                    _buildPopularStoresSection(paddingPercent, width),
                  ),
                  // 4) التصنيفات
                  _staggered(
                    i++,
                    _buildCategoriesSection(paddingPercent, width),
                  ),
                  const SizedBox(height: 8),
                  // 5) الأكثر طلباً
                  if (_mostOrderedStores.isNotEmpty)
                    _staggered(
                      i++,
                      _buildMostOrderedSection(paddingPercent, width),
                    ),
                  // 6) العروض
                  if (_featuredStores.isNotEmpty)
                    _staggered(
                      i++,
                      PromoBannerCarousel(stores: _featuredStores),
                    ),
                  const SizedBox(height: 8),
                  // 7) المتاجر المميزة
                  if (_featuredStores.isNotEmpty)
                    _staggered(
                      i++,
                      _buildFeaturedStoresSection(paddingPercent, width),
                    ),
                  // 8) آخر المنتجات
                  if (_latestProducts.isNotEmpty)
                    _staggered(
                      i++,
                      _buildLatestProductsSection(paddingPercent, width),
                    ),
                  if (_recommendedStores.isNotEmpty)
                    _staggered(
                      i++,
                      _buildRecommendedStoresSection(paddingPercent, width),
                    ),
                  _staggered(
                    i++,
                    _buildTrendingProductsSection(paddingPercent, width),
                  ),
                  if (_recommendedProducts.isNotEmpty)
                    _staggered(
                      i++,
                      _buildRecommendedProductsSection(paddingPercent, width),
                    ),
                  _buildFooterSection(paddingPercent, isWeb),
                ],
              ),
            ),
            PositionedDirectional(
              bottom: 16,
              start: 16,
              child: ActiveOrderBanner(orders: _orders),
            ),
          ],
        );
      },
    );
  }

  // ✅ خلفية الـ Hero من صورة أول متجر مميّز (بيانات حقيقية من الباك إند) -
  // بدل صورة stock عشوائية، وبفولباك متدرّج لوني لو ما في متاجر مميّزة بعد.
  Widget _buildHeroSection(bool isWeb, double padding) {
    final locale = Localizations.localeOf(context);
    final heroImageUrl = _featuredStores.isNotEmpty
        ? _featuredStores.first.imageUrl
        : null;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: isWeb ? 24 : 12,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: SizedBox(
          height: isWeb ? 400 : 300,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (heroImageUrl != null && heroImageUrl.isNotEmpty)
                Image.network(
                  heroImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildHeroFallback(),
                )
              else
                _buildHeroFallback(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.05),
                    ],
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWeb ? 48 : 20,
                  vertical: 24,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWeb ? 560 : double.infinity,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer.withValues(
                              alpha: 0.85,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.bolt,
                                size: 16,
                                color: AppColors.onSecondaryContainer,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppLocalizations.t(
                                  locale,
                                  'home_fast_delivery_badge',
                                ),
                                style: const TextStyle(
                                  color: AppColors.onSecondaryContainer,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          AppLocalizations.t(locale, 'home_hero_title_line1') +
                              AppLocalizations.t(
                                locale,
                                'home_hero_title_line2',
                              ),
                          style: TextStyle(
                            fontSize: isWeb ? 44 : 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          AppLocalizations.t(locale, 'home_hero_subtitle'),
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: brandColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const StoresScreen(),
                                ),
                              ),
                              icon: Text(
                                AppLocalizations.t(
                                  locale,
                                  'home_browse_stores',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              label: const Icon(Icons.arrow_forward, size: 16),
                            ),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.14,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 14,
                                ),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const StoresScreen(),
                                ),
                              ),
                              child: Text(
                                AppLocalizations.t(
                                  locale,
                                  'home_view_categories',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ فولباك الـ Hero لما ما يكون في صورة متجر مميّز حقيقية (أو فشل تحميلها) -
  // تدرّج لوني + مجموعة أيقونات كبيرة شبه شفافة (سلة/خضار/بقالة/مشروبات) بدل
  // كتلة لون مسطّحة، عشان يضل يحس بصري حتى بدون بيانات حقيقية.
  Widget _buildHeroFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [brandColor, AppColors.brandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -30,
            top: -20,
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 180,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          PositionedDirectional(
            end: 60,
            bottom: -30,
            child: Icon(
              Icons.eco_outlined,
              size: 140,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          PositionedDirectional(
            end: 190,
            top: 40,
            child: Icon(
              Icons.local_grocery_store_outlined,
              size: 90,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          PositionedDirectional(
            end: 200,
            bottom: 30,
            child: Icon(
              Icons.local_drink_outlined,
              size: 70,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesStrip(bool isWeb, double padding) {
    final locale = Localizations.localeOf(context);
    var features = [
      {
        'icon': Icons.local_shipping_outlined,
        'title': AppLocalizations.t(locale, 'home_feature_delivery_title'),
        'desc': AppLocalizations.t(locale, 'home_feature_delivery_desc'),
      },
      {
        'icon': Icons.access_time,
        'title': AppLocalizations.t(locale, 'home_feature_pickup_title'),
        'desc': AppLocalizations.t(locale, 'home_feature_pickup_desc'),
      },
      {
        'icon': Icons.shield_outlined,
        'title': AppLocalizations.t(locale, 'home_feature_secure_title'),
        'desc': AppLocalizations.t(locale, 'home_feature_secure_desc'),
      },
    ];

    List<Widget> featureWidgets = features
        .map(
          (f) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: brandColor.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundColor: brandColor.withValues(alpha: 0.1),
                  child: Icon(
                    f['icon'] as IconData,
                    color: brandColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f['title'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    Text(
                      f['desc'] as String,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
      child: isWeb
          ? Row(
              children: featureWidgets
                  .map(
                    (w) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: w,
                      ),
                    ),
                  )
                  .toList(),
            )
          : Column(
              children: featureWidgets
                  .map(
                    (w) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: w,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildCategoriesSection(double padding, double width) {
    int crossAxisCount = width > 1100 ? 7 : (width > 700 ? 4 : 3);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.t(
                      Localizations.localeOf(context),
                      'home_categories_title',
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    AppLocalizations.t(
                      Localizations.localeOf(context),
                      'home_categories_subtitle',
                    ),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StoresScreen(),
                    ),
                  );
                },
                label: const Icon(Icons.chevron_right, size: 14),
                icon: Text(
                  AppLocalizations.t(
                    Localizations.localeOf(context),
                    'home_view_all',
                  ),
                  style: TextStyle(
                    color: brandColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.82,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              var cat = _categories[index];
              final theme = Theme.of(context);
              final isDark = theme.brightness == Brightness.dark;
              final catColor = cat.color;
              final tint = catColor.withValues(alpha: isDark ? 0.18 : 0.12);
              return HoverLift(
                liftPx: 3,
                scale: 1.03,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          StoresScreen(initialCategoryId: cat.id),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: catColor,
                        child: Icon(
                          cat.iconData,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        cat.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${cat.productCount} ${AppLocalizations.t(Localizations.localeOf(context), 'categories_products_suffix')}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPopularStoresSection(double padding, double width) {
    int crossAxisCount = StoreCard.gridColumnsForWidth(width);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.t(
                      Localizations.localeOf(context),
                      _lat != null
                          ? 'home_nearest_stores_title'
                          : 'home_popular_stores_title',
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    AppLocalizations.t(
                      Localizations.localeOf(context),
                      _lat != null
                          ? 'home_nearest_stores_subtitle'
                          : 'home_popular_stores_subtitle',
                    ),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StoresScreen(),
                    ),
                  );
                },
                label: const Icon(Icons.chevron_right, size: 14),
                icon: Text(
                  AppLocalizations.t(
                    Localizations.localeOf(context),
                    'home_see_all',
                  ),
                  style: TextStyle(
                    color: brandColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: StoreCard.gridItemHeight,
            ),
            itemCount: _stores.length,
            itemBuilder: (context, index) {
              final store = _stores[index];
              return StoreCard(
                store: store,
                categoryName: _catMap[store.categoryId] ?? '',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          StoreDetailScreen(store: store, isGuest: false),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ✅ "الأكثر طلباً" - عدد طلبات Delivered فعلي لكل متجر (sort=most_ordered
  // بالباك إند)، مختلف عن "مقترح لك" تحت (توصية شخصية) وعن Popular (تقييمات).
  Widget _buildMostOrderedSection(double padding, double width) {
    int crossAxisCount = StoreCard.gridColumnsForWidth(width);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.t(
              Localizations.localeOf(context),
              'home_most_ordered_title',
            ),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            AppLocalizations.t(
              Localizations.localeOf(context),
              'home_most_ordered_subtitle',
            ),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: StoreCard.gridItemHeight,
            ),
            itemCount: _mostOrderedStores.length,
            itemBuilder: (context, index) {
              final store = _mostOrderedStores[index];
              return StoreCard(
                store: store,
                categoryName: _catMap[store.categoryId] ?? '',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          StoreDetailScreen(store: store, isGuest: false),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ✅ "المتاجر المميزة" - شبكة مخصصة لنفس _featuredStores (featured_only=true)
  // اللي كانت تُستخدم بس لخلفية الـ Hero وPromoBannerCarousel، بدون عرض مستقل.
  Widget _buildFeaturedStoresSection(double padding, double width) {
    int crossAxisCount = StoreCard.gridColumnsForWidth(width);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.t(
              Localizations.localeOf(context),
              'home_featured_title',
            ),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            AppLocalizations.t(
              Localizations.localeOf(context),
              'home_featured_subtitle',
            ),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: StoreCard.gridItemHeight,
            ),
            itemCount: _featuredStores.length,
            itemBuilder: (context, index) {
              final store = _featuredStores[index];
              return StoreCard(
                store: store,
                categoryName: _catMap[store.categoryId] ?? '',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          StoreDetailScreen(store: store, isGuest: false),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ✅ "آخر المنتجات" - getNewArrivals() كانت موجودة أصلًا بالسيرفس (تُستخدم
  // بشاشة NewArrivalsScreen المنفصلة) بس ما كان لها قسم بالصفحة الرئيسية.
  Widget _buildLatestProductsSection(double padding, double width) {
    int crossAxisCount = width > 950 ? 4 : (width > 650 ? 3 : 2);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.t(
              Localizations.localeOf(context),
              'home_latest_products_title',
            ),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            AppLocalizations.t(
              Localizations.localeOf(context),
              'home_latest_products_subtitle',
            ),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemCount: _latestProducts.length,
            itemBuilder: (context, index) {
              final product = _latestProducts[index];
              final storeName = product.storeName;
              return ProductCard(
                product: product,
                storeName: storeName,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailScreen(
                        product: product,
                        storeName: storeName,
                        isGuest: false,
                      ),
                    ),
                  );
                },
                onAddToCart: () {
                  ref
                      .read(cartProvider.notifier)
                      .addProduct(product, storeName);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.t(
                          Localizations.localeOf(context),
                          'home_added_to_cart',
                        ).replaceFirst('{item}', product.name),
                      ),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ✅ Recommendation Engine (قائم على قواعد/إحصاء - الطلبات السابقة/الفئات
  // المفضّلة/القرب - راجع recommendationService بالباك إند): متاجر مقترحة
  // خصيصًا لهذا المستخدم. الشارة على كل بطاقة هي سبب التوصية الحقيقي الراجع
  // من الباك إند (rec.reason) - مو نص تسويقي ثابت زي "الأكثر طلبًا" لأنه ما
  // عنا بيانات فعلية تثبت هيك ادّعاء لكل متجر.
  Widget _buildRecommendedStoresSection(double padding, double width) {
    int crossAxisCount = width > 900 ? 2 : 1;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: brandColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'مقترح لك',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Text(
            'متاجر اخترناها بناءً على طلباتك وتفضيلاتك',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: crossAxisCount > 1 ? 2.6 : 2.0,
            ),
            itemCount: _recommendedStores.length,
            itemBuilder: (context, index) {
              final rec = _recommendedStores[index];
              return StorePromoCard(
                store: rec.store,
                badge: rec.reason,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          StoreDetailScreen(store: rec.store, isGuest: false),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedProductsSection(double padding, double width) {
    int crossAxisCount = width > 950 ? 4 : (width > 650 ? 3 : 2);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: brandColor, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.t(
                  Localizations.localeOf(context),
                  'home_recommended_products_title',
                ),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemCount: _recommendedProducts.length,
            itemBuilder: (context, index) {
              final rec = _recommendedProducts[index];
              final product = rec.product;
              return ProductCard(
                product: product,
                storeName: product.storeName,
                reasonBadge: rec.reason,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailScreen(
                        product: product,
                        storeName: product.storeName,
                        isGuest: false,
                      ),
                    ),
                  );
                },
                onAddToCart: () {
                  ref
                      .read(cartProvider.notifier)
                      .addProduct(product, product.storeName);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.t(
                          Localizations.localeOf(context),
                          'home_added_to_cart',
                        ).replaceFirst('{item}', product.name),
                      ),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingProductsSection(double padding, double width) {
    int crossAxisCount = width > 950 ? 4 : (width > 650 ? 3 : 2);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.t(
              Localizations.localeOf(context),
              'home_trending_title',
            ),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            AppLocalizations.t(
              Localizations.localeOf(context),
              'home_trending_subtitle',
            ),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.76,
            ),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              var product = _products[index];
              final storeName = product.storeName;
              return ProductCard(
                product: product,
                storeName: storeName,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailScreen(
                        product: product,
                        storeName: storeName,
                        isGuest: false,
                      ),
                    ),
                  );
                },
                onAddToCart: () {
                  ref
                      .read(cartProvider.notifier)
                      .addProduct(product, storeName);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.t(
                          Localizations.localeOf(context),
                          'home_added_to_cart',
                        ).replaceFirst('{item}', product.name),
                      ),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSection(double padding, bool isWeb) {
    return Container(
      color: Theme.of(context).cardColor,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 40),
      child: isWeb
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _getFooterColumns(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _getFooterColumns()
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: c,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  List<Widget> _getFooterColumns() {
    return [
      Theme(
        data: Theme.of(context),
        child: SizedBox(
          width: 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.t(
                  Localizations.localeOf(context),
                  'home_brand_name',
                ),
                style: TextStyle(
                  color: brandColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.t(
                  Localizations.localeOf(context),
                  'home_footer_tagline',
                ),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      _buildFooterLinkColumn(
        AppLocalizations.t(
          Localizations.localeOf(context),
          'home_footer_shop_title',
        ),
        [
          AppLocalizations.t(
            Localizations.localeOf(context),
            'home_footer_link_categories',
          ),
          AppLocalizations.t(
            Localizations.localeOf(context),
            'home_footer_link_all_stores',
          ),
        ],
      ),
      _buildFooterLinkColumn(
        AppLocalizations.t(
          Localizations.localeOf(context),
          'home_footer_account_title',
        ),
        [
          AppLocalizations.t(
            Localizations.localeOf(context),
            'home_footer_link_my_orders',
          ),
          AppLocalizations.t(
            Localizations.localeOf(context),
            'home_footer_link_cart',
          ),
        ],
      ),
      _buildFooterLinkColumn(
        AppLocalizations.t(
          Localizations.localeOf(context),
          'home_footer_business_title',
        ),
        [
          AppLocalizations.t(
            Localizations.localeOf(context),
            'home_footer_link_store_dashboard',
          ),
        ],
      ),
      _buildFooterLinkColumn(
        AppLocalizations.t(
          Localizations.localeOf(context),
          'home_footer_legal_title',
        ),
        [
          AppLocalizations.t(
            Localizations.localeOf(context),
            'home_footer_link_about',
          ),
          AppLocalizations.t(
            Localizations.localeOf(context),
            'home_footer_link_help',
          ),
          AppLocalizations.t(
            Localizations.localeOf(context),
            'home_footer_link_contact',
          ),
          AppLocalizations.t(
            Localizations.localeOf(context),
            'home_footer_link_terms',
          ),
          AppLocalizations.t(
            Localizations.localeOf(context),
            'home_footer_link_privacy',
          ),
        ],
      ),
    ];
  }

  Widget _buildFooterLinkColumn(String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        ...links.map(
          (link) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              link,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
