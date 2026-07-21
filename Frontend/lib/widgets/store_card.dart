// lib/widgets/store_card.dart
//
// بطاقة متجر مشتركة بين stores_screen.dart / home_screen.dart / favorites_screen.dart
// (كانت مكررة بنفس الشكل تقريبًا بكل شاشة). فيها زر المفضلة (قلب) مربوط بـ
// favoritesProvider، وشارة "مغلق" لو الوقت الحالي خارج ساعات الدوام.
//
// ✅ ارتفاع البطاقة موحّد عبر gridItemHeight - كل شاشة تستخدمه كـ
// mainAxisExtent بدل childAspectRatio، عشان المحتوى (اسم/وصف/تقييم/رسوم
// توصيل/حد أدنى) يملأ البطاقة بالضبط بدون فراغ فاضي بالأسفل، وبدون ما تنحسب
// نسبة الطول/العرض يدويًا بكل شاشة وتنكسر لو تغيّر المحتوى بمكان وما تغيّر
// بالثاني.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_themes.dart';
import '../data/models/store_model.dart';
import '../providers/favorites_provider.dart';
import 'login_required_dialog.dart';
import 'image_badge.dart';

class StoreCard extends ConsumerStatefulWidget {
  final StoreModel store;
  final String categoryName;
  final bool isGuest;
  final VoidCallback onTap;

  const StoreCard({
    super.key,
    required this.store,
    required this.categoryName,
    required this.onTap,
    this.isGuest = false,
  });

  // الارتفاع الكلي للبطاقة (صورة 148 + جسم النص) - استخدمه كـ mainAxisExtent
  // بأي GridView يعرض StoreCard بدل حساب childAspectRatio يدويًا.
  static const double gridItemHeight = 262;
  static const double _imageHeight = 148;
  static const double _radius = 16;

  // متجر "توصيل سريع" لو وقت التحضير قصير - نفس عتبة الشارة المستخدمة
  // بشكل ضمني بباقي التطبيق لتوصيل سريع (home hero badge).
  static const int _fastDeliveryThresholdMinutes = 15;

  /// عدد أعمدة شبكة المتاجر حسب عرض الشاشة - مصدر واحد يستخدمه كل مكان
  /// (Stores/Favorites/Home) بدل ما توزيعات الأعمدة تنكسر عن بعض. آخر
  /// عتبة (>1600) تحديدًا عشان ما تضل بطاقة وحدة عريضة عالشاشات الكبيرة.
  static int gridColumnsForWidth(double width) {
    if (width > 1600) return 5;
    if (width > 1300) return 4;
    if (width > 950) return 3;
    if (width > 650) return 2;
    return 1;
  }

  @override
  ConsumerState<StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends ConsumerState<StoreCard> {
  bool _hovering = false;
  bool _pressed = false;

  void _onHeartTap(BuildContext context, WidgetRef ref) {
    if (widget.isGuest) {
      showLoginRequiredDialog(context);
      return;
    }
    ref.read(favoritesProvider.notifier).toggle(widget.store.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final isFavorited =
        !widget.isGuest && ref.watch(favoritesProvider).contains(store.id);
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isFastDelivery =
        store.isOpenNow &&
        store.prepTimeMinutes > 0 &&
        store.prepTimeMinutes <= StoreCard._fastDeliveryThresholdMinutes;

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
            borderRadius: BorderRadius.circular(StoreCard._radius),
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
            borderRadius: BorderRadius.circular(StoreCard._radius),
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
                    height: StoreCard._imageHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          store.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: theme.dividerColor,
                                child: const Icon(
                                  Icons.storefront_outlined,
                                  color: Colors.grey,
                                ),
                              ),
                        ),
                        if (!store.isOpenNow)
                          Container(
                            color: Colors.black.withValues(alpha: 0.45),
                            alignment: Alignment.center,
                            child: Text(
                              AppLocalizations.t(locale, 'stores_closed_badge'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        PositionedDirectional(
                          top: 10,
                          start: 10,
                          end: 40,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (store.isFeatured)
                                ImageBadge(
                                  label: AppLocalizations.t(
                                    locale,
                                    'stores_card_featured_badge',
                                  ),
                                  background: AppColors.warning,
                                  foreground: Colors.white,
                                  icon: Icons.star,
                                ),
                              if (store.discountLabel != null)
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: store.isFeatured ? 6 : 0,
                                  ),
                                  child: ImageBadge(
                                    label: store.discountLabel!,
                                    background: AppColors.brand,
                                    foreground: Colors.white,
                                  ),
                                ),
                              if (isFastDelivery)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: ImageBadge(
                                    label: AppLocalizations.t(
                                      locale,
                                      'stores_card_fast_badge',
                                    ),
                                    background: AppColors.secondaryContainer,
                                    foreground: AppColors.onSecondaryContainer,
                                    icon: Icons.bolt,
                                  ),
                                ),
                              if (store.deliveryFeeInsideCity == 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: ImageBadge(
                                    label: AppLocalizations.t(
                                      locale,
                                      'stores_card_free_delivery_badge',
                                    ),
                                    background: AppColors.success,
                                    foreground: Colors.white,
                                    icon: Icons.delivery_dining_outlined,
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: ImageBadge(
                                  label: widget.categoryName,
                                  background: Colors.white.withValues(
                                    alpha: 0.92,
                                  ),
                                  foreground: Colors.black87,
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
                              padding: const EdgeInsets.all(6),
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
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          top: 40,
                          end: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 12,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${store.averageRating}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                store.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                store.description.isNotEmpty
                                    ? store.description
                                    : AppLocalizations.t(
                                        locale,
                                        'stores_card_desc',
                                      ),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${store.averageRating}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                ' (${store.totalReviews})',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.access_time,
                                color: Colors.grey.shade500,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  store.distanceKm != null
                                      ? '${store.deliveryTime} · ${store.distanceKm!.toStringAsFixed(1)} km'
                                      : store.deliveryTime,
                                  style: const TextStyle(fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.delivery_dining_outlined,
                                color: AppColors.secondaryBrand,
                                size: 14,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '₪${store.deliveryFeeInsideCity.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              if (store.minimumOrder > 0) ...[
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.shopping_bag_outlined,
                                  color: Colors.grey.shade500,
                                  size: 13,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    '${AppLocalizations.t(locale, 'stores_card_min_order')} ₪${store.minimumOrder.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              if (store.isOpenNow) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  AppLocalizations.t(
                                    locale,
                                    'stores_card_open_label',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
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
