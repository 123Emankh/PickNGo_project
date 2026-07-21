// lib/widgets/store_promo_card.dart
//
// كارد "ترويجي" عريض لمتجر (صورة + نص جنب بعض) - مستخدم بقسم "مقترح لك"
// بشاشة Home (سبب توصية حقيقي من محرك التوصيات) وبقسم "الأكثر رواجًا" بصفحة
// Landing (الضيف ما إله محرك توصيات شخصي - بيعرض شارة زي "الأكثر تقييمًا"
// بدل سبب توصية). استُخرج لملف مشترك بدل ما يتكرر بالشاشتين.

import 'package:flutter/material.dart';
import '../core/theme/app_themes.dart';
import '../data/models/store_model.dart';

class StorePromoCard extends StatefulWidget {
  final StoreModel store;
  final String badge;
  final VoidCallback onTap;

  const StorePromoCard({
    super.key,
    required this.store,
    required this.badge,
    required this.onTap,
  });

  @override
  State<StorePromoCard> createState() => _StorePromoCardState();
}

class _StorePromoCardState extends State<StorePromoCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _hovering ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(
            0.0,
            _hovering ? -3.0 : 0.0,
            0.0,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurface
                : AppColors.secondaryContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.lg * 1.4),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg * 1.4),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg * 1.4),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.secondaryContainer.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Image.network(
                        store.imageUrl,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 88,
                          height: 88,
                          color: theme.dividerColor,
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.badge.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brand,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                widget.badge,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          Text(
                            store.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
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
                                size: 13,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${store.averageRating}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  store.deliveryTime,
                                  style: const TextStyle(fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.secondaryBrand,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
