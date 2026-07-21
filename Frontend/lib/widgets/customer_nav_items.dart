// lib/widgets/customer_nav_items.dart
//
// قائمة عناصر التنقل المشتركة بين CustomerDrawer (موبايل) وCustomerSidebar
// (ويب) - مصدر واحد عشان القائمتين ما ينفرقوا عن بعض.

import 'package:flutter/material.dart';
import '../core/i18n/app_localizations.dart';
import '../screens/categories/categories_screen.dart';
import '../screens/stores/stores_screen.dart';
import '../screens/favorites/favorites_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/settings/customer_settings_screen.dart';
import '../screens/loyalty/loyalty_screen.dart';

class CustomerNavItem {
  final String id;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  CustomerNavItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// كل عنصر بيسكر أي شاشة مفتوحة فوق (Drawer أو غيره) قبل ما ينتقل، عبر
/// [closeBefore] - بالـ Drawer هاي بتسكر الـ Drawer نفسه (Navigator.pop)،
/// وبالـ Sidebar الثابت ما في داعي نسكر شي فبنمررها كدالة فاضية.
List<CustomerNavItem> buildCustomerNavItems(
  BuildContext context, {
  required void Function() closeBefore,
}) {
  final locale = Localizations.localeOf(context);

  void go(Widget screen) {
    closeBefore();
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  return [
    CustomerNavItem(
      id: 'categories',
      icon: Icons.category_outlined,
      label: AppLocalizations.t(locale, 'drawer_categories'),
      onTap: () => go(const CategoriesScreen()),
    ),
    CustomerNavItem(
      id: 'search',
      icon: Icons.search,
      label: AppLocalizations.t(locale, 'drawer_search'),
      onTap: () => go(const StoresScreen()),
    ),
    CustomerNavItem(
      id: 'favorites',
      icon: Icons.favorite_border,
      label: AppLocalizations.t(locale, 'drawer_favorites'),
      onTap: () => go(const FavoritesScreen()),
    ),
    CustomerNavItem(
      id: 'cart',
      icon: Icons.shopping_cart_outlined,
      label: AppLocalizations.t(locale, 'drawer_cart'),
      onTap: () => go(const CartScreen()),
    ),
    CustomerNavItem(
      id: 'orders',
      icon: Icons.receipt_long_outlined,
      label: AppLocalizations.t(locale, 'drawer_orders'),
      onTap: () => go(const OrdersScreen()),
    ),
    CustomerNavItem(
      id: 'trackOrders',
      icon: Icons.local_shipping_outlined,
      label: AppLocalizations.t(locale, 'drawer_track_orders'),
      // ما في شاشة "تتبع كل الطلبات" منفصلة - التتبع الفعلي per-order من
      // داخل My Orders، فمنوجّه لنفس الشاشة.
      onTap: () => go(const OrdersScreen()),
    ),
    CustomerNavItem(
      id: 'notifications',
      icon: Icons.notifications_none,
      label: AppLocalizations.t(locale, 'drawer_notifications'),
      onTap: () => go(const NotificationsScreen()),
    ),
    CustomerNavItem(
      id: 'loyalty',
      icon: Icons.stars_outlined,
      label: AppLocalizations.t(locale, 'drawer_loyalty'),
      onTap: () => go(const LoyaltyScreen()),
    ),
    CustomerNavItem(
      id: 'settings',
      icon: Icons.settings_outlined,
      label: AppLocalizations.t(locale, 'drawer_settings'),
      onTap: () => go(const CustomerSettingsScreen()),
    ),
  ];
}

/// عنصر "Profile" منفصل لأنه بيظهر برأس القائمة بستايل مختلف (اسم +
/// إيميل)، بس التنقل نفسه بيتصرف زي باقي العناصر.
void goToProfile(BuildContext context, {required void Function() closeBefore}) {
  closeBefore();
  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
}
