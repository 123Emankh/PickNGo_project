// lib/widgets/stat_tile.dart
//
// كارت إحصائية صغير (أيقونة + قيمة + وصف) - يُستخدم بشاشات لوحة السائق
// وشاشة الأرباح.
import 'package:flutter/material.dart';
import '../core/theme/app_themes.dart';

class StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  // ✅ نسخة أكبر (تُستخدم بلوحات الأدمن/صاحب المتجر) - نفس الودجة بدل ما
  // تنكرر بكل شاشة (كانت _StatCard مكررة حرفيًا بملفين).
  final bool large;

  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = AppColors.brand,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final padding = large ? 20.0 : 14.0;
    final radius = large ? 16.0 : AppRadius.md;
    final iconPadding = large ? 8.0 : 6.0;
    final iconRadius = large ? 10.0 : AppRadius.sm;
    final iconSize = large ? 20.0 : 18.0;
    final valueFontSize = large ? 22.0 : 18.0;
    final spacing = large ? 14.0 : 10.0;
    final labelFontSize = large ? 12.0 : 11.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(iconPadding),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(iconRadius),
            ),
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
          SizedBox(height: spacing),
          Text(
            value,
            style: TextStyle(fontSize: valueFontSize, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: labelFontSize),
          ),
        ],
      ),
    );
  }
}
