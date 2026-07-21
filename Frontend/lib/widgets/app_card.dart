// lib/widgets/app_card.dart
//
// بطاقة أساسية موحّدة (shadow + AppRadius.lg، بدون حدود) بدل النمط المسطّح
// المكرر (cardColor + Border.all(dividerColor) + radius 14) يلي كان مبعثر
// بكذا شاشة (السلة/الدفع/الطلبات/نقاطي/الإشعارات). قيم الظل مأخوذة حرفيًا من
// حالة الاستقرار (resting state) بـ store_card.dart، بدون تأثيرات hover/press
// لأنه هاي بطاقات ثابتة (صفوف/أقسام) مش عناصر شبكة قابلة للضغط زي StoreCard/ProductCard.
import 'package:flutter/material.dart';
import '../core/theme/app_themes.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
            ),
    );
  }
}
