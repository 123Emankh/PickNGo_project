// lib/widgets/product_card.dart
//
// بطاقة منتج مشتركة (نفس فلسفة store_card.dart بالضبط) - كانت مكررة كـ Widget
// داخلي مسطّح بدون شارات/مفضلة بثلاث أماكن (Trending/Recommended بـ
// home_screen.dart، وقائمة منتجات المتجر بـ store_detail_screen.dart).
//
// onTap/onAddToCart مقصودين يضلوا callbacks يمررها المستدعي (مش منطق داخلي)
// لأنه كل مكان استخدام كان عنده منطق إضافة-للسلة مختلف شوي (بعضها ما كان
// فيه فحص ضيف/متغيرات) - نقل نفس الإغلاق (closure) الموجود بكل مكان بدل ما
// نعيد كتابة المنطق هون ونخمّن الفروقات.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_themes.dart';
import '../data/models/product_model.dart';
import '../providers/favorites_provider.dart';
import 'image_badge.dart';
import 'login_required_dialog.dart';

class ProductCard extends ConsumerStatefulWidget {
  final ProductModel product;
  final String storeName;
  final bool isGuest;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  final String? reasonBadge;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAddToCart,
    this.storeName = '',
    this.isGuest = false,
    this.reasonBadge,
  });

  static const double gridItemHeight = 244;
  static const double _imageHeight = 120;
  static const double _radius = 16;

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    // ✅ مؤجّل لما بعد فريم البناء الحالي (بدل نداء مباشر بـ initState) - هاد
    // الويدجت بينبني بأعداد كبيرة سوا جوا GridView.builder، فنداء .seed()
    // المباشر هون كان بيعدّل الـ provider أثناء بناء الشجرة نفسها ويرمي
    // "Tried to modify a provider while the widget tree was building"
    // (بعكس product_detail_screen.dart يلي عنده نسخة وحدة بس فما كانت
    // المشكلة تظهر هناك).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(favoriteProductsProvider.notifier)
          .seed(widget.product.id, widget.product.isFavorited);
    });
  }

  void _onHeartTap(BuildContext context, WidgetRef ref) {
    if (widget.isGuest) {
      showLoginRequiredDialog(context);
      return;
    }
    ref.read(favoriteProductsProvider.notifier).toggle(widget.product.id);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isFavorited =
        !widget.isGuest &&
        ref.watch(favoriteProductsProvider).contains(product.id);
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : (_hovering ? 1.03 : 1.0),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(
            0.0,
            _hovering ? -4.0 : 0.0,
            0.0,
          ),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(ProductCard._radius),
            border: isDark
                ? Border.all(color: theme.dividerColor)
                : Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isDark ? 0.24 : (_hovering ? 0.12 : 0.05),
                ),
                blurRadius: _hovering ? 22 : 10,
                offset: Offset(0, _hovering ? 10 : 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(ProductCard._radius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: ProductCard._imageHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: theme.dividerColor,
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey,
                                ),
                              ),
                        ),
                        if (product.isFeatured || widget.reasonBadge != null)
                          PositionedDirectional(
                            top: 8,
                            start: 8,
                            end: 36,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (product.isFeatured)
                                  ImageBadge(
                                    label: AppLocalizations.t(
                                      locale,
                                      'stores_card_featured_badge',
                                    ),
                                    background: AppColors.warning,
                                    foreground: Colors.white,
                                    icon: Icons.star,
                                  ),
                                if (widget.reasonBadge != null)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: product.isFeatured ? 6 : 0,
                                    ),
                                    child: ImageBadge(
                                      label: widget.reasonBadge!,
                                      background: AppColors.brand,
                                      foreground: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        PositionedDirectional(
                          top: 6,
                          end: 6,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _onHeartTap(context, ref),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isFavorited
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isFavorited
                                    ? Colors.redAccent
                                    : Colors.grey[700],
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
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
                              if (widget.storeName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.storeName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
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
                                  Text(
                                    ' (${product.totalReviews})',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
                                onTap: widget.onAddToCart,
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
