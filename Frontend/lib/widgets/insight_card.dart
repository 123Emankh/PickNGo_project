// lib/widgets/insight_card.dart
//
// مكوّنات مشتركة لشاشات التحليلات (تحليلات المتجر، أداء السائق، ولاحقًا أي
// شاشة إحصائيات جديدة) - كارت إحصائية غنيّ (أيقونة + رقم كبير + وصف فرعي
// حقيقي + شريط نسبة اختياري)، عنوان قسم موحّد، وحالة فراغ موحّدة. مصدر واحد
// بدل ما تتكرر نفس الودجات بكل شاشة تحليلات.

import 'package:flutter/material.dart';
import '../core/theme/app_themes.dart';

/// كارت إحصائية بمساحة ممتلئة بمحتوى حقيقي - لتفادي مشكلة الكروت الطويلة
/// الفاضية لما تنحط جوا GridView بعرض واسع (4 أعمدة بشاشات الديسكتوب).
class InsightCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String? sub;
  final double? ratio;
  final Color? ratioColor;

  const InsightCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.sub,
    this.ratio,
    this.ratioColor,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[400]!
        : Colors.grey[600]!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(fontSize: 11.5, color: muted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (ratio != null || sub != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ratio != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ratio!.clamp(0, 1),
                      minHeight: 5,
                      backgroundColor: Theme.of(context).dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(ratioColor ?? iconColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                if (sub != null)
                  Text(
                    sub!,
                    style: TextStyle(fontSize: 10.5, color: muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// عنوان قسم موحّد (أيقونة بصندوق ملوّن + عنوان) - نفس الأسلوب بكل شاشات
/// التحليلات.
class AnalyticsSectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const AnalyticsSectionHeader({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// حالة فراغ موحّدة (أيقونة + نص) - بدل نص رمادي عادي بمنتصف الشاشة.
class AnalyticsEmptyBlock extends StatelessWidget {
  final IconData icon;
  final String text;

  const AnalyticsEmptyBlock({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[400]!
        : Colors.grey[600]!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: muted),
          const SizedBox(height: 10),
          Text(text, style: TextStyle(color: muted, fontSize: 13)),
        ],
      ),
    );
  }
}
