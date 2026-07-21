// lib/widgets/vendor_nav_items.dart
//
// قائمة عناصر التنقل لصاحب المحل (Vendor). بخلاف الزبون، معظم العناصر
// هون بترجع نسخة جديدة من BusinessDashboardScreen بتبويب محدد (مش شاشة
// مستقلة) - راجع lib/screens/business/business_dashboard_screen.dart.

import 'package:flutter/material.dart';
import '../core/i18n/app_localizations.dart';
import '../screens/business/business_dashboard_screen.dart';
import '../screens/business/vendor_reviews_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';

class VendorNavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  VendorNavItem({required this.icon, required this.label, required this.onTap});
}

List<VendorNavItem> buildVendorNavItems(
  BuildContext context, {
  required void Function() closeBefore,
}) {
  final locale = Localizations.localeOf(context);

  void goToTab(int tab, {bool autoOpenAddProduct = false}) {
    closeBefore();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessDashboardScreen(
          initialTab: tab,
          autoOpenAddProduct: autoOpenAddProduct,
        ),
      ),
    );
  }

  void go(Widget screen) {
    closeBefore();
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  return [
    VendorNavItem(
      icon: Icons.dashboard_outlined,
      label: AppLocalizations.t(locale, 'vdrawer_dashboard'),
      onTap: () => goToTab(0),
    ),
    VendorNavItem(
      icon: Icons.inventory_2_outlined,
      label: AppLocalizations.t(locale, 'vdrawer_products'),
      onTap: () => goToTab(1),
    ),
    VendorNavItem(
      icon: Icons.add_box_outlined,
      label: AppLocalizations.t(locale, 'vdrawer_add_product'),
      onTap: () => goToTab(1, autoOpenAddProduct: true),
    ),
    VendorNavItem(
      icon: Icons.receipt_long_outlined,
      label: AppLocalizations.t(locale, 'vdrawer_orders'),
      onTap: () => goToTab(0),
    ),
    VendorNavItem(
      icon: Icons.warehouse_outlined,
      label: AppLocalizations.t(locale, 'vdrawer_inventory'),
      // ما في مفهوم "مخزون" منفصل - بس toggle "متوفر/غير متوفر" جوا كل
      // منتج، فمنوجّه لنفس تبويب المنتجات
      onTap: () => goToTab(1),
    ),
    VendorNavItem(
      icon: Icons.star_outline,
      label: AppLocalizations.t(locale, 'vdrawer_reviews'),
      onTap: () => go(const VendorReviewsScreen()),
    ),
    VendorNavItem(
      icon: Icons.notifications_none,
      label: AppLocalizations.t(locale, 'vdrawer_notifications'),
      onTap: () => go(const NotificationsScreen()),
    ),
    VendorNavItem(
      icon: Icons.person_outline,
      label: AppLocalizations.t(locale, 'vdrawer_profile'),
      onTap: () => go(const ProfileScreen()),
    ),
    VendorNavItem(
      icon: Icons.settings_outlined,
      label: AppLocalizations.t(locale, 'vdrawer_settings'),
      onTap: () => goToTab(3),
    ),
  ];
}
