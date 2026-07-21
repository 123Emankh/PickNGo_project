// lib/screens/stores/product_detail_screen.dart
//
// شاشة تفاصيل منتج: على الموبايل - صورة بحافة سفلية منحنية وبطاقة عائمة
// تحتها. على الشاشات العريضة (ويب/ديسكتوب) - تخطيط split-screen بهيدر
// التطبيق المعتاد، صورة كبيرة على جنب وتفاصيل المنتج على الجنب التاني.
// نفس المنطق (حجم، إضافات، طلبات خاصة، مفضلة، كمية) مشترك بين الاثنين.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_themes.dart';
import '../../core/i18n/app_localizations.dart';
import '../../data/models/product_model.dart';
import '../../data/models/product_variant_model.dart';
import '../../data/models/product_addon_model.dart';
import '../../data/models/product_exclusion_model.dart';
import '../../data/models/product_option_group_model.dart';
import '../../data/models/product_option_value_model.dart';
import '../../data/models/cart_item_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../widgets/login_required_dialog.dart';
import '../../widgets/main_layout.dart';
import '../../services/review_service.dart';

/// يقص الحافة السفلية للصورة الرئيسية (نسخة الموبايل) بمنحنى بيضاوي بسيط.
class _HeroBottomClipper extends CustomClipper<Path> {
  const _HeroBottomClipper();

  @override
  Path getClip(Size size) {
    const curveHeight = 18.0;
    final path = Path()
      ..lineTo(0, size.height - curveHeight)
      ..quadraticBezierTo(
        size.width / 2,
        size.height + curveHeight,
        size.width,
        size.height - curveHeight,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class ProductDetailScreen extends ConsumerStatefulWidget {
  final ProductModel product;
  final String storeName;
  final bool isGuest;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.storeName,
    this.isGuest = false,
  });

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  static const Color brandColor = AppColors.brand;

  final PageController _pageController = PageController();
  int _currentImage = 0;
  ProductVariantModel? _selectedVariant;
  final Set<String> _selectedAddonIds = {};
  final Set<String> _selectedExclusionIds = {};
  final Map<String, Set<String>> _selectedOptionValueIds = {}; // group.id -> value ids
  int _quantity = 1;
  bool _showValidationHint = false;

  late final List<String> _images = [
    if (widget.product.imageUrl.isNotEmpty) widget.product.imageUrl,
    ...widget.product.images,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.product.variants.isNotEmpty) {
      _selectedVariant = widget.product.variants.first;
    }
    ref.read(favoriteProductsProvider.notifier).seed(widget.product.id, widget.product.isFavorited);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double get _basePrice => _selectedVariant?.price ?? widget.product.price;

  List<ProductAddonModel> get _selectedAddons => widget.product.addons
      .where((a) => _selectedAddonIds.contains(a.id))
      .toList();

  double get _addonsPrice => _selectedAddons.fold(0.0, (sum, a) => sum + a.price);

  /// كل القيم المختارة من مجموعات المواصفات المخصصة، بشكل جاهز للسلة/الطلب
  List<SelectedProductOption> get _selectedOptionsList {
    final result = <SelectedProductOption>[];
    for (final group in widget.product.optionGroups) {
      final selectedIds = _selectedOptionValueIds[group.id] ?? const {};
      for (final value in group.values) {
        if (selectedIds.contains(value.id)) {
          result.add(SelectedProductOption(
            groupId: group.id,
            groupName: group.name,
            valueId: value.id,
            label: value.label,
            price: value.price,
          ));
        }
      }
    }
    return result;
  }

  double get _optionsPrice => _selectedOptionsList.fold(0.0, (sum, o) => sum + o.price);

  /// أسماء المجموعات الإجبارية اللي لسا ما انختار منها شي
  List<String> get _missingRequiredGroups => widget.product.optionGroups
      .where((g) => g.isRequired && (_selectedOptionValueIds[g.id]?.isEmpty ?? true))
      .map((g) => g.name)
      .toList();

  double get _unitPrice => _basePrice + _addonsPrice + _optionsPrice;
  double get _total => _unitPrice * _quantity;

  bool get _isFavorited =>
      !widget.isGuest && ref.watch(favoriteProductsProvider).contains(widget.product.id);

  void _toggleFavorite() {
    if (widget.isGuest) {
      showLoginRequiredDialog(context);
      return;
    }
    ref.read(favoriteProductsProvider.notifier).toggle(widget.product.id);
  }

  void _addToCart() {
    if (widget.isGuest) {
      showLoginRequiredDialog(context);
      return;
    }
    final locale = Localizations.localeOf(context);
    final missing = _missingRequiredGroups;
    if (missing.isNotEmpty) {
      setState(() => _showValidationHint = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.t(locale, 'productdetail_option_required_message')
                .replaceFirst('{group}', missing.first),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final exclusionLabels = widget.product.exclusions
        .where((e) => _selectedExclusionIds.contains(e.id))
        .map((e) => e.label)
        .toList();

    ref.read(cartProvider.notifier).addProduct(
          widget.product,
          widget.storeName,
          variant: _selectedVariant,
          addons: _selectedAddons,
          exclusionLabels: exclusionLabels,
          options: _selectedOptionsList,
          quantity: _quantity,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.t(locale, 'productdetail_added_to_cart')
              .replaceFirst('{item}', widget.product.name),
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      isGuest: widget.isGuest,
      builder: (context, isWeb, padding, width) {
        return isWeb ? _buildDesktopScaffold(padding) : _buildMobileScaffold();
      },
    );
  }

  // ==========================================================
  // ديسكتوب/ويب: تخطيط split-screen (الهيدر المشترك جاي من MainLayout)
  // ==========================================================
  Widget _buildDesktopScaffold(double padding) {
    final locale = Localizations.localeOf(context);
    final product = widget.product;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBreadcrumb(locale),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: _buildDesktopImage()),
                    const SizedBox(width: 40),
                    Expanded(flex: 5, child: _buildDesktopDetails(locale, product)),
                  ],
                ),
                const SizedBox(height: 32),
                const Divider(height: 1),
                _buildReviewsSection(0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumb(Locale locale) {
    final crumbStyle = TextStyle(color: Colors.grey[500], fontSize: 13);
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          child: Text(widget.storeName, style: crumbStyle),
        ),
        Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
        Text(
          widget.product.name,
          style: TextStyle(color: brandColor, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDesktopImage() {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _images.isEmpty
                ? Container(
                    color: Theme.of(context).dividerColor,
                    child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 56),
                  )
                : PageView.builder(
                    controller: _pageController,
                    itemCount: _images.length,
                    onPageChanged: (i) => setState(() => _currentImage = i),
                    itemBuilder: (context, index) => Image.network(
                      _images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Theme.of(context).dividerColor,
                        child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 56),
                      ),
                    ),
                  ),
            Positioned(top: 16, left: 16, child: _circleButton(Icons.arrow_back, () => Navigator.pop(context))),
            Positioned(top: 16, right: 16, child: _circleButton(
              _isFavorited ? Icons.favorite : Icons.favorite_border,
              _toggleFavorite,
              color: _isFavorited ? Colors.redAccent : Colors.black87,
            )),
            if (widget.product.isFeatured)
              Positioned(
                top: 16,
                left: 64,
                child: _bestsellerBadge(fontSize: 12, iconSize: 16, horizontalPad: 12, verticalPad: 7),
              ),
            if (_images.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_images.length, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _currentImage ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _currentImage ? Colors.white : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap, {Color color = Colors.black87}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _bestsellerBadge({
    required double fontSize,
    required double iconSize,
    required double horizontalPad,
    required double verticalPad,
  }) {
    final locale = Localizations.localeOf(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: verticalPad),
      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: iconSize, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.t(locale, 'productdetail_bestseller_label'),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: fontSize),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDetails(Locale locale, ProductModel product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(product.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            ),
            Text(
              '₪${_basePrice.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: brandColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 18),
            const SizedBox(width: 4),
            Text('${product.averageRating}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(' (${product.totalReviews})', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ),
        if (product.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            product.description,
            style: TextStyle(color: Colors.grey[700], fontSize: 14.5, height: 1.6),
          ),
        ],
        if (product.variants.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionTitle(AppLocalizations.t(locale, 'productdetail_size_title'), big: true),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: product.variants.map(_buildVariantChip).toList()),
        ],
        if (product.addons.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionTitle(AppLocalizations.t(locale, 'productdetail_customize_title'), big: true),
          const SizedBox(height: 10),
          ...product.addons.map(_buildAddonRow),
        ],
        if (product.exclusions.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionTitle(AppLocalizations.t(locale, 'productdetail_special_requests_title'), big: true),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: product.exclusions.map(_buildExclusionChip).toList()),
        ],
        for (final group in product.optionGroups) ...[
          const SizedBox(height: 24),
          _buildOptionGroupSection(locale, group, big: true),
        ],
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              _buildQuantityStepper(size: 40, iconSize: 18, fontSize: 18),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppLocalizations.t(locale, 'productdetail_total_label'),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  Text(
                    '₪${_total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: brandColor),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: _addToCart,
            icon: const Icon(Icons.shopping_bag_outlined, size: 20),
            label: Text(
              AppLocalizations.t(locale, 'productdetail_add_to_cart'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text, {bool big = false}) {
    return Text(
      big ? text : text.toUpperCase(),
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: big ? 15 : 10.5,
        letterSpacing: big ? 0 : 0.3,
        color: big ? Theme.of(context).textTheme.bodyLarge?.color : brandColor,
      ),
    );
  }

  // ✅ تقييمات المنتج فعليًا (مبنية على مشتريات حقيقية - راجع reviewController
  // syncProductReviews بالباك إند) - نفس نمط _buildReviewsSection بـ
  // store_detail_screen.dart بس على مستوى المنتج بدل المتجر.
  Widget _buildReviewsSection(double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'التقييمات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          FutureBuilder<ReviewListResult>(
            future: ReviewService().getProductReviews(widget.product.id),
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
                      'لا توجد تقييمات بعد لهذا المنتج',
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < review.rating ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (review.comment != null && review.comment!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(review.comment!, style: const TextStyle(fontSize: 13)),
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

  // ==========================================================
  // موبايل: صورة بحافة منحنية + بطاقة عائمة + شريط سفلي ثابت
  // ==========================================================
  Widget _buildMobileScaffold() {
    final locale = Localizations.localeOf(context);
    final product = widget.product;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMobileHero(),
                Transform.translate(
                  offset: const Offset(0, -18),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₪${_basePrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: brandColor,
                                  ),
                                ),
                                if (product.isFeatured) ...[
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: brandColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      AppLocalizations.t(locale, 'productdetail_bestseller_label')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: brandColor,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              '${product.averageRating}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            Text(
                              ' (${product.totalReviews})',
                              style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            ),
                          ],
                        ),
                        if (product.description.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Text(
                            AppLocalizations.t(locale, 'productdetail_description_title'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.description,
                            style: TextStyle(color: Colors.grey[700], fontSize: 12, height: 1.35),
                          ),
                        ],
                        if (product.variants.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _sectionTitle(AppLocalizations.t(locale, 'productdetail_size_title'), big: true),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: product.variants.map(_buildVariantChip).toList(),
                          ),
                        ],
                        if (product.addons.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _sectionTitle(AppLocalizations.t(locale, 'productdetail_customize_title')),
                          const SizedBox(height: 6),
                          ...product.addons.map(_buildAddonRow),
                        ],
                        if (product.exclusions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _sectionTitle(AppLocalizations.t(locale, 'productdetail_special_requests_title')),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: product.exclusions.map(_buildExclusionChip).toList(),
                          ),
                        ],
                        for (final group in product.optionGroups) ...[
                          const SizedBox(height: 12),
                          _buildOptionGroupSection(locale, group),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.t(locale, 'productdetail_quantity_title'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        const SizedBox(height: 6),
                        _buildQuantityStepper(size: 30, iconSize: 15, fontSize: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildReviewsSection(16),
              ],
            ),
          ),
        ),
        _buildMobileBottomBar(locale),
      ],
    );
  }

  Widget _buildMobileHero() {
    return ClipPath(
      clipper: const _HeroBottomClipper(),
      child: Stack(
        children: [
          SizedBox(
            height: 190,
            child: _images.isEmpty
                ? Container(
                    color: Theme.of(context).dividerColor,
                    child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 40),
                  )
                : PageView.builder(
                    controller: _pageController,
                    itemCount: _images.length,
                    onPageChanged: (i) => setState(() => _currentImage = i),
                    itemBuilder: (context, index) => Image.network(
                      _images[index],
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Theme.of(context).dividerColor,
                        child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 40),
                      ),
                    ),
                  ),
          ),
          Positioned(top: 10, left: 10, child: SafeArea(child: _circleButton(Icons.arrow_back, () => Navigator.pop(context)))),
          Positioned(
            top: 10,
            right: 10,
            child: SafeArea(
              child: _circleButton(
                _isFavorited ? Icons.favorite : Icons.favorite_border,
                _toggleFavorite,
                color: _isFavorited ? Colors.redAccent : Colors.black87,
              ),
            ),
          ),
          if (_images.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_images.length, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentImage ? 16 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i == _currentImage ? Colors.white : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileBottomBar(Locale locale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.t(locale, 'productdetail_total_label'),
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                  Text(
                    '₪${_total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _addToCart,
              icon: const Icon(Icons.shopping_bag_outlined, size: 16),
              label: Text(
                AppLocalizations.t(locale, 'productdetail_add_to_cart'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // عناصر مشتركة بين الموبايل والديسكتوب
  // ==========================================================
  Widget _buildVariantChip(ProductVariantModel variant) {
    final isSelected = _selectedVariant?.id == variant.id;
    return InkWell(
      onTap: () => setState(() => _selectedVariant = variant),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? AppColors.accent : Theme.of(context).dividerColor),
        ),
        child: Text(
          '${variant.label} · ₪${variant.price.toStringAsFixed(2)}',
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildAddonRow(ProductAddonModel addon) {
    final isSelected = _selectedAddonIds.contains(addon.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          if (isSelected) {
            _selectedAddonIds.remove(addon.id);
          } else {
            _selectedAddonIds.add(addon.id);
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? brandColor : Theme.of(context).dividerColor,
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: isSelected ? brandColor : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(addon.name, style: const TextStyle(fontSize: 12.5))),
              Text(
                '+₪${addon.price.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: brandColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExclusionChip(ProductExclusionModel exclusion) {
    final isSelected = _selectedExclusionIds.contains(exclusion.id);
    return InkWell(
      onTap: () => setState(() {
        if (isSelected) {
          _selectedExclusionIds.remove(exclusion.id);
        } else {
          _selectedExclusionIds.add(exclusion.id);
        }
      }),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? brandColor : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? brandColor : Theme.of(context).dividerColor),
        ),
        child: Text(
          exclusion.label,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionGroupSection(Locale locale, ProductOptionGroupModel group, {bool big = false}) {
    final missing = _showValidationHint &&
        group.isRequired &&
        (_selectedOptionValueIds[group.id]?.isEmpty ?? true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionTitle(group.name, big: big),
            if (group.isRequired) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (missing ? Colors.redAccent : brandColor).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  AppLocalizations.t(locale, 'productdetail_required_badge'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: missing ? Colors.redAccent : brandColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: big ? 10 : 6),
        if (group.isSingleSelect)
          Wrap(
            spacing: big ? 10 : 8,
            runSpacing: big ? 10 : 8,
            children: group.values.map((v) => _buildOptionValueChip(group, v)).toList(),
          )
        else
          ...group.values.map((v) => _buildOptionValueRow(group, v)),
      ],
    );
  }

  Widget _buildOptionValueChip(ProductOptionGroupModel group, ProductOptionValueModel value) {
    final isSelected = _selectedOptionValueIds[group.id]?.contains(value.id) ?? false;
    return InkWell(
      onTap: () => setState(() {
        _selectedOptionValueIds[group.id] = {value.id};
      }),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? AppColors.accent : Theme.of(context).dividerColor),
        ),
        child: Text(
          value.price > 0
              ? '${value.label} · +₪${value.price.toStringAsFixed(2)}'
              : value.label,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionValueRow(ProductOptionGroupModel group, ProductOptionValueModel value) {
    final isSelected = _selectedOptionValueIds[group.id]?.contains(value.id) ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          final current = {...?_selectedOptionValueIds[group.id]};
          if (isSelected) {
            current.remove(value.id);
          } else {
            current.add(value.id);
          }
          _selectedOptionValueIds[group.id] = current;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? brandColor : Theme.of(context).dividerColor,
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: isSelected ? brandColor : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(value.label, style: const TextStyle(fontSize: 12.5))),
              if (value.price > 0)
                Text(
                  '+₪${value.price.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: brandColor),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityStepper({required double size, required double iconSize, required double fontSize}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepperButton(icon: Icons.remove, size: size, iconSize: iconSize, onTap: _quantity > 1 ? () => setState(() => _quantity--) : null),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('$_quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
        ),
        _stepperButton(icon: Icons.add, size: size, iconSize: iconSize, onTap: () => setState(() => _quantity++)),
      ],
    );
  }

  Widget _stepperButton({required IconData icon, required double size, required double iconSize, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap == null ? Colors.grey.shade200 : brandColor.withValues(alpha: 0.1),
        ),
        child: Icon(icon, size: iconSize, color: onTap == null ? Colors.grey : brandColor),
      ),
    );
  }
}
