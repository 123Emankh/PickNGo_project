// lib/widgets/home_shortcut_cards.dart
//
// شريط 4 بطاقات اختصار ملوّنة أعلى الصفحة الرئيسية (كوبونات خصم/وصل حديثاً/
// توصيل مجاني/عروض اليوم) - كل بطاقة بتفتح شاشة مخصصة إلها (lib/screens/home/shortcuts/).
// Row على الشاشات الواسعة، شبكة 2x2 تحت ~650px (نفس فكرة كسر الأعمدة
// المستخدمة بـ StoreCard.gridColumnsForWidth).
//
// ✅ الألوان هون محلية للملف (مش AppColors) بقرار: تخفيف تشبّع ألوان صفحة
// الهوم بس، بدون ما يأثر عالثيم العام (أزرار/sidebar/باقي الشاشات).

import 'package:flutter/material.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_themes.dart';
import '../screens/home/shortcuts/coupons_screen.dart';
import '../screens/home/shortcuts/new_arrivals_screen.dart';
import '../screens/home/shortcuts/free_delivery_screen.dart';
import '../screens/home/shortcuts/todays_offers_screen.dart';
import 'hover_lift.dart';

class _ShortcutCardData {
  final String titleKey;
  final String subtitleKey;
  final IconData icon;
  final List<Color> gradient;
  final WidgetBuilder destinationBuilder;

  const _ShortcutCardData({
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
    required this.gradient,
    required this.destinationBuilder,
  });
}

final List<_ShortcutCardData> _shortcuts = [
  _ShortcutCardData(
    titleKey: 'home_shortcut_coupons_title',
    subtitleKey: 'home_shortcut_coupons_subtitle',
    icon: Icons.local_offer_outlined,
    gradient: const [Color(0xFFF97316), Color(0xFFFB923C)],
    destinationBuilder: (context) => const CouponsScreen(),
  ),
  _ShortcutCardData(
    titleKey: 'home_shortcut_newarrivals_title',
    subtitleKey: 'home_shortcut_newarrivals_subtitle',
    icon: Icons.auto_awesome,
    gradient: const [Color(0xFF16A34A), Color(0xFF4ADE80)],
    destinationBuilder: (context) => const NewArrivalsScreen(),
  ),
  _ShortcutCardData(
    titleKey: 'home_shortcut_freedelivery_title',
    subtitleKey: 'home_shortcut_freedelivery_subtitle',
    icon: Icons.delivery_dining_outlined,
    gradient: const [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    destinationBuilder: (context) => const FreeDeliveryScreen(),
  ),
  _ShortcutCardData(
    titleKey: 'home_shortcut_todaysoffers_title',
    subtitleKey: 'home_shortcut_todaysoffers_subtitle',
    icon: Icons.whatshot_outlined,
    gradient: const [Color(0xFFEF4444), Color(0xFFF87171)],
    destinationBuilder: (context) => const TodaysOffersScreen(),
  ),
];

class HomeShortcutCards extends StatelessWidget {
  final double padding;

  const HomeShortcutCards({super.key, required this.padding});

  static const double _cardHeight = 152;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 650 ? 4 : 2;
    final locale = Localizations.localeOf(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: _cardHeight,
        ),
        itemCount: _shortcuts.length,
        itemBuilder: (context, index) {
          final data = _shortcuts[index];
          return HoverLift(
            liftPx: 3,
            scale: 1.03,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: data.destinationBuilder),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: data.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(data.icon, color: Colors.white, size: 22),
                  ),
                  const Spacer(),
                  Text(
                    AppLocalizations.t(locale, data.titleKey),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.t(locale, data.subtitleKey),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.t(locale, 'home_shortcut_explore'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 12,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
