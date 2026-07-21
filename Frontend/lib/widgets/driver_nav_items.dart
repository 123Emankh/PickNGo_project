// lib/widgets/driver_nav_items.dart
//
// قائمة عناصر التنقل للسائق. Available Orders/Current Delivery/History
// كلهم أقسام بنفس driver_home_screen.dart (مش شاشات منفصلة) فبيرجعوا لنفس
// الشاشة. Switch to Customer Mode ميزة جديدة - تنقل واجهة بس، بدون أي
// تغيير بالباك اند (نفس الجلسة/التوكن).

import 'package:flutter/material.dart';
import '../core/i18n/app_localizations.dart';
import '../screens/driver/driver_home_screen.dart';
import '../screens/driver/driver_performance_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';

class DriverNavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  DriverNavItem({required this.icon, required this.label, required this.onTap});
}

List<DriverNavItem> buildDriverNavItems(
  BuildContext context, {
  required void Function() closeBefore,
}) {
  final locale = Localizations.localeOf(context);

  void goToDriverHome() {
    closeBefore();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
    );
  }

  void go(Widget screen) {
    closeBefore();
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  return [
    DriverNavItem(
      icon: Icons.list_alt_outlined,
      label: AppLocalizations.t(locale, 'ddrawer_available_orders'),
      onTap: goToDriverHome,
    ),
    DriverNavItem(
      icon: Icons.local_shipping_outlined,
      label: AppLocalizations.t(locale, 'ddrawer_current_delivery'),
      onTap: goToDriverHome,
    ),
    DriverNavItem(
      icon: Icons.history,
      label: AppLocalizations.t(locale, 'ddrawer_history'),
      onTap: goToDriverHome,
    ),
    DriverNavItem(
      icon: Icons.insights_outlined,
      label: 'أدائي',
      onTap: () => go(const DriverPerformanceScreen()),
    ),
    DriverNavItem(
      icon: Icons.person_outline,
      label: AppLocalizations.t(locale, 'ddrawer_profile'),
      onTap: () => go(const ProfileScreen()),
    ),
    DriverNavItem(
      icon: Icons.notifications_none,
      label: AppLocalizations.t(locale, 'ddrawer_notifications'),
      onTap: () => go(const NotificationsScreen()),
    ),
    DriverNavItem(
      icon: Icons.swap_horiz,
      label: AppLocalizations.t(locale, 'ddrawer_switch_customer'),
      onTap: () {
        closeBefore();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      },
    ),
  ];
}
