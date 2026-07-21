// lib/widgets/admin_nav_items.dart
//
// قائمة عناصر التنقل للأدمن. زي Vendor، معظم العناصر بترجع نسخة جديدة من
// AdminDashboardScreen بتبويب محدد. Products/Payments/Reports/Settings
// ما فيهم شاشة أصلاً - عناصر "قريباً" مؤقتة.

import 'package:flutter/material.dart';
import '../core/i18n/app_localizations.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/notifications/notifications_screen.dart';

class AdminNavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  AdminNavItem({required this.icon, required this.label, required this.onTap});
}

List<AdminNavItem> buildAdminNavItems(
  BuildContext context, {
  required void Function() closeBefore,
}) {
  final locale = Localizations.localeOf(context);

  void goToTab(int tab) {
    closeBefore();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AdminDashboardScreen(initialTab: tab)),
    );
  }

  void go(Widget screen) {
    closeBefore();
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void comingSoon(String messageKey) {
    closeBefore();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.t(locale, messageKey)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  return [
    AdminNavItem(
      icon: Icons.dashboard_outlined,
      label: AppLocalizations.t(locale, 'adrawer_dashboard'),
      onTap: () => goToTab(0),
    ),
    AdminNavItem(
      icon: Icons.people_outline,
      label: AppLocalizations.t(locale, 'adrawer_users'),
      onTap: () => goToTab(2),
    ),
    AdminNavItem(
      icon: Icons.storefront_outlined,
      label: AppLocalizations.t(locale, 'adrawer_vendors'),
      onTap: () => goToTab(0),
    ),
    AdminNavItem(
      icon: Icons.local_shipping_outlined,
      label: AppLocalizations.t(locale, 'adrawer_drivers'),
      onTap: () => goToTab(6),
    ),
    AdminNavItem(
      icon: Icons.tune,
      label: AppLocalizations.t(locale, 'adrawer_delivery_settings'),
      onTap: () => goToTab(8),
    ),
    AdminNavItem(
      icon: Icons.inventory_2_outlined,
      label: AppLocalizations.t(locale, 'adrawer_products_soon'),
      onTap: () => comingSoon('adrawer_products_soon'),
    ),
    AdminNavItem(
      icon: Icons.category_outlined,
      label: AppLocalizations.t(locale, 'adrawer_categories'),
      onTap: () => goToTab(3),
    ),
    AdminNavItem(
      icon: Icons.receipt_long_outlined,
      label: AppLocalizations.t(locale, 'adrawer_orders'),
      onTap: () => goToTab(1),
    ),
    AdminNavItem(
      icon: Icons.payment_outlined,
      label: AppLocalizations.t(locale, 'adrawer_payments_soon'),
      onTap: () => comingSoon('adrawer_payments_soon'),
    ),
    AdminNavItem(
      icon: Icons.bar_chart_outlined,
      label: AppLocalizations.t(locale, 'adrawer_reports_soon'),
      onTap: () => comingSoon('adrawer_reports_soon'),
    ),
    AdminNavItem(
      icon: Icons.notifications_none,
      label: AppLocalizations.t(locale, 'adrawer_notifications'),
      onTap: () => go(const NotificationsScreen()),
    ),
    AdminNavItem(
      icon: Icons.settings_outlined,
      label: AppLocalizations.t(locale, 'adrawer_settings_soon'),
      onTap: () => comingSoon('adrawer_settings_soon'),
    ),
  ];
}
