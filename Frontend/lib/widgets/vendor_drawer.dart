// lib/widgets/vendor_drawer.dart
//
// Drawer صاحب المحل (Vendor) - Drawer بس بدون Sidebar (business_dashboard_screen.dart
// معماريته ما بتسمح بإضافة Sidebar بسهولة زي الزبون، راجع خطة التنفيذ).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_themes.dart';
import '../providers/auth_provider.dart';
import '../screens/landing/landing_screen.dart';
import 'vendor_nav_items.dart';

class VendorDrawer extends ConsumerWidget {
  const VendorDrawer({super.key});

  static const Color brandColor = AppColors.brand;

  void _closeDrawer(BuildContext context) => Navigator.pop(context);

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    await ref.read(authProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LandingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final user = ref.watch(authProvider).user;
    final items = buildVendorNavItems(context, closeBefore: () => _closeDrawer(context));

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: brandColor.withValues(alpha: 0.1),
                    child: const Icon(Icons.storefront, size: 24, color: brandColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user?.fullName ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            for (final item in items)
              ListTile(
                leading: Icon(item.icon),
                title: Text(item.label),
                onTap: item.onTap,
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: Text(
                AppLocalizations.t(locale, 'vdrawer_logout'),
                style: const TextStyle(color: Colors.redAccent),
              ),
              onTap: () => _handleLogout(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
