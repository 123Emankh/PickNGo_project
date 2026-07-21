// lib/screens/landing/landing_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_notifier.dart';
import '../../core/theme/app_themes.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_notifier.dart';
import '../../data/models/category_model.dart';
import '../../data/models/store_model.dart';
import '../../data/models/product_model.dart';
import '../../providers/store_provider.dart';
import '../../services/store_service.dart';
import '../auth/register_screen.dart';
import '../stores/stores_screen.dart';
import '../stores/store_detail_screen.dart';
import '../../widgets/login_required_dialog.dart';
import '../../widgets/store_card.dart';
import '../../widgets/store_promo_card.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/hover_lift.dart';
import 'widgets/app_showcase_phone_widget.dart';

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  bool _isLoading = true;
  List<CategoryModel> _categories = [];
  List<StoreModel> _stores = [];
  List<ProductModel> _products = [];
  List<ProductModel> _showcaseProducts = [];
  Map<String, String> _catMap = {};
  Map<String, String> _storeMap = {};

  // ✅ إحصائيات حقيقية من نفس البيانات المحمّلة أصلًا (بدون أي endpoint
  // جديد) - listStoresPaged بيرجّع "total" الحقيقي من الباك إند (كان
  // listStores العادي يتجاهله). عدد السائقين/الطلبات مش متاحين لضيف غير
  // مسجّل دخول بأي endpoint حالي، فما ضفناهم كأرقام وهمية.
  int _totalStoresCount = 0;
  int _citiesCount = 0;
  double _avgRating = 0;
  Map<String, int> _categoryStoreCounts = {};

  final Color brandColor = AppColors.brand;

  // ---------------- Nav anchors (بتخلي كل كبسة بالـ navbar توديك عالقسم تبعها) ----------------
  final GlobalKey _howItWorksKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _forYouKey = GlobalKey();
  final GlobalKey _storesKey = GlobalKey();

  void _scrollToSection(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  // ---------------- Theme-aware colors (يخلّي زر Light/Dark فعليًا يغيّر الشكل) ----------------
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBg =>
      _isDark ? const Color(0xFF0F1722) : const Color(0xFFFAFAFA);
  Color get _surfaceBg => _isDark ? const Color(0xFF15202B) : Colors.white;
  Color get _textPrimary => _isDark ? Colors.white : Colors.black87;
  Color get _textSecondary =>
      _isDark ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _borderColor => _isDark ? Colors.white24 : Colors.grey.shade200;
  Color get _borderColorSoft => _isDark ? Colors.white12 : Colors.grey.shade100;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    final storeService = ref.read(storeServiceProvider);
    final results = await Future.wait([
      storeService.getCategories(),
      // ✅ listStoresPaged بدل listStores العادية - نفس endpoint (GET
      // /api/stores) بنفس الاستخدام الموجود أصلًا بـ home_screen.dart، بس
      // بيرجّع "total" الحقيقي لعدد كل المتاجر مش بس عدد المحمّل بالصفحة.
      storeService.listStoresPaged(limit: 100),
    ]);
    _categories = results[0] as List<CategoryModel>;
    final pagedStores = results[1] as StoresPageResult;
    _stores = pagedStores.stores;
    _catMap = {for (final c in _categories) c.id: c.name};
    _storeMap = {for (final s in _stores) s.id: s.name};

    _totalStoresCount = pagedStores.total > _stores.length
        ? pagedStores.total
        : _stores.length;
    _citiesCount = _stores
        .map((s) => s.city.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .length;
    final ratedStores = _stores.where((s) => s.totalReviews > 0).toList();
    _avgRating = ratedStores.isEmpty
        ? 0
        : ratedStores.map((s) => s.averageRating).reduce((a, b) => a + b) /
              ratedStores.length;

    // "الأكثر رواجًا": ما في endpoint عام لكل المنتجات بكل المتاجر بالباك
    // إند حاليًا (بس واحد لكل متجر) - فبنجمع أول كم منتج من أول كم متجر.
    // بناخد متجر واحد من كل فئة الأول (قبل ما نكرر فئات) عشان العرض ما
    // يطلع كله أكل لو أول 6 متاجر بالقائمة صدفة كلها مطاعم.
    final storesByCategory = <String, List<StoreModel>>{};
    for (final s in _stores) {
      storesByCategory.putIfAbsent(s.categoryId, () => []).add(s);
    }
    _categoryStoreCounts = {
      for (final entry in storesByCategory.entries) entry.key: entry.value.length,
    };
    final sampleStores = <StoreModel>[
      for (final list in storesByCategory.values) list.first,
    ];
    for (final s in _stores) {
      if (sampleStores.length >= 6) break;
      if (!sampleStores.contains(s)) sampleStores.add(s);
    }
    if (sampleStores.length > 6) {
      sampleStores.removeRange(6, sampleStores.length);
    }
    final productLists = await Future.wait(
      sampleStores.map((s) => storeService.getStoreDetail(s.id)),
    );
    _products = productLists.expand((r) => r.products.take(4)).toList();
    // موك-أب الهاتف بالـ hero بياخد منتج واحد بس من كل متجر متنوّع (مش أول
    // 6 من _products) عشان يضمن تنوع فئات حقيقي بدل ما يطلع مليان أكل لو
    // أول متجر بالقائمة عنده لحاله 4+ منتجات.
    _showcaseProducts = [
      for (final r in productLists)
        if (r.products.isNotEmpty) r.products.first,
    ];

    if (mounted) setState(() => _isLoading = false);
  }

  void _goToRegister({bool startOnLogin = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterScreen(startOnLogin: startOnLogin),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(brandColor),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _pageBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWeb = constraints.maxWidth > 1000;
          double padding = isWeb ? constraints.maxWidth * 0.08 : 16.0;

          return Column(
            children: [
              _buildNavbar(isWeb, padding),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        key: _howItWorksKey,
                        child: _buildHero(
                          isWeb,
                          padding,
                        ), // 👈 الفرق المقصود: فيها خريطة/رسمة التوصيل
                      ),
                      _buildStatsSection(isWeb, padding),
                      Container(
                        key: _featuresKey,
                        child: _buildFeaturesStrip(isWeb, padding),
                      ),
                      _buildCategoriesSection(padding, constraints.maxWidth),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: padding),
                        child: FadeSlideIn(
                          child: _buildMultiCategoryBanner(isWeb),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        key: _storesKey,
                        child: _buildPopularStoresSection(
                          padding,
                          constraints.maxWidth,
                        ),
                      ),
                      _buildRecommendedSection(padding, constraints.maxWidth),
                      Container(
                        key: _forYouKey,
                        child: FadeSlideIn(
                          child: _buildTrendingProductsSection(
                            padding,
                            constraints.maxWidth,
                          ),
                        ),
                      ),
                      _buildWhyPickNGoSection(isWeb, padding),
                      _buildHowItWorksSection(isWeb, padding),
                      FadeSlideIn(
                        child: _buildPartnerCtaSection(isWeb, padding),
                      ),
                      _buildTestimonialsSection(isWeb, padding),
                      _buildFooterSection(padding, isWeb),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------- Navbar (خاص بالضيوف) ----------------
  Widget _buildNavbar(bool isWeb, double padding) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 14),
      decoration: BoxDecoration(
        color: _surfaceBg,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brandColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.t(
                  ref.watch(localeNotifierProvider),
                  'app_name',
                ),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          if (isWeb)
            Row(
              children: [
                _navLink(
                  AppLocalizations.t(
                    ref.watch(localeNotifierProvider),
                    'features',
                  ),
                  onTap: () => _scrollToSection(_featuresKey),
                ),
                _navLink(
                  AppLocalizations.t(
                    ref.watch(localeNotifierProvider),
                    'how_it_works',
                  ),
                  onTap: () => _scrollToSection(_howItWorksKey),
                ),
                _navLink(
                  AppLocalizations.t(
                    ref.watch(localeNotifierProvider),
                    'for_you',
                  ),
                  onTap: () => _scrollToSection(_forYouKey),
                ),
                _navLink(
                  AppLocalizations.t(
                    ref.watch(localeNotifierProvider),
                    'stores',
                  ),
                  onTap: () => _scrollToSection(_storesKey),
                ),
              ],
            ),
          Row(
            children: [
              // Language selector
              PopupMenuButton<Locale>(
                tooltip: AppLocalizations.t(
                  ref.watch(localeNotifierProvider),
                  'landing2_language_tooltip',
                ),
                icon: Icon(Icons.language, color: _textPrimary),
                onSelected: (locale) =>
                    ref.read(localeNotifierProvider.notifier).setLocale(locale),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: const Locale('en'),
                    child: Text(
                      AppLocalizations.t(
                        ref.watch(localeNotifierProvider),
                        'language_en',
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: const Locale('ar'),
                    child: Text(
                      AppLocalizations.t(
                        ref.watch(localeNotifierProvider),
                        'language_ar',
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: const Locale('fr'),
                    child: Text(
                      AppLocalizations.t(
                        ref.watch(localeNotifierProvider),
                        'language_fr',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // Theme selector (System / Light / Dark)
              PopupMenuButton<ThemeMode>(
                tooltip: AppLocalizations.t(
                  ref.watch(localeNotifierProvider),
                  'landing2_theme_tooltip',
                ),
                icon: Icon(
                  ref.watch(themeNotifierProvider) == ThemeMode.dark
                      ? Icons.dark_mode
                      : ref.watch(themeNotifierProvider) == ThemeMode.light
                      ? Icons.light_mode
                      : Icons.brightness_auto,
                  color: _textPrimary,
                ),
                onSelected: (mode) =>
                    ref.read(themeNotifierProvider.notifier).setThemeMode(mode),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: ThemeMode.system,
                    child: Text(
                      AppLocalizations.t(
                        ref.watch(localeNotifierProvider),
                        'landing2_theme_system',
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: ThemeMode.light,
                    child: Text(
                      AppLocalizations.t(
                        ref.watch(localeNotifierProvider),
                        'landing2_theme_light',
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: ThemeMode.dark,
                    child: Text(
                      AppLocalizations.t(
                        ref.watch(localeNotifierProvider),
                        'landing2_theme_dark',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _goToRegister(startOnLogin: true),
                icon: Icon(Icons.person_outline, size: 16, color: _textPrimary),
                label: Text(
                  AppLocalizations.t(
                    ref.watch(localeNotifierProvider),
                    'log_in',
                  ),
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  elevation: 0,
                ),
                onPressed: () => _goToRegister(),
                label: Text(
                  AppLocalizations.t(
                    ref.watch(localeNotifierProvider),
                    'get_started',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                icon: const Icon(Icons.arrow_forward, size: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navLink(String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          text,
          style: TextStyle(
            color: _isDark ? Colors.grey.shade300 : Colors.grey[700],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ---------------- Hero (الفرق المقصود: فيها الخريطة) ----------------
  // ✅ يبني TextSpans من نص الهيدلاين الخام: \n لفصل الأسطر، و *كلمة* لتمييز
  // كلمة بلون مختلف (مستخدمة حاليًا لتلوين "Go" - راجع مفتاح 'headline' بكل اللغات)
  List<TextSpan> _headlineSpans(String raw, Color highlightColor) {
    final spans = <TextSpan>[];
    final lines = raw.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final parts = lines[i].split('*');
      for (var j = 0; j < parts.length; j++) {
        if (parts[j].isEmpty) continue;
        spans.add(TextSpan(
          text: parts[j],
          style: j.isOdd ? TextStyle(color: highlightColor) : null,
        ));
      }
      if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }

  Widget _buildHero(bool isWeb, double padding) {
    final locale = ref.watch(localeNotifierProvider);
    final headlineRaw = AppLocalizations.t(locale, 'headline');
    final heroDescription = AppLocalizations.t(
      locale,
      'landing2_hero_description',
    );
    return Container(
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            brandColor.withValues(alpha: _isDark ? 0.12 : 0.06),
            _surfaceBg,
            _isDark ? brandColor.withValues(alpha: 0.05) : Colors.green.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // ✅ عناصر خلفية هادئة (blobs) - مجرد تدرّج شفاف، بدون أي تأثير
          // تفاعلي، بس لمسة عصرية خفيفة خلف المحتوى.
          Positioned(
            top: -80,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      brandColor.withValues(alpha: _isDark ? 0.14 : 0.08),
                      brandColor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: _isDark ? 0.1 : 0.06),
                      AppColors.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: padding,
              vertical: isWeb ? 60 : 30,
            ),
            child: Flex(
              direction: isWeb ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: isWeb
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: isWeb ? 1 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: brandColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delivery_dining_outlined,
                              size: 16,
                              color: brandColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.t(locale, 'fast_delivery'),
                              style: TextStyle(
                                color: brandColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: isWeb ? 54 : 34,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                            height: 1.1,
                            fontFamily: 'sans-serif',
                          ),
                          children: _headlineSpans(
                            headlineRaw,
                            const Color(0xFF10B981),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        heroDescription,
                        style: TextStyle(
                          fontSize: 16,
                          color: _textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () => _goToRegister(),
                            icon: Text(
                              AppLocalizations.t(locale, 'browse_stores'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            label: const Icon(Icons.arrow_forward, size: 16),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _textPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              side: BorderSide(
                                color: _isDark
                                    ? Colors.white30
                                    : Colors.grey.shade300,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const StoresScreen(isGuest: true),
                                ),
                              );
                            },
                            child: Text(
                              AppLocalizations.t(locale, 'view_categories'),
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
                if (isWeb) const SizedBox(width: 40),
                if (isWeb)
                  Expanded(
                    flex: 1,
                    child: AppShowcasePhoneWidget(products: _showcaseProducts),
                  ),
                if (!isWeb) const SizedBox(height: 30),
                if (!isWeb) AppShowcasePhoneWidget(products: _showcaseProducts),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Statistics Cards (أرقام حقيقية من نفس البيانات المحمّلة - راجع _loadHomeData) ----------------
  // ✅ شريط غامق (زي التصميم المرجعي) بدل الخلفية البيضاء المسطّحة - نفس
  // الأرقام الحقيقية بس بوزن بصري أوضح.
  Widget _buildStatsSection(bool isWeb, double padding) {
    final locale = ref.watch(localeNotifierProvider);
    final stats = [
      {
        'icon': Icons.storefront_outlined,
        'value': _totalStoresCount > 0 ? '$_totalStoresCount+' : '-',
        'label': AppLocalizations.t(locale, 'landing2_stats_stores'),
        'sub': AppLocalizations.t(locale, 'landing2_stats_stores_sub'),
      },
      {
        'icon': Icons.category_outlined,
        'value': '${_categories.length}',
        'label': AppLocalizations.t(locale, 'landing2_stats_categories'),
        'sub': AppLocalizations.t(locale, 'landing2_stats_categories_sub'),
      },
      {
        'icon': Icons.location_city_outlined,
        'value': _citiesCount > 0 ? '$_citiesCount' : '-',
        'label': AppLocalizations.t(locale, 'landing2_stats_cities'),
        'sub': AppLocalizations.t(locale, 'landing2_stats_cities_sub'),
      },
      {
        'icon': Icons.star_rounded,
        'value': _avgRating > 0 ? _avgRating.toStringAsFixed(1) : '-',
        'label': AppLocalizations.t(locale, 'landing2_stats_rating'),
        'sub': AppLocalizations.t(locale, 'landing2_stats_rating_sub'),
      },
    ];

    return Container(
      width: double.infinity,
      color: AppColors.brandDark,
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: isWeb ? 48 : 28,
      ),
      child: FadeSlideIn(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 900
                ? 4
                : (constraints.maxWidth > 520 ? 2 : 1);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: crossAxisCount == 1 ? 3.2 : 1.15,
              ),
              itemCount: stats.length,
              itemBuilder: (context, i) {
                final s = stats[i];
                return HoverLift(
                  liftPx: 4,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: brandColor.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            s['icon'] as IconData,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          s['value'] as String,
                          style: TextStyle(
                            fontSize: isWeb ? 30 : 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s['label'] as String,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s['sub'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ---------------- باقي الأقسام: نفس home_screen.dart بالظبط ----------------

  Widget _buildFeaturesStrip(bool isWeb, double padding) {
    final locale = ref.watch(localeNotifierProvider);
    var features = [
      {
        'icon': Icons.local_shipping_outlined,
        'title': AppLocalizations.t(
          locale,
          'landing2_feature_fast_delivery_title',
        ),
        'desc': AppLocalizations.t(
          locale,
          'landing2_feature_fast_delivery_desc',
        ),
      },
      {
        'icon': Icons.access_time,
        'title': AppLocalizations.t(locale, 'landing2_feature_pickup_title'),
        'desc': AppLocalizations.t(locale, 'landing2_feature_pickup_desc'),
      },
      {
        'icon': Icons.shield_outlined,
        'title': AppLocalizations.t(locale, 'landing2_feature_secure_title'),
        'desc': AppLocalizations.t(locale, 'landing2_feature_secure_desc'),
      },
    ];

    List<Widget> featureWidgets = features
        .map(
          (f) => HoverLift(
            liftPx: 5,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: isWeb ? 260 : double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _pageBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _borderColorSoft),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: brandColor.withValues(alpha: 0.08),
                    child: Icon(
                      f['icon'] as IconData,
                      color: brandColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f['title'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _textPrimary,
                          ),
                        ),
                        Text(
                          f['desc'] as String,
                          style: TextStyle(color: _textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();

    return Container(
      width: double.infinity,
      color: _surfaceBg,
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 28),
      child: FadeSlideIn(
        child: isWeb
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: featureWidgets,
              )
            : Column(
                children: featureWidgets
                    .map(
                      (w) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: w,
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }

  // ---------------- Multi-category promo banner (order anything, from anywhere) ----------------
  Widget _buildMultiCategoryBanner(bool isWeb) {
    final locale = ref.watch(localeNotifierProvider);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isWeb ? 36 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          colors: [brandColor, AppColors.brandDark, const Color(0xFF1A1A24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: brandColor.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.all_inbox_rounded,
              size: isWeb ? 180 : 120,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            right: 70,
            top: -10,
            child: Icon(
              Icons.local_mall_outlined,
              size: isWeb ? 100 : 70,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flash_on, color: Colors.amber, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.t(locale, 'landing2_banner_badge'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                AppLocalizations.t(locale, 'landing2_banner_headline'),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: isWeb ? 28 : 20,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.t(locale, 'landing2_banner_subtitle'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                  fontSize: isWeb ? 15 : 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(double padding, double width) {
    final locale = ref.watch(localeNotifierProvider);
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
                    AppLocalizations.t(locale, 'landing2_categories_heading'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  Text(
                    AppLocalizations.t(
                      locale,
                      'landing2_categories_subheading',
                    ),
                    style: TextStyle(color: _textSecondary, fontSize: 14),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StoresScreen(isGuest: true),
                  ),
                ),
                label: const Icon(Icons.chevron_right, size: 14),
                icon: Text(
                  AppLocalizations.t(locale, 'landing2_view_all'),
                  style: TextStyle(
                    color: brandColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FadeSlideIn(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.95,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                var cat = _categories[index];
                return HoverLift(
                  liftPx: 5,
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StoresScreen(
                        initialCategoryId: cat.id,
                        isGuest: true,
                      ),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _surfaceBg,
                      border: Border.all(color: _borderColorSoft),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: brandColor.withValues(alpha: 0.1),
                          child: Icon(
                            cat.iconData,
                            color: brandColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          cat.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if ((_categoryStoreCounts[cat.id] ?? 0) > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${_categoryStoreCounts[cat.id]} ${AppLocalizations.t(locale, 'landing2_stats_stores')}',
                            style: TextStyle(
                              fontSize: 10,
                              color: _textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularStoresSection(double padding, double width) {
    final locale = ref.watch(localeNotifierProvider);
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
                      locale,
                      'landing2_popular_stores_heading',
                    ),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  Text(
                    AppLocalizations.t(
                      locale,
                      'landing2_popular_stores_subheading',
                    ),
                    style: TextStyle(color: _textSecondary, fontSize: 14),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StoresScreen(isGuest: true),
                  ),
                ),
                label: const Icon(Icons.chevron_right, size: 14),
                icon: Text(
                  AppLocalizations.t(locale, 'landing2_see_all'),
                  style: TextStyle(
                    color: brandColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FadeSlideIn(
            child: GridView.builder(
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
                var store = _stores[index];
                final categoryName = _catMap[store.categoryId] ?? '';
                return StoreCard(
                  store: store,
                  categoryName: categoryName,
                  isGuest: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          StoreDetailScreen(store: store, isGuest: true),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- "الأكثر رواجًا لك" ----------------
  // بديل guest-safe لقسم "Recommended For You": محرك التوصيات الحقيقي
  // بالتطبيق (recommendationRoutes.js) auth-protected ومبني على تاريخ طلبات
  // المستخدم الفعلي - ما بينفع يشتغل لضيف مش مسجّل دخول أصلًا (401). فبدل
  // ما نستنسخ محرك توصيات وهمي، بنعرض أعلى المتاجر تقييمًا من نفس البيانات
  // المحمّلة أصلًا - نفس الإحساس البصري بس بشارة صادقة ("الأعلى تقييمًا")
  // مش ادّعاء تخصيص شخصي غير موجود فعليًا لزائر ما سجّل دخول.
  Widget _buildRecommendedSection(double padding, double width) {
    if (_stores.isEmpty) return const SizedBox.shrink();
    final locale = ref.watch(localeNotifierProvider);
    final topRated = [..._stores]
      ..sort((a, b) => b.averageRating.compareTo(a.averageRating));
    final picks = topRated.take(4).toList();
    final crossAxisCount = width > 900 ? 2 : 1;

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
                AppLocalizations.t(locale, 'landing2_recommended_heading'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          Text(
            AppLocalizations.t(locale, 'landing2_recommended_subheading'),
            style: TextStyle(color: _textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
          FadeSlideIn(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: crossAxisCount > 1 ? 2.6 : 2.0,
              ),
              itemCount: picks.length,
              itemBuilder: (context, index) {
                final store = picks[index];
                return StorePromoCard(
                  store: store,
                  badge: AppLocalizations.t(
                    locale,
                    'landing2_recommended_badge',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          StoreDetailScreen(store: store, isGuest: true),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingProductsSection(double padding, double width) {
    final locale = ref.watch(localeNotifierProvider);
    int crossAxisCount = width > 950 ? 4 : (width > 650 ? 3 : 2);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.t(locale, 'landing2_trending_heading'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          Text(
            AppLocalizations.t(locale, 'landing2_trending_subheading'),
            style: TextStyle(color: _textSecondary, fontSize: 14),
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
              final storeName = _storeMap[product.storeId] ?? '';
              return Container(
                decoration: BoxDecoration(
                  color: _surfaceBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _borderColorSoft),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Image.network(
                          product.imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey,
                                ),
                              ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              storeName,
                              style: TextStyle(
                                fontSize: 11,
                                color: _textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 12,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${product.averageRating}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₪${product.price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                InkWell(
                                  // 👈 هون الفرق: ضيف مش مسجل دخول، فبنطلعله نافذة تسجيل بدل الإضافة الفعلية
                                  onTap: () => showLoginRequiredDialog(context),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    height: 28,
                                    width: 28,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.accent,
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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

  // ---------------- "Why PickNGo" - ميزات حقيقية موجودة فعليًا بالتطبيق ----------------
  Widget _buildWhyPickNGoSection(bool isWeb, double padding) {
    final locale = ref.watch(localeNotifierProvider);
    final items = [
      {
        'icon': Icons.auto_awesome,
        'title': AppLocalizations.t(locale, 'landing2_why_ai_title'),
        'desc': AppLocalizations.t(locale, 'landing2_why_ai_desc'),
      },
      {
        'icon': Icons.route_outlined,
        'title': AppLocalizations.t(locale, 'landing2_why_smart_title'),
        'desc': AppLocalizations.t(locale, 'landing2_why_smart_desc'),
      },
      {
        'icon': Icons.location_on_outlined,
        'title': AppLocalizations.t(locale, 'landing2_why_tracking_title'),
        'desc': AppLocalizations.t(locale, 'landing2_why_tracking_desc'),
      },
      {
        'icon': Icons.apps_outlined,
        'title': AppLocalizations.t(locale, 'landing2_why_multiservice_title'),
        'desc': AppLocalizations.t(locale, 'landing2_why_multiservice_desc'),
      },
    ];

    return Container(
      width: double.infinity,
      color: _pageBg,
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: isWeb ? 56 : 32,
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.t(locale, 'landing2_why_heading'),
            style: TextStyle(
              fontSize: isWeb ? 28 : 22,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              AppLocalizations.t(locale, 'landing2_why_subheading'),
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),
          FadeSlideIn(
            child: Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: items.map((f) {
                return HoverLift(
                  liftPx: 6,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: isWeb ? 260 : double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: _surfaceBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _borderColorSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: brandColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            f['icon'] as IconData,
                            color: brandColor,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          f['title'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          f['desc'] as String,
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- How it works (4 خطوات حقيقية لآلية الطلب) ----------------
  Widget _buildHowItWorksSection(bool isWeb, double padding) {
    final locale = ref.watch(localeNotifierProvider);
    final steps = [
      {
        'icon': Icons.explore_outlined,
        'title': AppLocalizations.t(locale, 'landing2_how_step1_title'),
        'desc': AppLocalizations.t(locale, 'landing2_how_step1_desc'),
      },
      {
        'icon': Icons.storefront_outlined,
        'title': AppLocalizations.t(locale, 'landing2_how_step2_title'),
        'desc': AppLocalizations.t(locale, 'landing2_how_step2_desc'),
      },
      {
        'icon': Icons.shopping_cart_checkout_outlined,
        'title': AppLocalizations.t(locale, 'landing2_how_step3_title'),
        'desc': AppLocalizations.t(locale, 'landing2_how_step3_desc'),
      },
      {
        'icon': Icons.location_on_outlined,
        'title': AppLocalizations.t(locale, 'landing2_how_step4_title'),
        'desc': AppLocalizations.t(locale, 'landing2_how_step4_desc'),
      },
    ];

    return Container(
      width: double.infinity,
      color: _pageBg,
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: isWeb ? 56 : 32,
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.t(locale, 'landing2_how_heading'),
            style: TextStyle(
              fontSize: isWeb ? 28 : 22,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              AppLocalizations.t(locale, 'landing2_how_subheading'),
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, fontSize: 14),
            ),
          ),
          const SizedBox(height: 40),
          FadeSlideIn(
            child: Stack(
              children: [
                // ✅ خط متقطّع واصل بين الدوائر - بعرض الويب بس، وين في مساحة
                // كافية إنه يبين مرتّب أفقيًا.
                if (isWeb)
                  Positioned(
                    top: 40,
                    left: 60,
                    right: 60,
                    child: CustomPaint(
                      size: const Size(double.infinity, 2),
                      painter: _DashedLinePainter(
                        color: brandColor.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                isWeb
                    ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int i = 0; i < steps.length; i++)
                              Expanded(
                                child: _howItWorksStep(steps[i], i + 1),
                              ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          for (int i = 0; i < steps.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: _howItWorksStep(steps[i], i + 1),
                            ),
                        ],
                      ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StoresScreen(isGuest: true),
              ),
            ),
            icon: Text(
              AppLocalizations.t(locale, 'landing2_how_cta'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            label: const Icon(Icons.arrow_forward, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _howItWorksStep(Map<String, Object> step, int number) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  step['icon'] as IconData,
                  color: brandColor,
                  size: 30,
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _surfaceBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: brandColor, width: 2),
                  ),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: brandColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            step['title'] as String,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: _textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            step['desc'] as String,
            style: TextStyle(
              fontSize: 12.5,
              color: _textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------------- Testimonials ----------------
  // ⚠️ محتوى مؤقت (placeholder) - أسماء/اقتباسات عامة غير مرتبطة بعملاء
  // حقيقيين، وبدون صور مستخدمين حقيقية (أيقونة عامة بدل صورة). لازم تتبدّل
  // بتقييمات عملاء حقيقية قبل الإطلاق الفعلي.
  Widget _buildTestimonialsSection(bool isWeb, double padding) {
    final locale = ref.watch(localeNotifierProvider);
    final testimonials = [
      {
        'name': AppLocalizations.t(locale, 'landing2_testimonial_1_name'),
        'role': AppLocalizations.t(locale, 'landing2_testimonial_1_role'),
        'quote': AppLocalizations.t(locale, 'landing2_testimonial_1_quote'),
      },
      {
        'name': AppLocalizations.t(locale, 'landing2_testimonial_2_name'),
        'role': AppLocalizations.t(locale, 'landing2_testimonial_2_role'),
        'quote': AppLocalizations.t(locale, 'landing2_testimonial_2_quote'),
      },
      {
        'name': AppLocalizations.t(locale, 'landing2_testimonial_3_name'),
        'role': AppLocalizations.t(locale, 'landing2_testimonial_3_role'),
        'quote': AppLocalizations.t(locale, 'landing2_testimonial_3_quote'),
      },
    ];

    return Container(
      width: double.infinity,
      color: _surfaceBg,
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: isWeb ? 56 : 32,
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.t(locale, 'landing2_testimonials_heading'),
            style: TextStyle(
              fontSize: isWeb ? 28 : 22,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FadeSlideIn(
            child: isWeb
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: testimonials
                        .map(
                          (t) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: _testimonialCard(t),
                            ),
                          ),
                        )
                        .toList(),
                  )
                : Column(
                    children: testimonials
                        .map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _testimonialCard(t),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _testimonialCard(Map<String, String> t) {
    final initial = t['name']!.trim().isNotEmpty
        ? t['name']!.trim()[0].toUpperCase()
        : '?';
    // ✅ ظل أخضر مختلف الشدّة لكل كارت (بدل لون واحد ثابت) - تنويع بصري
    // بسيط بدون الخروج عن العائلة اللونية الخضراء المطلوبة.
    final avatarColor = Color.lerp(
      brandColor,
      AppColors.secondaryBrand,
      (t['name'].hashCode.abs() % 100) / 100,
    )!;
    return HoverLift(
      liftPx: 5,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _pageBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColorSoft),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -4,
              right: -4,
              child: Icon(
                Icons.format_quote_rounded,
                size: 42,
                color: brandColor.withValues(alpha: 0.12),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) =>
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '"${t['quote']}"',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 13.5,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: avatarColor,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t['name']!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _textPrimary,
                          ),
                        ),
                        Text(
                          t['role']!,
                          style: TextStyle(
                            fontSize: 11,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- CTA: انضم كمطعم / انضم كسائق (قبل الفوتر مباشرة) ----------------
  Widget _buildPartnerCtaSection(bool isWeb, double padding) {
    final locale = ref.watch(localeNotifierProvider);

    final storeCard = _PartnerCard(
      brandColor: brandColor,
      icon: Icons.storefront_outlined,
      title: AppLocalizations.t(locale, 'landing2_partner_store_title'),
      subtitle: AppLocalizations.t(locale, 'landing2_partner_store_desc'),
      bullets: [
        AppLocalizations.t(locale, 'landing2_partner_store_b1'),
        AppLocalizations.t(locale, 'landing2_partner_store_b2'),
        AppLocalizations.t(locale, 'landing2_partner_store_b3'),
      ],
      ctaLabel: AppLocalizations.t(locale, 'landing2_partner_store_cta'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RegisterScreen(initialRole: 'Business'),
        ),
      ),
    );

    final driverCard = _PartnerCard(
      brandColor: brandColor,
      icon: Icons.two_wheeler_outlined,
      title: AppLocalizations.t(locale, 'landing2_partner_driver_title'),
      subtitle: AppLocalizations.t(locale, 'landing2_partner_driver_desc'),
      bullets: [
        AppLocalizations.t(locale, 'landing2_partner_driver_b1'),
        AppLocalizations.t(locale, 'landing2_partner_driver_b2'),
        AppLocalizations.t(locale, 'landing2_partner_driver_b3'),
      ],
      ctaLabel: AppLocalizations.t(locale, 'landing2_partner_driver_cta'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RegisterScreen(initialRole: 'Driver'),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: isWeb ? 64 : 40,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [brandColor, AppColors.brandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.t(locale, 'landing2_partner_heading'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isWeb ? 30 : 22,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              AppLocalizations.t(locale, 'landing2_partner_subheading'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: isWeb ? 15 : 13,
              ),
            ),
          ),
          const SizedBox(height: 36),
          isWeb
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: storeCard),
                    const SizedBox(width: 24),
                    Expanded(child: driverCard),
                  ],
                )
              : Column(
                  children: [storeCard, const SizedBox(height: 20), driverCard],
                ),
        ],
      ),
    );
  }

  Widget _buildFooterSection(double padding, bool isWeb) {
    final locale = ref.watch(localeNotifierProvider);
    final year = DateTime.now().year;
    return Container(
      color: _surfaceBg,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(padding, 40, padding, 24),
      child: FadeSlideIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isWeb
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
            const SizedBox(height: 24),
            Divider(color: _borderColorSoft),
            const SizedBox(height: 16),
            Text(
              '© $year ${AppLocalizations.t(locale, 'app_name')}',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _getFooterColumns() {
    final locale = ref.watch(localeNotifierProvider);
    return [
      SizedBox(
        width: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: brandColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.t(locale, 'app_name'),
                  style: TextStyle(
                    color: brandColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.t(locale, 'landing2_footer_tagline'),
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
      _buildFooterLinkColumn(
        AppLocalizations.t(locale, 'landing2_footer_shop_title'),
        [
          AppLocalizations.t(locale, 'landing2_footer_categories'),
          AppLocalizations.t(locale, 'landing2_footer_all_stores'),
        ],
      ),
      _buildFooterLinkColumn(
        AppLocalizations.t(locale, 'landing2_footer_account_title'),
        [
          AppLocalizations.t(locale, 'log_in'),
          AppLocalizations.t(locale, 'landing2_footer_sign_up'),
        ],
      ),
      _buildFooterLinkColumn(
        AppLocalizations.t(locale, 'landing2_footer_business_title'),
        [
          AppLocalizations.t(locale, 'landing2_footer_become_store_owner'),
          AppLocalizations.t(locale, 'landing2_footer_become_driver'),
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...links.map(
          (link) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              link,
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _PartnerCard extends StatelessWidget {
  final Color brandColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final String ctaLabel;
  final VoidCallback onTap;

  const _PartnerCard({
    required this.brandColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.ctaLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: brandColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 18),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: brandColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              onPressed: onTap,
              label: Text(
                ctaLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.arrow_forward, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// خط أفقي متقطّع - يستخدم بقسم "كيف يعمل" لربط دوائر الخطوات ببعضها بصريًا.
class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dashWidth = 6.0;
    const dashSpace = 5.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
